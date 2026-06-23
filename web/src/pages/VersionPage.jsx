import { useEffect, useState, useRef } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext'
import { supabase } from '../services/supabase'
import toast from 'react-hot-toast'
import { ArrowLeft, Upload, Check, Clock } from 'lucide-react'
import { formatFileSize, formatDate } from '../utils/helpers'

export default function VersionPage({ fileId: propFileId, onBack }) {
  const { fileId: paramFileId } = useParams()
  const fileId = propFileId || paramFileId
  const { user, profile } = useAuth()
  const navigate = useNavigate()
  const goBack = onBack || (() => navigate('/dashboard/files'))
  const fileInputRef = useRef(null)
  const [file, setFile] = useState(null)
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

    if (selectedFile.size > 100 * 1024 * 1024) {
      toast.error('File size exceeds 100MB limit')
      return
    }

    if (!profile?.drive_folder_id) {
      toast.error('Please configure Google Drive folder in Settings')
      return
    }

    setUploading(true)
    setProcessingText('Uploading version...')
    try {
      const { data: { session } } = await supabase.auth.getSession()
      const token = session?.access_token
      const googleToken = localStorage.getItem('google_provider_token') || session?.provider_token || ''

      const formData = new FormData()
      formData.append('file', selectedFile)
      formData.append('folder_id', profile.drive_folder_id)
      formData.append('provider_token', googleToken)
      if (file.google_drive_file_id) {
        formData.append('old_file_id', file.google_drive_file_id)
      }

      const res = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/upload-version`,
        {
          method: 'POST',
          headers: { 'Authorization': `Bearer ${token}` },
          body: formData,
        }
      )

      const result = await res.json()
      if (!res.ok) throw new Error(result.error || 'Upload failed')

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
      toast.error(err.message || 'Version upload failed')
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
        <div className="flex items-center justify-between">
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
                      isCurrent ? 'bg-primary-600/20 text-primary-400' : 'bg-gray-100 text-gray-400'
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
          <div className="bg-dark-600 border border-dark-400 rounded-2xl max-w-xs w-full p-6 space-y-4 shadow-2xl animate-scale-in text-center">
            <div className="w-10 h-10 border-4 border-primary-500 border-t-transparent rounded-full animate-spin mx-auto" />
            <p className="text-gray-200 text-sm font-medium font-['Space_Grotesk'] tracking-wide">
              {processingText}
            </p>
          </div>
        </div>
      )}
    </div>
  )
}
