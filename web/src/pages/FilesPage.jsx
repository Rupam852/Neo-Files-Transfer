import { useState, useEffect, useRef } from 'react'
import { useAuth } from '../contexts/AuthContext'
import { supabase } from '../services/supabase'
import toast from 'react-hot-toast'
import {
  Search, Upload, MoreVertical, Download, Pencil, Trash2,
  Share2, History, FileText, Image, Video, Archive, Table,
  Presentation, File, SortAsc, Plus, Folder, ChevronRight,
  CheckSquare, Square, FolderInput, X,
} from 'lucide-react'
import { formatFileSize, formatDate, getExtension, generateShareUrl, generateDirectDownloadUrl, formatErrorMessage } from '../utils/helpers'
import { useNavigate } from 'react-router-dom'

const ALLOWED_TYPES = [
  'application/pdf',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'image/jpeg', 'image/png', 'video/mp4',
  'application/zip', 'application/x-zip-compressed',
  'application/vnd.android.package-archive',
]

const BLOCKED_EXTENSIONS = ['exe', 'bat', 'cmd', 'msi', 'scr']

function getUniqueFileName(originalName, existingFiles) {
  if (!existingFiles || !Array.isArray(existingFiles)) return originalName
  const existingNames = existingFiles
    .map(f => f && f.file_name ? f.file_name.toLowerCase() : '')
    .filter(name => name !== '')

  let name = originalName

  if (!existingNames.includes(name.toLowerCase())) {
    return name
  }

  const lastDotIndex = originalName.lastIndexOf('.')
  let baseName = originalName
  let ext = ''

  if (lastDotIndex !== -1) {
    baseName = originalName.substring(0, lastDotIndex)
    ext = originalName.substring(lastDotIndex)
  }

  let counter = 1
  while (existingNames.includes(`${baseName} (${counter})${ext}`.toLowerCase())) {
    counter++
  }

  return `${baseName} (${counter})${ext}`
}

const ICON_MAP = {
  'file-text': FileText,
  'image': Image,
  'video': Video,
  'archive': Archive,
  'table': Table,
  'presentation': Presentation,
  'file': File,
}

export default function FilesPage({ onViewVersions }) {
  const { user, profile } = useAuth()
  const navigate = useNavigate()
  const fileInputRef = useRef(null)
  const folderInputRef = useRef(null)
  const [files, setFiles] = useState([])
  const [loading, setLoading] = useState(true)
  const [uploading, setUploading] = useState(false)
  const [processingText, setProcessingText] = useState(null)
  const [search, setSearch] = useState('')
  const [sortBy, setSortBy] = useState('created_at')
  const [sortDir, setSortDir] = useState('desc')
  const [activeMenu, setActiveMenu] = useState(null)
  const [renameModal, setRenameModal] = useState(null)
  const [shareModal, setShareModal] = useState(null)
  const [deleteConfirm, setDeleteConfirm] = useState(null)
  const [newName, setNewName] = useState('')
  const menuRef = useRef(null)

  // Folders and batching states
  const [currentFolder, setCurrentFolder] = useState(null)
  const [folderPath, setFolderPath] = useState([])
  const [uploadQueue, setUploadQueue] = useState([])
  const [folderCreateModal, setFolderCreateModal] = useState(false)
  const [folderName, setFolderName] = useState('')

  // Multi-select states
  const [selectedIds, setSelectedIds] = useState(new Set())
  const [bulkDeleteConfirm, setBulkDeleteConfirm] = useState(false)
  const [moveModal, setMoveModal] = useState(false)
  const [allFolders, setAllFolders] = useState([])
  const lastSelectedIdx = useRef(null)
  const activeXhrRef = useRef(null)
  const isCancelledRef = useRef(false)

  function handleCancelUpload() {
    isCancelledRef.current = true
    if (activeXhrRef.current) {
      activeXhrRef.current.abort()
      activeXhrRef.current = null
    }
    setUploading(false)
    setProcessingText(null)
    setUploadQueue([])
  }

  function handleOpenFolder(folder) {
    setCurrentFolder(folder)
    setFolderPath(prev => [...prev, folder])
    setSelectedIds(new Set())
  }

  async function loadAllFolders() {
    const { data } = await supabase
      .from('shared_files')
      .select('id, file_name, parent_folder_id')
      .eq('user_id', user.id)
      .eq('is_folder', true)
    setAllFolders(data || [])
  }

  function toggleSelect(fileId, idx, e) {
    if (e.shiftKey && lastSelectedIdx.current !== null) {
      // Shift-click: select range
      const idxA = Math.min(lastSelectedIdx.current, idx)
      const idxB = Math.max(lastSelectedIdx.current, idx)
      setSelectedIds(prev => {
        const next = new Set(prev)
        filteredFiles.slice(idxA, idxB + 1).forEach(f => next.add(f.id))
        return next
      })
    } else {
      setSelectedIds(prev => {
        const next = new Set(prev)
        if (next.has(fileId)) next.delete(fileId)
        else next.add(fileId)
        return next
      })
    }
    lastSelectedIdx.current = idx
  }

  function toggleSelectAll() {
    if (selectedIds.size === filteredFiles.length) {
      setSelectedIds(new Set())
    } else {
      setSelectedIds(new Set(filteredFiles.map(f => f.id)))
    }
  }

  async function handleBulkDelete() {
    setProcessingText(`Deleting ${selectedIds.size} item(s)...`)
    setBulkDeleteConfirm(false)
    try {
      const { data: { session } } = await supabase.auth.getSession()
      const token = session?.access_token
      const googleToken = localStorage.getItem('google_provider_token') || session?.provider_token || ''
      const itemsToDelete = files.filter(f => selectedIds.has(f.id))

      for (const item of itemsToDelete) {
        try {
          const res = await fetch(
            `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/delete-file`,
            {
              method: 'POST',
              headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
              body: JSON.stringify({ file_id: item.google_drive_file_id, provider_token: googleToken }),
            }
          )
          if (!res.ok) {
            const r = await res.json().catch(() => ({}))
            console.warn(`Drive delete failed for ${item.file_name}:`, r.error)
          }
        } catch (e) {
          console.warn(`Drive delete error for ${item.file_name}:`, e)
        }
        // Always remove from DB even if Drive delete partially failed
        await supabase.from('file_versions').delete().eq('file_id', item.id)
        await supabase.from('shared_files').delete().eq('id', item.id)
      }

      await supabase.from('activity_logs').insert({
        user_id: user.id,
        action: 'bulk_delete',
        details: `Deleted ${itemsToDelete.length} item(s)`,
      })

      toast.success(`${itemsToDelete.length} item(s) deleted`)
      setSelectedIds(new Set())
      loadFiles()
    } catch (err) {
      toast.error(formatErrorMessage(err))
    } finally {
      setProcessingText(null)
    }
  }

  async function handleBulkMove(targetFolderId) {
    setProcessingText(`Moving ${selectedIds.size} item(s)...`)
    setMoveModal(false)
    try {
      const { error } = await supabase
        .from('shared_files')
        .update({ parent_folder_id: targetFolderId })
        .in('id', Array.from(selectedIds))

      if (error) throw error

      await supabase.from('activity_logs').insert({
        user_id: user.id,
        action: 'bulk_move',
        details: `Moved ${selectedIds.size} item(s)`,
      })

      toast.success(`${selectedIds.size} item(s) moved successfully`)
      setSelectedIds(new Set())
      loadFiles()
    } catch (err) {
      toast.error(formatErrorMessage(err))
    } finally {
      setProcessingText(null)
    }
  }

  useEffect(() => {
    loadFiles()
  }, [currentFolder, sortBy, sortDir])

  useEffect(() => {
    window.addEventListener('trigger-upload', () => fileInputRef.current?.click())
    return () => window.removeEventListener('trigger-upload', () => { })
  }, [])

  useEffect(() => {
    function handleClick(e) {
      if (menuRef.current && !menuRef.current.contains(e.target)) {
        setActiveMenu(null)
      }
    }
    document.addEventListener('click', handleClick)
    return () => document.removeEventListener('click', handleClick)
  }, [])

  async function loadFiles() {
    setLoading(true)
    try {
      let query = supabase
        .from('shared_files')
        .select('*, file_versions(*)')
        .eq('user_id', user.id)

      if (currentFolder) {
        query = query.eq('parent_folder_id', currentFolder.id)
      } else {
        query = query.is('parent_folder_id', null)
      }

      const { data, error } = await query.order(sortBy, { ascending: sortDir === 'asc' })

      if (error) throw error
      setFiles(data || [])
    } catch (err) {
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  async function uploadBatch(batch) {
    isCancelledRef.current = false
    setUploading(true)
    const { data: { session } } = await supabase.auth.getSession()
    const token = session?.access_token
    const googleToken = localStorage.getItem('google_provider_token') || session?.provider_token || ''

    for (let i = 0; i < batch.length; i++) {
      if (isCancelledRef.current) break
      const item = batch[i]
      const file = item.fileObj ? item.fileObj : item
      const dbParentId = item.dbParentId !== undefined ? item.dbParentId : (currentFolder ? currentFolder.id : null)
      const driveParentId = item.driveParentId !== undefined ? item.driveParentId : (currentFolder ? currentFolder.google_drive_file_id : profile.drive_folder_id)

      setProcessingText(`Uploading file ${i + 1} of ${batch.length}: ${file.name} (0%)...`)

      try {
        const uniqueName = getUniqueFileName(file.name, files)
        const proxyUrl = import.meta.env.VITE_PROXY_URL
        let result

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
                    'X-Upload-Content-Type': file.type || 'application/octet-stream'
                  },
                  body: JSON.stringify({
                    name: uniqueName,
                    parents: [driveParentId]
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
            throw new Error(`Failed to initiate Google Drive upload: ${initErr.message}`)
          }

          // Step 2: Upload raw file stream via XHR to track progress
          result = await new Promise((resolve, reject) => {
            const xhr = new XMLHttpRequest()
            activeXhrRef.current = xhr
            xhr.open('PUT', uploadUrl)
            
            xhr.upload.addEventListener('progress', (e) => {
              if (e.lengthComputable) {
                const pct = Math.round((e.loaded / e.total) * 100)
                setProcessingText(`Uploading file ${i + 1} of ${batch.length}: ${file.name} (${pct}%)`)
              }
            })

            xhr.onload = () => {
              activeXhrRef.current = null
              if (xhr.status >= 200 && xhr.status < 300) {
                try {
                  const driveData = JSON.parse(xhr.responseText)
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

            xhr.send(file)
          })

        } else {
          // Fallback to old Supabase Edge Function path (100MB limit)
          result = await new Promise((resolve, reject) => {
            const xhr = new XMLHttpRequest()
            activeXhrRef.current = xhr
            const uploadUrl = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/upload-file`

            xhr.open('POST', uploadUrl)
            xhr.setRequestHeader('Authorization', `Bearer ${token}`)

            // Track upload progress
            xhr.upload.addEventListener('progress', (e) => {
              if (e.lengthComputable) {
                const pct = Math.round((e.loaded / e.total) * 100)
                setProcessingText(`Uploading file ${i + 1} of ${batch.length}: ${file.name} (${pct}%)`)
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
            formData.append('file', file, uniqueName)
            formData.append('folder_id', driveParentId)
            formData.append('provider_token', googleToken)
            xhr.send(formData)
          })
        }

        const { error: insertError } = await supabase.from('shared_files').insert({
          user_id: user.id,
          google_drive_file_id: result.file_id,
          file_name: uniqueName,
          file_size: file.size,
          mime_type: file.type,
          current_version_num: 1,
          sharing_status: 'private',
          parent_folder_id: dbParentId,
        })

        if (insertError) throw insertError

        const { data: newFile } = await supabase
          .from('shared_files')
          .select('id')
          .eq('google_drive_file_id', result.file_id)
          .single()

        if (newFile) {
          await supabase.from('file_versions').insert({
            file_id: newFile.id,
            google_drive_file_id: result.file_id,
            version_number: 1,
          })
        }

        await supabase.from('activity_logs').insert({
          user_id: user.id,
          action: 'upload',
          details: `Uploaded file: ${uniqueName}`,
        })

        toast.success(`${uniqueName} uploaded successfully`)
      } catch (err) {
        console.error(err)
        if (isCancelledRef.current) {
          toast.error('Upload cancelled')
          break
        }
        toast.error(`Failed to upload ${file.name}: ${err.message}`)
      }
    }

    setUploading(false)
    setProcessingText(null)
    loadFiles()
  }

  async function handleUpload(e) {
    const filesSelected = Array.from(e.target.files)
    if (filesSelected.length === 0) return

    if (!profile?.drive_folder_id) {
      toast.error('Please configure your Google Drive folder in Settings first')
      return
    }

    const validFiles = filesSelected.filter(file => {
      const ext = file.name.split('.').pop().toLowerCase()
      return !BLOCKED_EXTENSIONS.includes(ext)
    })

    if (validFiles.length < filesSelected.length) {
      toast.error('Some files were skipped due to blocked file extensions.')
    }

    let currentBatch = []
    let remainingQueue = []
    const uploadLimit = import.meta.env.VITE_PROXY_URL ? 250 * 1024 * 1024 : 100 * 1024 * 1024
    const limitLabel = import.meta.env.VITE_PROXY_URL ? '250MB' : '100MB'
    let currentBatchSize = 0

    for (const file of validFiles) {
      if (file.size > uploadLimit) {
        toast.error(`File ${file.name} exceeds ${limitLabel} limit and was skipped.`)
        continue
      }

      const item = {
        fileObj: file,
        dbParentId: currentFolder ? currentFolder.id : null,
        driveParentId: currentFolder ? currentFolder.google_drive_file_id : profile.drive_folder_id
      }

      if (currentBatchSize + file.size <= uploadLimit) {
        currentBatch.push(item)
        currentBatchSize += file.size
      } else {
        remainingQueue.push(item)
      }
    }

    setUploadQueue(prev => [...prev, ...remainingQueue])

    if (currentBatch.length > 0) {
      await uploadBatch(currentBatch)
    }

    if (fileInputRef.current) fileInputRef.current.value = ''
  }

  async function handleUploadRemaining() {
    let currentBatch = []
    let remainingQueue = []
    const uploadLimit = import.meta.env.VITE_PROXY_URL ? 250 * 1024 * 1024 : 100 * 1024 * 1024
    let currentBatchSize = 0

    for (const item of uploadQueue) {
      const file = item.fileObj ? item.fileObj : item
      if (currentBatchSize + file.size <= uploadLimit) {
        currentBatch.push(item)
        currentBatchSize += file.size
      } else {
        remainingQueue.push(item)
      }
    }

    setUploadQueue(remainingQueue)

    if (currentBatch.length > 0) {
      await uploadBatch(currentBatch)
    }
  }

  async function handleCreateFolder() {
    if (!folderName.trim()) return
    setProcessingText('Creating folder...')
    try {
      if (!profile?.drive_folder_id) {
        toast.error('Please configure your Google Drive folder in Settings first')
        return
      }

      const { data: { session } } = await supabase.auth.getSession()
      const token = session?.access_token

      const parentDriveFolderId = currentFolder ? currentFolder.google_drive_file_id : profile.drive_folder_id

      const res = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/create-folder`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            name: folderName.trim(),
            parent_drive_folder_id: parentDriveFolderId,
          }),
        }
      )

      const result = await res.json()
      if (!res.ok) throw new Error(result.error || 'Failed to create folder')

      const { error: insertError } = await supabase.from('shared_files').insert({
        user_id: user.id,
        google_drive_file_id: result.file_id,
        file_name: folderName.trim(),
        mime_type: 'application/vnd.google-apps.folder',
        is_folder: true,
        current_version_num: 1,
        sharing_status: 'private',
        parent_folder_id: currentFolder ? currentFolder.id : null,
      })

      if (insertError) throw insertError

      await supabase.from('activity_logs').insert({
        user_id: user.id,
        action: 'create_folder',
        details: `Created folder: ${folderName.trim()}`,
      })

      toast.success(`Folder ${folderName.trim()} created successfully`)
      setFolderCreateModal(false)
      loadFiles()
    } catch (err) {
      console.error(err)
      toast.error(formatErrorMessage(err))
    } finally {
      setProcessingText(null)
    }
  }

  async function handleFolderUpload(e) {
    const filesUploaded = Array.from(e.target.files)
    if (filesUploaded.length === 0) return

    if (!profile?.drive_folder_id) {
      toast.error('Please configure your Google Drive folder in Settings first')
      return
    }

    isCancelledRef.current = false
    setUploading(true)
    setProcessingText('Analyzing folder structure...')

    try {
      const pathsToCreate = new Set()

      for (const file of filesUploaded) {
        if (!file.webkitRelativePath) continue
        const parts = file.webkitRelativePath.split('/')
        parts.pop()

        let currentPath = ''
        for (const part of parts) {
          currentPath = currentPath ? `${currentPath}/${part}` : part
          pathsToCreate.add(currentPath)
        }
      }

      const sortedPaths = Array.from(pathsToCreate).sort((a, b) => {
        const depthA = a.split('/').length
        const depthB = b.split('/').length
        return depthA - depthB
      })

      const { data: { session } } = await supabase.auth.getSession()
      const token = session?.access_token

      const pathLookup = {}

      for (const path of sortedPaths) {
        if (isCancelledRef.current) break
        const parts = path.split('/')
        const fName = parts[parts.length - 1]

        let parentDbId = currentFolder ? currentFolder.id : null
        let parentDriveId = currentFolder ? currentFolder.google_drive_file_id : profile.drive_folder_id

        if (parts.length > 1) {
          parts.pop()
          const parentPath = parts.join('/')
          const parentInfo = pathLookup[parentPath]
          if (parentInfo) {
            parentDbId = parentInfo.dbId
            parentDriveId = parentInfo.driveId
          }
        }

        setProcessingText(`Creating folder: ${path}...`)

        const res = await fetch(
          `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/create-folder`,
          {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${token}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              name: fName,
              parent_drive_folder_id: parentDriveId,
            }),
          }
        )

        const result = await res.json()
        if (!res.ok) throw new Error(result.error || `Failed to create folder ${fName}`)

        const { data: dbRow, error: insertError } = await supabase
          .from('shared_files')
          .insert({
            user_id: user.id,
            google_drive_file_id: result.file_id,
            file_name: fName,
            mime_type: 'application/vnd.google-apps.folder',
            is_folder: true,
            current_version_num: 1,
            sharing_status: 'private',
            parent_folder_id: parentDbId,
          })
          .select('id')
          .single()

        if (insertError) throw insertError

        pathLookup[path] = { dbId: dbRow.id, driveId: result.file_id }
      }

      if (isCancelledRef.current) {
        throw new Error('Upload cancelled')
      }

      const filesToUpload = filesUploaded.map(file => {
        const parts = file.webkitRelativePath.split('/')
        parts.pop()
        const folderPathStr = parts.join('/')

        const folderInfo = pathLookup[folderPathStr]
        return {
          fileObj: file,
          dbParentId: folderInfo?.dbId || null,
          driveParentId: folderInfo?.driveId || profile.drive_folder_id
        }
      })

      let currentBatch = []
      let remainingQueue = []
      const uploadLimit = import.meta.env.VITE_PROXY_URL ? 250 * 1024 * 1024 : 100 * 1024 * 1024
      const limitLabel = import.meta.env.VITE_PROXY_URL ? '250MB' : '100MB'
      let currentBatchSize = 0

      for (const item of filesToUpload) {
        if (isCancelledRef.current) break
        if (BLOCKED_EXTENSIONS.includes(item.fileObj.name.split('.').pop().toLowerCase())) {
          continue
        }

        if (item.fileObj.size > uploadLimit) {
          toast.error(`File ${item.fileObj.name} exceeds ${limitLabel} and was skipped.`)
          continue
        }

        if (currentBatchSize + item.fileObj.size <= uploadLimit) {
          currentBatch.push(item)
          currentBatchSize += item.fileObj.size
        } else {
          remainingQueue.push(item)
        }
      }

      setUploadQueue(prev => [...prev, ...remainingQueue])

      if (currentBatch.length > 0) {
        await uploadBatch(currentBatch)
      }

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
      if (folderInputRef.current) folderInputRef.current.value = ''
    }
  }

  async function handleRename() {
    if (!newName.trim()) return
    setProcessingText('Renaming file...')
    try {
      const { data: { session } } = await supabase.auth.getSession()
      const token = session?.access_token
      const googleToken = localStorage.getItem('google_provider_token') || session?.provider_token || ''

      const res = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/rename-file`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            file_id: renameModal.google_drive_file_id,
            new_name: newName,
            provider_token: googleToken,
          }),
        }
      )

      if (!res.ok) {
        const result = await res.json().catch(() => ({}))
        throw new Error(result.error || 'Failed to rename file in Google Drive')
      }

      const ext = renameModal.file_name.split('.').pop()
      const fullName = newName.includes('.') ? newName : `${newName}.${ext}`

      await supabase
        .from('shared_files')
        .update({ file_name: fullName })
        .eq('id', renameModal.id)

      await supabase.from('activity_logs').insert({
        user_id: user.id,
        action: 'rename',
        details: `Renamed file to: ${fullName}`,
      })

      toast.success('File renamed successfully')
      setRenameModal(null)
      loadFiles()
    } catch (err) {
      toast.error(formatErrorMessage(err))
    } finally {
      setProcessingText(null)
    }
  }

  async function handleDelete() {
    setProcessingText('Deleting file...')
    try {
      const { data: { session } } = await supabase.auth.getSession()
      const token = session?.access_token
      const googleToken = localStorage.getItem('google_provider_token') || session?.provider_token || ''

      const res = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/delete-file`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            file_id: deleteConfirm.google_drive_file_id,
            provider_token: googleToken,
          }),
        }
      )

      if (!res.ok) {
        const result = await res.json().catch(() => ({}))
        throw new Error(result.error || 'Failed to delete file from Google Drive')
      }

      // Delete versions first
      await supabase.from('file_versions').delete().eq('file_id', deleteConfirm.id)

      // Delete file record
      await supabase.from('shared_files').delete().eq('id', deleteConfirm.id)

      await supabase.from('activity_logs').insert({
        user_id: user.id,
        action: 'delete',
        details: `Deleted file: ${deleteConfirm.file_name}`,
      })

      toast.success('File deleted successfully')
      setDeleteConfirm(null)
      loadFiles()
    } catch (err) {
      toast.error(formatErrorMessage(err))
    } finally {
      setProcessingText(null)
    }
  }

  async function toggleSharing(file) {
    const newStatus = file.sharing_status === 'public' ? 'private' : 'public'
    setProcessingText(newStatus === 'public' ? 'Making file public...' : 'Making file private...')
    try {
      await supabase
        .from('shared_files')
        .update({ sharing_status: newStatus })
        .eq('id', file.id)

      await supabase.from('activity_logs').insert({
        user_id: user.id,
        action: 'share',
        details: `Toggled sharing to ${newStatus}: ${file.file_name}`,
      })

      toast.success(`File is now ${newStatus}`)
      loadFiles()
    } catch (err) {
      toast.error(formatErrorMessage(err))
    } finally {
      setProcessingText(null)
    }
  }

  const filteredFiles = files
    .filter(f => f.file_name?.toLowerCase().includes(search.toLowerCase()))
    .sort((a, b) => {
      if (a.is_folder && !b.is_folder) return -1
      if (!a.is_folder && b.is_folder) return 1
      return 0
    })

  function getIconComponent(file) {
    if (file.is_folder) return Folder
    const mimeType = file.mime_type
    const type = mimeType?.startsWith('image/') ? 'image' :
      mimeType?.startsWith('video/') ? 'video' :
        mimeType?.includes('pdf') ? 'file-text' :
          mimeType?.includes('zip') ? 'archive' :
            mimeType?.includes('spreadsheet') ? 'table' :
              mimeType?.includes('presentation') ? 'presentation' : 'file'
    const Icon = ICON_MAP[type] || File
    return Icon
  }

  return (
    <div className="space-y-4 flex flex-col min-h-[calc(100vh-150px)] lg:min-h-[calc(100vh-180px)]">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        {/* Title / Breadcrumb navigation */}
        <div className="flex flex-wrap items-center gap-2 text-xl md:text-2xl font-bold text-gray-50">
          <button
            onClick={() => {
              setCurrentFolder(null)
              setFolderPath([])
            }}
            className="hover:text-primary-400 transition-colors duration-200 text-left"
          >
            My Files
          </button>
          {folderPath.map((folder, index) => (
            <span key={folder.id} className="flex items-center gap-2">
              <ChevronRight size={18} className="text-gray-500" />
              <button
                onClick={() => {
                  setCurrentFolder(folder)
                  setFolderPath(folderPath.slice(0, index + 1))
                }}
                className="hover:text-primary-400 transition-colors duration-200 text-left"
              >
                {folder.file_name}
              </button>
            </span>
          ))}
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <input
            ref={fileInputRef}
            type="file"
            className="hidden"
            multiple
            accept=".pdf,.docx,.xlsx,.pptx,.jpg,.jpeg,.png,.gif,.webp,.svg,.mp4,.mkv,.mov,.avi,.zip,.rar,.tar,.gz,.7z,.apk,.xapk,.txt"
            onChange={handleUpload}
          />
          <input
            ref={folderInputRef}
            type="file"
            className="hidden"
            webkitdirectory="true"
            directory="true"
            multiple
            onChange={handleFolderUpload}
          />

          <button
            onClick={() => setFolderCreateModal(true)}
            disabled={uploading}
            className="btn-secondary flex items-center gap-2 text-sm"
          >
            <Plus size={16} />
            New Folder
          </button>

          <button
            onClick={() => folderInputRef.current?.click()}
            disabled={uploading}
            className="btn-secondary flex items-center gap-2 text-sm"
          >
            <Folder size={16} />
            Upload Folder
          </button>

          <button
            onClick={() => fileInputRef.current?.click()}
            disabled={uploading}
            className="btn-primary flex items-center gap-2 text-sm"
          >
            <Upload size={16} />
            {uploading ? 'Uploading...' : 'Upload Files'}
          </button>
        </div>
      </div>

      {/* Search & Sort */}
      <div className="flex flex-col sm:flex-row gap-3">
        <div className="relative flex-1 max-w-md">
          <Search size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            placeholder="Search files..."
            className="input-field pl-10"
            value={search}
            onChange={e => setSearch(e.target.value)}
          />
        </div>
        <div className="flex items-center gap-2">
          <SortAsc size={16} className="text-gray-400" />
          <select
            className="input-field w-auto text-sm"
            value={`${sortBy}-${sortDir}`}
            onChange={e => {
              const [by, dir] = e.target.value.split('-')
              setSortBy(by)
              setSortDir(dir)
              loadFiles()
            }}
          >
            <option value="created_at-desc">Newest First</option>
            <option value="created_at-asc">Oldest First</option>
            <option value="file_name-asc">Name A-Z</option>
            <option value="file_name-desc">Name Z-A</option>
            <option value="file_size-desc">Largest First</option>
            <option value="file_size-asc">Smallest First</option>
          </select>
        </div>
      </div>

      {/* File List */}
      {loading ? (
        <div className="flex justify-center py-12">
          <div className="w-8 h-8 border-4 border-primary-600 border-t-transparent rounded-full animate-spin" />
        </div>
      ) : filteredFiles.length === 0 ? (
        <div className="card text-center py-12">
          <FileText size={48} className="mx-auto text-gray-300 mb-4" />
          <p className="text-gray-400">No files yet. Upload your first file to get started.</p>
        </div>
      ) : (
        <div className="bg-dark-600 rounded-xl border border-dark-300 overflow-hidden flex-1 flex flex-col">
          {/* Selection Toolbar */}
          {selectedIds.size > 0 && (
            <div className="flex items-center gap-3 px-4 py-2.5 bg-primary-500/10 border-b border-primary-500/20 animate-fade-in">
              <span className="text-sm font-semibold text-primary-400 flex items-center gap-2">
                <CheckSquare size={15} />
                {selectedIds.size} selected
              </span>
              <div className="flex items-center gap-2 ml-auto">
                <button
                  onClick={() => { loadAllFolders(); setMoveModal(true) }}
                  className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-indigo-500/15 text-indigo-400 border border-indigo-500/20 text-xs font-semibold hover:bg-indigo-500/25 transition-all"
                >
                  <FolderInput size={13} /> Move
                </button>
                <button
                  onClick={() => setBulkDeleteConfirm(true)}
                  className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-red-500/10 text-red-400 border border-red-500/20 text-xs font-semibold hover:bg-red-500/20 transition-all"
                >
                  <Trash2 size={13} /> Delete
                </button>
                <button
                  onClick={() => setSelectedIds(new Set())}
                  className="p-1.5 rounded-lg text-gray-500 hover:text-gray-300 hover:bg-dark-400 transition-all"
                  title="Clear selection"
                >
                  <X size={14} />
                </button>
              </div>
            </div>
          )}
          <div className="overflow-x-auto flex-grow min-h-[280px]">
            <table className="w-full">
              <thead>
                <tr className="bg-dark-500 border-b border-dark-300">
                  <th className="px-4 py-3 w-10">
                    <button
                      onClick={toggleSelectAll}
                      className="text-gray-400 hover:text-primary-400 transition-colors"
                      title={selectedIds.size === filteredFiles.length ? 'Deselect all' : 'Select all'}
                    >
                      {selectedIds.size === filteredFiles.length && filteredFiles.length > 0
                        ? <CheckSquare size={16} className="text-primary-400" />
                        : <Square size={16} />}
                    </button>
                  </th>
                  <th className="text-left text-xs font-medium text-gray-400 uppercase tracking-wider px-4 py-3">File</th>
                  <th className="text-left text-xs font-medium text-gray-400 uppercase tracking-wider px-4 py-3 hidden sm:table-cell">Size</th>
                  <th className="text-left text-xs font-medium text-gray-400 uppercase tracking-wider px-4 py-3 hidden md:table-cell">Version</th>
                  <th className="text-left text-xs font-medium text-gray-400 uppercase tracking-wider px-4 py-3">Status</th>
                  <th className="text-left text-xs font-medium text-gray-400 uppercase tracking-wider px-4 py-3 hidden lg:table-cell">Date</th>
                  <th className="text-left text-xs font-medium text-gray-400 uppercase tracking-wider px-4 py-3">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-dark-400">
                {filteredFiles.map((file, idx) => {
                  const Icon = getIconComponent(file)
                  const isSelected = selectedIds.has(file.id)
                  return (
                    <tr
                      key={file.id}
                      className={`transition-colors duration-100 ${isSelected ? 'bg-primary-500/8 hover:bg-primary-500/12' : 'hover:bg-dark-500'
                        }`}
                      onDoubleClick={() => {
                        if (file.is_folder) handleOpenFolder(file)
                      }}
                    >
                      {/* Checkbox */}
                      <td className="px-4 py-3 w-10">
                        <button
                          onClick={(e) => { e.stopPropagation(); toggleSelect(file.id, idx, e) }}
                          className="text-gray-500 hover:text-primary-400 transition-colors"
                        >
                          {isSelected
                            ? <CheckSquare size={16} className="text-primary-400" />
                            : <Square size={16} />}
                        </button>
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-3">
                          <div className={`w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0 transition-colors ${isSelected ? 'bg-primary-500/20' : 'bg-dark-500'
                            }`}>
                            <Icon size={16} className={isSelected ? 'text-primary-400' : 'text-gray-400'} />
                          </div>
                          <div className="min-w-0">
                            {file.is_folder ? (
                              <button
                                onClick={() => handleOpenFolder(file)}
                                className="text-sm font-medium text-gray-100 hover:text-primary-400 text-left truncate w-full"
                              >
                                {file.file_name}
                              </button>
                            ) : (
                              <p className="text-sm font-medium text-gray-100 truncate">{file.file_name}</p>
                            )}
                            <p className="text-xs text-gray-400">
                              {file.is_folder ? 'Folder' : getExtension(file.file_name)}
                            </p>
                          </div>
                        </div>
                      </td>
                      <td className="px-4 py-3 text-sm text-gray-400 hidden sm:table-cell">
                        {file.is_folder ? '—' : formatFileSize(file.file_size || 0)}
                      </td>
                      <td className="px-4 py-3 text-sm text-gray-400 hidden md:table-cell">
                        {file.is_folder ? '—' : `v${file.current_version_num}`}
                      </td>
                      <td className="px-4 py-3">
                        <span className={`inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-medium border ${file.sharing_status === 'public'
                            ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20'
                            : 'bg-amber-500/10 text-amber-400 border-amber-500/20'
                          }`}>
                          <span className={`w-1.5 h-1.5 rounded-full ${file.sharing_status === 'public' ? 'bg-emerald-400 animate-pulse' : 'bg-amber-400'
                            }`} />
                          {file.sharing_status}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-sm text-gray-400 hidden lg:table-cell">
                        {formatDate(file.created_at)}
                      </td>
                      <td className="px-4 py-3">
                        <div className="relative">
                          <button
                            onClick={(e) => {
                              e.stopPropagation()
                              setActiveMenu(activeMenu === file.id ? null : file.id)
                            }}
                            className="p-1.5 text-gray-400 hover:bg-dark-500 rounded-lg"
                          >
                            <MoreVertical size={16} />
                          </button>
                          {activeMenu === file.id && (
                            <div
                              ref={menuRef}
                              onClick={(e) => e.stopPropagation()}
                              className="absolute right-0 mt-1 w-48 bg-dark-600 rounded-lg shadow-xl border border-dark-400 py-1 z-50"
                            >
                              <button
                                onClick={() => { toggleSharing(file); setActiveMenu(null) }}
                                className="flex items-center gap-2 w-full px-4 py-2 text-sm text-gray-200 hover:bg-dark-500"
                              >
                                <Share2 size={16} />
                                {file.sharing_status === 'public' ? 'Make Private' : 'Make Public'}
                              </button>
                              <button
                                onClick={() => {
                                  setShareModal(file)
                                  setActiveMenu(null)
                                }}
                                className="flex items-center gap-2 w-full px-4 py-2 text-sm text-gray-200 hover:bg-dark-500"
                              >
                                <Share2 size={16} />
                                {file.is_folder ? 'Share Folder' : 'Share File'}
                              </button>
                              <button
                                onClick={() => {
                                  setRenameModal(file)
                                  setNewName(file.file_name.replace(/\.[^/.]+$/, ''))
                                  setActiveMenu(null)
                                }}
                                className="flex items-center gap-2 w-full px-4 py-2 text-sm text-gray-200 hover:bg-dark-500"
                              >
                                <Pencil size={16} />
                                Rename
                              </button>
                              {!file.is_folder && (
                                <button
                                  onClick={() => {
                                    if (onViewVersions) {
                                      onViewVersions(file.id)
                                    } else {
                                      navigate(`/dashboard/files/${file.id}/versions`)
                                    }
                                    setActiveMenu(null)
                                  }}
                                  className="flex items-center gap-2 w-full px-4 py-2 text-sm text-gray-200 hover:bg-dark-500"
                                >
                                  <History size={16} />
                                  Manage Versions
                                </button>
                              )}
                              <hr className="my-1 border-dark-400" />
                              <button
                                onClick={() => {
                                  setDeleteConfirm(file)
                                  setActiveMenu(null)
                                }}
                                className="flex items-center gap-2 w-full px-4 py-2 text-sm text-red-400 hover:bg-red-500/10 rounded-lg"
                              >
                                <Trash2 size={16} />
                                Delete
                              </button>
                            </div>
                          )}
                        </div>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Rename Modal */}
      {renameModal && (
        <Modal onClose={() => setRenameModal(null)}>
          <h3 className="font-semibold text-gray-100 mb-4">Rename File</h3>
          <input
            type="text"
            className="input-field mb-4"
            value={newName}
            onChange={e => setNewName(e.target.value)}
            autoFocus
          />
          <div className="flex justify-end gap-2">
            <button className="btn-secondary text-sm" onClick={() => setRenameModal(null)}>Cancel</button>
            <button className="btn-primary text-sm" onClick={handleRename}>Rename</button>
          </div>
        </Modal>
      )}

      {/* Delete Confirm Modal (single) */}
      {deleteConfirm && (
        <Modal onClose={() => setDeleteConfirm(null)}>
          <h3 className="font-semibold text-gray-100 mb-2">Delete File</h3>
          <p className="text-sm text-gray-400 mb-4">
            Are you sure you want to delete <strong>{deleteConfirm.file_name}</strong>?
            This action cannot be undone.
          </p>
          <div className="flex justify-end gap-2">
            <button className="btn-secondary text-sm" onClick={() => setDeleteConfirm(null)}>Cancel</button>
            <button className="btn-danger text-sm" onClick={handleDelete}>Delete</button>
          </div>
        </Modal>
      )}

      {/* Bulk Delete Confirm Modal */}
      {bulkDeleteConfirm && (
        <Modal onClose={() => setBulkDeleteConfirm(false)}>
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 bg-red-500/10 border border-red-500/20 rounded-xl flex items-center justify-center text-red-400">
              <Trash2 size={18} />
            </div>
            <div>
              <h3 className="font-semibold text-gray-100">Delete {selectedIds.size} item(s)?</h3>
              <p className="text-xs text-gray-400">This cannot be undone.</p>
            </div>
          </div>
          <p className="text-sm text-gray-400 mb-5">
            You are about to permanently delete <strong className="text-gray-200">{selectedIds.size}</strong> selected file(s) and/or folder(s). All contents and sub-files will also be deleted.
          </p>
          <div className="flex justify-end gap-2">
            <button className="btn-secondary text-sm" onClick={() => setBulkDeleteConfirm(false)}>Cancel</button>
            <button className="btn-danger text-sm" onClick={handleBulkDelete}>Delete All</button>
          </div>
        </Modal>
      )}

      {/* Move To Modal */}
      {moveModal && (
        <Modal onClose={() => setMoveModal(false)}>
          <h3 className="font-semibold text-gray-100 mb-1 text-lg font-['Space_Grotesk']">Move {selectedIds.size} item(s) to...</h3>
          <p className="text-xs text-gray-400 mb-4">Select a destination folder</p>
          <div className="space-y-1 max-h-64 overflow-y-auto pr-1">
            {/* Root option */}
            <button
              onClick={() => handleBulkMove(null)}
              disabled={currentFolder === null}
              className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm text-left transition-all ${currentFolder === null
                  ? 'opacity-40 cursor-not-allowed bg-dark-500'
                  : 'hover:bg-dark-500 text-gray-200'
                }`}
            >
              <Folder size={16} className="text-yellow-400 flex-shrink-0" />
              <span className="font-medium">Root (My Files)</span>
              {currentFolder === null && <span className="ml-auto text-xs text-gray-500">current</span>}
            </button>
            {/* All folders */}
            {allFolders
              .filter(f => !selectedIds.has(f.id))
              .map(folder => (
                <button
                  key={folder.id}
                  onClick={() => handleBulkMove(folder.id)}
                  disabled={currentFolder?.id === folder.id}
                  className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm text-left transition-all ${currentFolder?.id === folder.id
                      ? 'opacity-40 cursor-not-allowed bg-dark-500'
                      : 'hover:bg-dark-500 text-gray-200'
                    }`}
                >
                  <Folder size={16} className="text-yellow-400 flex-shrink-0" />
                  <span className="truncate">{folder.file_name}</span>
                  {currentFolder?.id === folder.id && <span className="ml-auto text-xs text-gray-500">current</span>}
                </button>
              ))
            }
            {allFolders.filter(f => !selectedIds.has(f.id)).length === 0 && currentFolder !== null && (
              <p className="text-xs text-gray-500 text-center py-4">No other folders available</p>
            )}
          </div>
          <div className="flex justify-end pt-4">
            <button className="btn-secondary text-sm" onClick={() => setMoveModal(false)}>Cancel</button>
          </div>
        </Modal>
      )}

      {/* Share Links Modal */}
      {shareModal && (
        <Modal onClose={() => setShareModal(null)}>
          <div className="space-y-5 font-sans">
            <div>
              <h3 className="font-semibold text-gray-100 text-lg font-['Space_Grotesk'] mb-1">
                {shareModal.is_folder ? 'Share Folder' : 'Share File'}
              </h3>
              <p className="text-xs text-gray-400 truncate">{shareModal.file_name}</p>
            </div>

            {!shareModal.unique_share_hash ? (
              /* No link generated yet — show generate button */
              <div className="space-y-4">
                <div className="bg-dark-500 border border-dark-400 rounded-xl p-4 text-center space-y-3">
                  <div className="w-12 h-12 bg-indigo-500/10 border border-indigo-500/20 rounded-xl flex items-center justify-center mx-auto text-indigo-400">
                    <Share2 size={22} />
                  </div>
                  <div>
                    <p className="text-sm font-semibold text-gray-200">No share link yet</p>
                    <p className="text-xs text-gray-400 mt-1 leading-relaxed">
                      Generate a permanent share link for this {shareModal.is_folder ? 'folder' : 'file'}.
                      The link will be stored and can be copied anytime from this menu.
                    </p>
                  </div>
                </div>
                <button
                  onClick={async () => {
                    try {
                      const newHash = crypto.randomUUID().replace(/-/g, '').substring(0, 12)
                      const { error } = await supabase
                        .from('shared_files')
                        .update({ unique_share_hash: newHash, sharing_status: 'public' })
                        .eq('id', shareModal.id)
                      if (error) throw error
                      // Refresh local files list and update modal state with new hash
                      setShareModal(prev => ({ ...prev, unique_share_hash: newHash, sharing_status: 'public' }))
                      loadFiles()
                      toast.success('Share links generated!')
                    } catch (err) {
                      toast.error('Failed to generate share link: ' + err.message)
                    }
                  }}
                  className="w-full btn-primary py-3 flex items-center justify-center gap-2 font-semibold"
                >
                  <Share2 size={16} /> Generate Share Links
                </button>
              </div>
            ) : (
              /* Links already generated */
              <>
                {/* Status row */}
                <div className="flex items-center justify-between gap-3">
                  {shareModal.sharing_status === 'public' ? (
                    <div className="flex items-center gap-2 px-3 py-1.5 bg-emerald-500/10 border border-emerald-500/20 rounded-lg flex-1">
                      <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse flex-shrink-0" />
                      <p className="text-xs text-emerald-400 font-medium">Public — link is active</p>
                    </div>
                  ) : (
                    <div className="flex items-center gap-2 px-3 py-1.5 bg-amber-500/10 border border-amber-500/20 rounded-lg flex-1">
                      <span className="w-2 h-2 rounded-full bg-amber-400 flex-shrink-0" />
                      <p className="text-xs text-amber-400 font-medium">Private — link is blocked</p>
                    </div>
                  )}
                  {/* Inline toggle button */}
                  <button
                    onClick={async () => {
                      const newStatus = shareModal.sharing_status === 'public' ? 'private' : 'public'
                      try {
                        const { error } = await supabase
                          .from('shared_files')
                          .update({ sharing_status: newStatus })
                          .eq('id', shareModal.id)
                        if (error) throw error
                        setShareModal(prev => ({ ...prev, sharing_status: newStatus }))
                        loadFiles()
                        toast.success(`Link is now ${newStatus}`)
                      } catch (err) {
                        toast.error('Failed to update: ' + err.message)
                      }
                    }}
                    className={`shrink-0 px-3 py-1.5 rounded-lg text-xs font-semibold border transition-all ${shareModal.sharing_status === 'public'
                        ? 'bg-amber-500/10 text-amber-400 border-amber-500/20 hover:bg-amber-500/20'
                        : 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20 hover:bg-emerald-500/20'
                      }`}
                  >
                    {shareModal.sharing_status === 'public' ? '🔒 Make Private' : '🌐 Make Public'}
                  </button>
                </div>

                {/* Private warning */}
                {shareModal.sharing_status === 'private' && (
                  <div className="bg-amber-500/5 border border-amber-500/15 rounded-lg px-3 py-2 text-xs text-amber-300/80 leading-relaxed">
                    ⚠️ Link is currently <strong>blocked</strong>. Anyone visiting this link will see an "Access Denied" page. Click <strong>Make Public</strong> above to re-enable it. The link URL will not change.
                  </div>
                )}

                {/* Option A: Web Share Link */}
                <div className="space-y-1.5">
                  <label className="block text-[11px] font-bold text-indigo-400 uppercase tracking-wider">
                    Option A: Web Download Page Link
                  </label>
                  <div className="flex gap-2">
                    <input
                      type="text"
                      readOnly
                      className={`input-field text-xs bg-dark-500 py-2 border-dark-400 select-all transition-opacity ${shareModal.sharing_status === 'private' ? 'opacity-50' : ''}`}
                      value={generateShareUrl(shareModal.unique_share_hash)}
                    />
                    <button
                      onClick={() => {
                        navigator.clipboard.writeText(generateShareUrl(shareModal.unique_share_hash))
                        toast.success('Web download link copied!')
                      }}
                      className="btn-primary py-2 px-4 text-xs font-semibold shrink-0"
                    >
                      Copy
                    </button>
                  </div>
                  <p className="text-[11px] text-gray-400 leading-normal">
                    Opens the beautiful download page with real-time progress bar.
                  </p>
                </div>

                {/* Option B: Direct API Download Link */}
                <div className="space-y-1.5">
                  <label className="block text-[11px] font-bold text-pink-400 uppercase tracking-wider">
                    Option B: Direct Download Link
                  </label>
                  <div className="flex gap-2">
                    <input
                      type="text"
                      readOnly
                      className={`input-field text-xs bg-dark-500 py-2 border-dark-400 select-all transition-opacity ${shareModal.sharing_status === 'private' ? 'opacity-50' : ''}`}
                      value={generateDirectDownloadUrl(shareModal.unique_share_hash, shareModal.is_folder)}
                    />
                    <button
                      onClick={() => {
                        navigator.clipboard.writeText(generateDirectDownloadUrl(shareModal.unique_share_hash, shareModal.is_folder))
                        toast.success('Direct download link copied!')
                      }}
                      className="btn-primary py-2 px-4 text-xs font-semibold shrink-0"
                    >
                      Copy
                    </button>
                  </div>
                  <p className="text-[11px] text-gray-400 leading-normal">
                    Direct stream connection. Clicking this link starts downloading instantly.
                  </p>
                </div>
              </>
            )}

            <div className="flex justify-end pt-2">
              <button className="btn-secondary text-xs py-2 px-4" onClick={() => setShareModal(null)}>
                Close
              </button>
            </div>
          </div>
        </Modal>
      )}

      {/* Create Folder Modal */}
      {folderCreateModal && (
        <Modal onClose={() => { setFolderCreateModal(false); setFolderName('') }}>
          <h3 className="font-semibold text-gray-100 mb-4 text-lg font-['Space_Grotesk']">Create New Folder</h3>
          <input
            type="text"
            placeholder="Folder name"
            className="input-field mb-4"
            value={folderName}
            onChange={e => setFolderName(e.target.value)}
            autoFocus
          />
          <div className="flex justify-end gap-2">
            <button
              className="btn-secondary text-sm"
              onClick={() => { setFolderCreateModal(false); setFolderName('') }}
            >
              Cancel
            </button>
            <button
              className="btn-primary text-sm"
              onClick={handleCreateFolder}
              disabled={!folderName.trim()}
            >
              Create
            </button>
          </div>
        </Modal>
      )}

      {/* Floating Queue Panel */}
      {uploadQueue.length > 0 && (
        <div className="fixed bottom-6 right-6 bg-dark-600 border border-dark-400 rounded-xl shadow-2xl p-4 max-w-sm w-full z-50 animate-scale-in">
          <div className="flex items-center justify-between gap-4 mb-3">
            <h4 className="text-sm font-semibold text-gray-100">Upload Queue</h4>
            <span className="text-xs bg-primary-500/10 text-primary-400 px-2 py-0.5 rounded-full font-medium">
              {uploadQueue.length} {uploadQueue.length === 1 ? 'file' : 'files'} remaining
            </span>
          </div>
          <p className="text-xs text-gray-400 mb-3 leading-relaxed">
            Some files were queued because the concurrent upload size exceeds the {import.meta.env.VITE_PROXY_URL ? '250MB' : '100MB'} limit.
          </p>
          <div className="flex gap-2">
            <button
              onClick={handleUploadRemaining}
              disabled={uploading}
              className="btn-primary w-full text-xs py-2"
            >
              {uploading ? 'Uploading Batch...' : 'Upload Remaining Files'}
            </button>
            <button
              onClick={() => setUploadQueue([])}
              className="btn-secondary text-xs py-2 px-3 hover:text-red-400 transition-colors"
              title="Clear queue"
            >
              Clear
            </button>
          </div>
        </div>
      )}

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

function Modal({ children, onClose }) {
  return (
    <div className="fixed inset-0 bg-black/40 z-50 flex items-center justify-center p-4" onClick={onClose}>
      <div className="bg-dark-600 rounded-xl shadow-xl p-6 w-full max-w-md" onClick={e => e.stopPropagation()}>
        {children}
      </div>
    </div>
  )
}
