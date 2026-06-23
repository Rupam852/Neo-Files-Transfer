import { useState, useEffect, useRef } from 'react'
import { useAuth } from '../contexts/AuthContext'
import { supabase } from '../services/supabase'
import toast from 'react-hot-toast'
import {
  Search, Upload, MoreVertical, Download, Pencil, Trash2,
  Share2, History, FileText, Image, Video, Archive, Table,
  Presentation, File, SortAsc, Plus, Folder, ChevronRight,
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

  function handleOpenFolder(folder) {
    setCurrentFolder(folder)
    setFolderPath(prev => [...prev, folder])
  }

  useEffect(() => {
    loadFiles()
  }, [currentFolder, sortBy, sortDir])

  useEffect(() => {
    window.addEventListener('trigger-upload', () => fileInputRef.current?.click())
    return () => window.removeEventListener('trigger-upload', () => {})
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
    setUploading(true)
    const { data: { session } } = await supabase.auth.getSession()
    const token = session?.access_token
    const googleToken = localStorage.getItem('google_provider_token') || session?.provider_token || ''

    for (let i = 0; i < batch.length; i++) {
      const item = batch[i]
      const file = item.fileObj ? item.fileObj : item
      const dbParentId = item.dbParentId !== undefined ? item.dbParentId : (currentFolder ? currentFolder.id : null)
      const driveParentId = item.driveParentId !== undefined ? item.driveParentId : (currentFolder ? currentFolder.google_drive_file_id : profile.drive_folder_id)

      setProcessingText(`Uploading file ${i + 1} of ${batch.length}: ${file.name}...`)

      try {
        const uniqueName = getUniqueFileName(file.name, files)

        const formData = new FormData()
        formData.append('file', file, uniqueName)
        formData.append('folder_id', driveParentId)
        formData.append('provider_token', googleToken)

        const res = await fetch(
          `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/upload-file`,
          {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${token}`,
            },
            body: formData,
          }
        )

        const result = await res.json()
        if (!res.ok) throw new Error(result.error || 'Upload failed')

        const shareHash = crypto.randomUUID().replace(/-/g, '').substring(0, 12)

        const { error: insertError } = await supabase.from('shared_files').insert({
          user_id: user.id,
          google_drive_file_id: result.file_id,
          file_name: uniqueName,
          file_size: file.size,
          mime_type: file.type,
          current_version_num: 1,
          unique_share_hash: shareHash,
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
    let currentBatchSize = 0

    for (const file of validFiles) {
      if (file.size > 100 * 1024 * 1024) {
        toast.error(`File ${file.name} exceeds 100MB limit and was skipped.`)
        continue
      }

      const item = {
        fileObj: file,
        dbParentId: currentFolder ? currentFolder.id : null,
        driveParentId: currentFolder ? currentFolder.google_drive_file_id : profile.drive_folder_id
      }

      if (currentBatchSize + file.size <= 100 * 1024 * 1024) {
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
    let currentBatchSize = 0

    for (const item of uploadQueue) {
      const file = item.fileObj ? item.fileObj : item
      if (currentBatchSize + file.size <= 100 * 1024 * 1024) {
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

      const shareHash = crypto.randomUUID().replace(/-/g, '').substring(0, 12)
      const { error: insertError } = await supabase.from('shared_files').insert({
        user_id: user.id,
        google_drive_file_id: result.file_id,
        file_name: folderName.trim(),
        mime_type: 'application/vnd.google-apps.folder',
        is_folder: true,
        current_version_num: 1,
        unique_share_hash: shareHash,
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

        const shareHash = crypto.randomUUID().replace(/-/g, '').substring(0, 12)
        const { data: dbRow, error: insertError } = await supabase
          .from('shared_files')
          .insert({
            user_id: user.id,
            google_drive_file_id: result.file_id,
            file_name: fName,
            mime_type: 'application/vnd.google-apps.folder',
            is_folder: true,
            current_version_num: 1,
            unique_share_hash: shareHash,
            sharing_status: 'private',
            parent_folder_id: parentDbId,
          })
          .select('id')
          .single()

        if (insertError) throw insertError

        pathLookup[path] = { dbId: dbRow.id, driveId: result.file_id }
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
      let currentBatchSize = 0

      for (const item of filesToUpload) {
        if (BLOCKED_EXTENSIONS.includes(item.fileObj.name.split('.').pop().toLowerCase())) {
          continue
        }

        if (item.fileObj.size > 100 * 1024 * 1024) {
          toast.error(`File ${item.fileObj.name} exceeds 100MB and was skipped.`)
          continue
        }

        if (currentBatchSize + item.fileObj.size <= 100 * 1024 * 1024) {
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
      toast.error(formatErrorMessage(err))
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
          <div className="overflow-x-auto flex-grow min-h-[280px]">
            <table className="w-full">
              <thead>
                <tr className="bg-dark-500 border-b border-dark-300">
                  <th className="text-left text-xs font-medium text-gray-400 uppercase tracking-wider px-4 py-3">File</th>
                  <th className="text-left text-xs font-medium text-gray-400 uppercase tracking-wider px-4 py-3 hidden sm:table-cell">Size</th>
                  <th className="text-left text-xs font-medium text-gray-400 uppercase tracking-wider px-4 py-3 hidden md:table-cell">Version</th>
                  <th className="text-left text-xs font-medium text-gray-400 uppercase tracking-wider px-4 py-3">Status</th>
                  <th className="text-left text-xs font-medium text-gray-400 uppercase tracking-wider px-4 py-3 hidden lg:table-cell">Date</th>
                  <th className="text-left text-xs font-medium text-gray-400 uppercase tracking-wider px-4 py-3">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-dark-400">
                {filteredFiles.map(file => {
                  const Icon = getIconComponent(file)
                  return (
                    <tr 
                      key={file.id} 
                      className="hover:bg-dark-500"
                      onDoubleClick={() => {
                        if (file.is_folder) {
                          handleOpenFolder(file)
                        }
                      }}
                    >
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-3">
                          <div className="w-8 h-8 bg-dark-500 rounded-lg flex items-center justify-center flex-shrink-0">
                            <Icon size={16} className="text-gray-400" />
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
                        <span className={`inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-medium border ${
                          file.sharing_status === 'public'
                            ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20'
                            : 'bg-amber-500/10 text-amber-400 border-amber-500/20'
                        }`}>
                          <span className={`w-1.5 h-1.5 rounded-full ${
                            file.sharing_status === 'public' ? 'bg-emerald-400 animate-pulse' : 'bg-amber-400'
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

      {/* Delete Confirm Modal */}
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

      {/* Share Links Modal */}
      {shareModal && (
        <Modal onClose={() => setShareModal(null)}>
          <div className="space-y-5 font-sans">
            <div>
              <h3 className="font-semibold text-gray-100 text-lg font-['Space_Grotesk'] mb-1">Share File</h3>
              <p className="text-xs text-gray-400 truncate">{shareModal.file_name}</p>
            </div>

            {/* Option A: Web Share Link */}
            <div className="space-y-1.5">
              <label className="block text-[11px] font-bold text-indigo-400 uppercase tracking-wider">
                Option A: Web Download Page Link
              </label>
              <div className="flex gap-2">
                <input
                  type="text"
                  readOnly
                  className="input-field text-xs bg-dark-500 py-2 border-dark-400 select-all"
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
                Opens the beautiful download page with real-time progress bar. Perfect for sharing with users.
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
                  className="input-field text-xs bg-dark-500 py-2 border-dark-400 select-all"
                  value={generateDirectDownloadUrl(shareModal.unique_share_hash)}
                />
                <button
                  onClick={() => {
                    navigator.clipboard.writeText(generateDirectDownloadUrl(shareModal.unique_share_hash))
                    toast.success('Direct download link copied!')
                  }}
                  className="btn-primary py-2 px-4 text-xs font-semibold shrink-0"
                >
                  Copy
                </button>
              </div>
              <p className="text-[11px] text-gray-400 leading-normal">
                Direct stream connection. Clicking this link in any browser or website starts downloading the file instantly in the background without redirecting.
              </p>
            </div>

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
            Some files were queued because the concurrent upload size exceeds the 100MB limit.
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

function Modal({ children, onClose }) {
  return (
    <div className="fixed inset-0 bg-black/40 z-50 flex items-center justify-center p-4" onClick={onClose}>
      <div className="bg-dark-600 rounded-xl shadow-xl p-6 w-full max-w-md" onClick={e => e.stopPropagation()}>
        {children}
      </div>
    </div>
  )
}
