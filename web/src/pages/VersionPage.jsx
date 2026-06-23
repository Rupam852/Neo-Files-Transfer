import { useEffect, useState, useRef } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext'
import { supabase } from '../services/supabase'
import toast from 'react-hot-toast'
import { ArrowLeft, Upload, Check, Clock, X } from 'lucide-react'
import { formatFileSize, formatDate, formatErrorMessage } from '../utils/helpers'

export default function VersionPage({ fileId: propFileId, onBack }) {
  const { fileId: paramFileId } = useParams()
  const fileId = propFileId || paramFileId
  const { user, profile } = useAuth()
  const navigate = useNavigate()
  const goBack = onBack || (() => navigate('/dashboard/files'))
  const fileInputRef = useRef(null)
  const activeXhrRef = useRef(null)
  const isCancelledRef = useRef(false)
  const [file, setFile] = useState(null)

  function handleCancelUpload() {
    isCancelledRef.current = true
    if (activeXhrRef.current) {
      activeXhrRef.current.abort()
      activeXhrRef.current = null
    }
    setUploading(false)
    setProcessingText(null)
  }
  const [versions, setVersions] = useState([])
  const [loading, setLoading] = useState(true)
  const [uploading, setUploading] = useState(false)
  const [processingText, setProcessingText] = useState(null)

  useEffect(() => {
    loadData()
  }, [fileId])

  async function loadData() {
    try {
      const { data: fileData } = await supabase
        .from('shared_files')
        .select('*')
        .eq('id', fileId)
        .eq('user_id', user.id)
        .single()

      setFile(fileData)

      if (fileData) {
        const { data: versionData } = await supabase
          .from('file_versions')
          .select('*')
          .eq('file_id', fileId)
          .order('version_number', { ascending: false })

        setVersions(versionData || [])
      }
    } catch (err) {
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  async function handleVersionUpload(e) {
    const selectedFile = e.target.files?.[0]
    if (!selectedFile) return

    const proxyUrl = import.meta.env.VITE_PROXY_URL
    const uploadLimit = proxyUrl ? 250 * 1024 * 1024 : 100 * 1024 * 1024
    const limitLabel = proxyUrl ? '250MB' : '100MB'

    if (selectedFile.size > uploadLimit) {
      toast.error(`File size exceeds ${limitLabel} limit`)
      return
    }

    if (!profile?.drive_folder_id) {
      toast.error('Please configure Google Drive folder in Settings')
      return
    }

    isCancelledRef.current = false
    setUploading(true)
    setProcessingText('Uploading version (0%)...')
    try {
      const { data: { session } } = await supabase.auth.getSession()
      const token = session?.access_token
      const googleToken = localStorage.getItem('google_provider_token') || session?.provider_token || ''

      const result = await new Promise((resolve, reject) => {
        if (proxyUrl) {
          // Direct High-speed Upload to Google Drive using Client-side resumable stream
          let accessToken = localStorage.getItem('google_provider_token') || ''
          
          const refreshGoogleAccessToken = async () => {
            const cleanProxy = proxyUrl.endsWith('/') ? proxyUrl.slice(0, -1) : proxyUrl
            const refreshRes = await fetch(`${cleanProxy}/refresh-token`, {
              headers: { 'Authorization': `Bearer ${token}` }
            })
            if (!refreshRes.ok) throw new Error('Google Drive connection expired. Please reconnect in settings.')
            const data = await refreshRes.json()
            localStorage.setItem('google_provider_token', data.google_access_token)
            return data.google_access_token
          }

          // Step 1: Initiate session on Google Drive
          (async () => {
            let uploadUrl
            try {
              if (!accessToken) {
                accessToken = await refreshGoogleAccessToken()
              }
              
              const startSession = async (tokenVal) => {
                return await fetch(
                  'https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable',
                  {
                    method: 'POST',
                    headers: {
                      'Authorization': `Bearer ${tokenVal}`,
                      'Content-Type': 'application/json; charset=UTF-8',
                      'X-Upload-Content-Type': selectedFile.type || 'application/octet-stream'
                    },
                    body: JSON.stringify({
                      name: selectedFile.name,
                      parents: [profile.drive_folder_id]
                    })
                  }
                )
              }

              let initiateResponse = await startSession(accessToken)
              if (initiateResponse.status === 401) {
                console.log('Access token expired. Refreshing...')
                accessToken = await refreshGoogleAccessToken()
                initiateResponse = await startSession(accessToken)
              }

              if (!initiateResponse.ok) {
                const errTxt = await initiateResponse.text()
                throw new Error(`Google Drive API initiation failed: ${errTxt}`)
              }

              uploadUrl = initiateResponse.headers.get('Location')
              if (!uploadUrl) throw new Error('Did not receive location upload header from Google.')

            } catch (initErr) {
              reject(new Error(`Failed to initiate Google Drive upload: ${initErr.message}`))
              return
            }

            // Step 2: Upload raw file stream via XHR to track progress
            const xhr = new XMLHttpRequest()
            activeXhrRef.current = xhr
            xhr.open('PUT', uploadUrl)
            
            xhr.upload.addEventListener('progress', (e) => {
              if (e.lengthComputable) {
                const pct = Math.round((e.loaded / e.total) * 100)
                setProcessingText(`Uploading version (${pct}%)...`)
              }
            })

            xhr.onload = async () => {
              activeXhrRef.current = null
              if (xhr.status >= 200 && xhr.status < 300) {
                try {
                  const driveData = JSON.parse(xhr.responseText)
                  
                  // Delete old file version from Google Drive if specified
                  if (file.google_drive_file_id) {
                    console.log(`Deleting old file version from Google Drive: ${file.google_drive_file_id}`)
                    try {
                      await fetch(`https://www.googleapis.com/drive/v3/files/${file.google_drive_file_id}`, {
                        method: 'DELETE',
                        headers: {
                          'Authorization': `Bearer ${accessToken}`
                        }
                      })
                    } catch (delErr) {
                      console.error(`Failed to delete old file version:`, delErr)
                    }
                  }

                  resolve({ file_id: driveData.id, mime_type: driveData.mimeType })
                } catch (parseErr) {
                  reject(new Error('Failed to parse Google Drive response.'))
                }
              } else {
                reject(new Error(`Google Drive upload failed with status ${xhr.status}`))
              }
            }

            xhr.onerror = () => {
              activeXhrRef.current = null
              reject(new Error('Upload failed. Connection interrupted.'))
            }
            xhr.onabort = () => {
              activeXhrRef.current = null
              reject(new Error('Upload aborted.'))
            }

            xhr.send(selectedFile)
          })()

        } else {
          // Fallback to old Supabase Edge Function path (100MB limit)
          const xhr = new XMLHttpRequest()
          activeXhrRef.current = xhr
          const uploadUrl = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/upload-version`

          xhr.open('POST', uploadUrl)
          xhr.setRequestHeader('Authorization', `Bearer ${token}`)

          // Track upload progress
          xhr.upload.addEventListener('progress', (e) => {
            if (e.lengthComputable) {
              const pct = Math.round((e.loaded / e.total) * 100)
              setProcessingText(`Uploading version (${pct}%)...`)
            }
          })

          xhr.onload = () => {
            activeXhrRef.current = null
            if (xhr.status >= 200 && xhr.status < 300) {
              try {
                resolve(JSON.parse(xhr.responseText))
              } catch (parseErr) {
                resolve({ success: true })
              }
            } else {
              try {
                const errJson = JSON.parse(xhr.responseText)
                reject(new Error(errJson.error || `Server returned HTTP ${xhr.status}`))
              } catch (parseErr) {
                reject(new Error(`Server returned HTTP ${xhr.status}`))
              }
            }
          }

          xhr.onerror = () => {
            activeXhrRef.current = null
            reject(new Error('Network error. Connection failed.'))
          }
          xhr.onabort = () => {
            activeXhrRef.current = null
            reject(new Error('Upload aborted.'))
          }

          const formData = new FormData()
          formData.append('file', selectedFile)
          formData.append('folder_id', profile.drive_folder_id)
          formData.append('provider_token', googleToken)
          if (file.google_drive_file_id) {
            formData.append('old_file_id', file.google_drive_file_id)
          }
          xhr.send(formData)
        }
      })

      const newVersionNum = (file.current_version_num || 0) + 1

      // Delete all old version records to prevent DB bloating
      await supabase
        .from('file_versions')
        .delete()
        .eq('file_id', fileId)

      // Add version record
      await supabase.from('file_versions').insert({
        file_id: fileId,
        google_drive_file_id: result.file_id,
        version_number: newVersionNum,
      })

      // Update the main file details in shared_files
      await supabase
        .from('shared_files')
        .update({ 
          current_version_num: newVersionNum,
          google_drive_file_id: result.file_id,
          file_name: selectedFile.name,
          file_size: selectedFile.size,
          mime_type: result.mime_type || selectedFile.type
        })
        .eq('id', fileId)

      // Log
      await supabase.from('activity_logs').insert({
        user_id: user.id,
        action: 'version_upload',
        details: `Uploaded version ${newVersionNum} for: ${selectedFile.name}`,
      })

      toast.success(`Version ${newVersionNum} uploaded successfully`)
      loadData()
    } catch (err) {
      console.error(err)
      if (isCancelledRef.current) {
        toast.error('Upload cancelled')
      } else {
        toast.error(formatErrorMessage(err))
      }
    } finally {
      setUploading(false)
      setProcessingText(null)
      if (fileInputRef.current) fileInputRef.current.value = ''
    }
  }

  if (loading) {
    return (
      <div className="flex justify-center py-12">
        <div className="w-8 h-8 border-4 border-primary-600 border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }

  if (!file) {
    return (
      <div className="card text-center py-12">
        <p className="text-gray-400">File not found.</p>
        <button onClick={() => goBack()} className="btn-primary mt-4 text-sm">
          Back to Files
        </button>
      </div>
    )
  }

  return (
    <div className="space-y-6 font-sans">
      {/* Header */}
      <div className="flex items-center gap-4">
        <button
          onClick={() => goBack()}
          className="p-2 hover:bg-dark-500 rounded-lg animate-fade-in"
        >
          <ArrowLeft size={20} className="text-gray-400" />
        </button>
        <div>
          <h1 className="text-2xl font-bold text-gray-50">Version History</h1>
          <p className="text-sm text-gray-400">{file.file_name}</p>
        </div>
      </div>

      {/* Upload New Version */}
      <div className="card">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h3 className="font-semibold text-gray-100">Upload New Version</h3>
            <p className="text-sm text-gray-400 mt-1">
              The share link stays the same. Users always get the latest version.
            </p>
          </div>
          <input
            ref={fileInputRef}
            type="file"
            className="hidden"
            onChange={handleVersionUpload}
          />
          <button
            onClick={() => fileInputRef.current?.click()}
            disabled={uploading}
            className="btn-primary flex items-center gap-2 text-sm"
          >
            <Upload size={16} />
            {uploading ? 'Uploading...' : 'Upload Version'}
          </button>
        </div>
      </div>

      {/* Version List */}
      <div className="bg-dark-600 rounded-xl border border-dark-300 overflow-hidden">
        <div className="bg-dark-500 border-b border-dark-300 px-4 py-3">
          <h3 className="text-sm font-medium text-gray-200">
            {versions.length} Version{versions.length !== 1 ? 's' : ''}
          </h3>
        </div>
        <div className="divide-y divide-dark-400">
          {versions.length === 0 ? (
            <div className="py-8 text-center text-gray-400 text-sm">
              No versions yet
            </div>
          ) : (
            versions.map(version => {
              const isCurrent = version.version_number === file.current_version_num
              return (
                <div key={version.id} className="flex items-center justify-between px-4 py-3 hover:bg-dark-500">
                  <div className="flex items-center gap-3">
                    <div className={`w-8 h-8 rounded-lg flex items-center justify-center ${
                      isCurrent ? 'bg-primary-600/20 text-primary-400' : 'bg-dark-500 text-gray-400'
                    }`}>
                      {isCurrent ? <Check size={16} /> : <Clock size={16} />}
                    </div>
                    <div>
                      <p className="text-sm font-medium text-gray-100">
                        Version {version.version_number}
                        {isCurrent && (
                          <span className="ml-2 text-xs bg-primary-600/20 text-primary-400 px-2 py-0.5 rounded-full">
                            Active
                          </span>
                        )}
                      </p>
                      <p className="text-xs text-gray-400">
                        Uploaded {formatDate(version.uploaded_at)}
                      </p>
                    </div>
                  </div>
                </div>
              )
            })
          )}
        </div>
      </div>

      {/* Global Processing Loader Spinner */}
      {processingText && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-[9999] flex items-center justify-center p-4 animate-fade-in">
          <div className="bg-dark-600 border border-dark-400 rounded-2xl max-w-xs w-full p-6 space-y-4 shadow-2xl animate-scale-in text-center relative">
            <div className="relative w-16 h-16 mx-auto flex items-center justify-center">
              <div className="w-12 h-12 border-4 border-primary-500 border-t-transparent rounded-full animate-spin" />
              {uploading && (
                <button
                  type="button"
                  onClick={handleCancelUpload}
                  className="absolute top-0 right-0 bg-dark-500 hover:bg-red-500/20 text-gray-400 hover:text-red-400 border border-dark-300 hover:border-red-500/30 rounded-full p-1.5 transition-all duration-200 shadow-lg cursor-pointer"
                  title="Cancel Upload"
                >
                  <X size={14} />
                </button>
              )}
            </div>
            <p className="text-gray-200 text-sm font-medium font-['Space_Grotesk'] tracking-wide select-none">
              {processingText}
            </p>
          </div>
        </div>
      )}
    </div>
  )
}
