import { useState, useEffect, useRef } from 'react'
import { useAuth } from '../contexts/AuthContext'
import { supabase } from '../services/supabase'
import toast from 'react-hot-toast'
import {
  Search, Upload, MoreVertical, Download, Pencil, Trash2,
  Share2, History, FileText, Image, Video, Archive, Table,
  Presentation, File, SortAsc,
} from 'lucide-react'
import { formatFileSize, formatDate, getExtension, generateShareUrl } from '../utils/helpers'
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
  const existingNames = existingFiles.map(f => f.file_name.toLowerCase())
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
  const [files, setFiles] = useState([])
  const [loading, setLoading] = useState(true)
  const [uploading, setUploading] = useState(false)
  const [search, setSearch] = useState('')
  const [sortBy, setSortBy] = useState('created_at')
  const [sortDir, setSortDir] = useState('desc')
  const [activeMenu, setActiveMenu] = useState(null)
  const [renameModal, setRenameModal] = useState(null)
  const [shareModal, setShareModal] = useState(null)
  const [deleteConfirm, setDeleteConfirm] = useState(null)
  const [newName, setNewName] = useState('')
  const menuRef = useRef(null)

  useEffect(() => {
    loadFiles()
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
      const { data, error } = await supabase
        .from('shared_files')
        .select('*, file_versions(*)')
        .eq('user_id', user.id)
        .order(sortBy, { ascending: sortDir === 'asc' })

      if (error) throw error
      setFiles(data || [])
    } catch (err) {
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  async function handleUpload(e) {
    const file = e.target.files?.[0]
    if (!file) return

    // Generate unique name if file already exists in files list
    const uniqueName = getUniqueFileName(file.name, files)
    const uploadFile = uniqueName !== file.name 
      ? new File([file], uniqueName, { type: file.type })
      : file

    // Validate type
    const ext = uploadFile.name.split('.').pop().toLowerCase()
    if (BLOCKED_EXTENSIONS.includes(ext)) {
      toast.error('This file type is not allowed')
      return
    }

    const ALLOWED_EXTENSIONS = [
      'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
      'jpg', 'jpeg', 'png', 'gif', 'webp', 'svg',
      'mp4', 'mkv', 'mov', 'avi',
      'zip', 'rar', 'tar', 'gz', '7z', 'apk', 'xapk', 'txt'
    ]

    const isAllowedType = ALLOWED_TYPES.includes(uploadFile.type) ||
                          uploadFile.type.startsWith('image/') ||
                          uploadFile.type.startsWith('video/') ||
                          ALLOWED_EXTENSIONS.includes(ext)

    if (!isAllowedType) {
      toast.error('Unsupported file type')
      return
    }

    // Validate size (100MB)
    if (uploadFile.size > 100 * 1024 * 1024) {
      toast.error('File size exceeds 100MB limit')
      return
    }

    if (!profile?.drive_folder_id) {
      toast.error('Please configure your Google Drive folder in Settings first')
      return
    }

    setUploading(true)
    try {
      const { data: { session } } = await supabase.auth.getSession()
      const token = session?.access_token
      const googleToken = localStorage.getItem('google_provider_token') || session?.provider_token || ''

      // Upload via edge function
      const formData = new FormData()
      formData.append('file', uploadFile)
      formData.append('folder_id', profile.drive_folder_id)
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

      // Store metadata in Supabase
      const shareHash = crypto.randomUUID().replace(/-/g, '').substring(0, 12)

      const { error: insertError } = await supabase.from('shared_files').insert({
        user_id: user.id,
        google_drive_file_id: result.file_id,
        file_name: uploadFile.name,
        file_size: uploadFile.size,
        mime_type: uploadFile.type,
        current_version_num: 1,
        unique_share_hash: shareHash,
        sharing_status: 'private',
      })

      if (insertError) throw insertError

      // Add version record
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

      // Log activity
      await supabase.from('activity_logs').insert({
        user_id: user.id,
        action: 'upload',
        details: `Uploaded file: ${uploadFile.name}`,
      })

      toast.success(`${uploadFile.name} uploaded successfully`)
      loadFiles()
    } catch (err) {
      console.error(err)
      toast.error(err.message || 'Upload failed')
    } finally {
      setUploading(false)
      if (fileInputRef.current) fileInputRef.current.value = ''
    }
  }

  async function handleRename() {
    if (!newName.trim()) return
    try {
      const { data: { session } } = await supabase.auth.getSession()
      const token = session?.access_token
      const googleToken = localStorage.getItem('google_provider_token') || session?.provider_token || ''

      await fetch(
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
      toast.error('Failed to rename file')
    }
  }

  async function handleDelete() {
    try {
      const { data: { session } } = await supabase.auth.getSession()
      const token = session?.access_token
      const googleToken = localStorage.getItem('google_provider_token') || session?.provider_token || ''

      await fetch(
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
      toast.error('Failed to delete file')
    }
  }

  async function toggleSharing(file) {
    const newStatus = file.sharing_status === 'public' ? 'private' : 'public'
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
      toast.error('Failed to update sharing status')
    }
  }

  const filteredFiles = files.filter(f =>
    f.file_name?.toLowerCase().includes(search.toLowerCase())
  )

  function getIconComponent(mimeType) {
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
        <h1 className="text-2xl font-bold text-gray-50">My Files</h1>
        <div className="flex items-center gap-3">
          <input
            ref={fileInputRef}
            type="file"
            className="hidden"
            accept=".pdf,.docx,.xlsx,.pptx,.jpg,.jpeg,.png,.gif,.webp,.svg,.mp4,.mkv,.mov,.avi,.zip,.rar,.tar,.gz,.7z,.apk,.xapk,.txt"
            onChange={handleUpload}
          />
          <button
            onClick={() => fileInputRef.current?.click()}
            disabled={uploading}
            className="btn-primary flex items-center gap-2 text-sm"
          >
            <Upload size={16} />
            {uploading ? 'Uploading...' : 'Upload File'}
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
              <tbody className="divide-y divide-gray-100">
                {filteredFiles.map(file => {
                  const Icon = getIconComponent(file.mime_type)
                  return (
                    <tr key={file.id} className="hover:bg-dark-500">
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-3">
                          <div className="w-8 h-8 bg-gray-100 rounded-lg flex items-center justify-center flex-shrink-0">
                            <Icon size={16} className="text-gray-400" />
                          </div>
                          <div className="min-w-0">
                            <p className="text-sm font-medium text-gray-100 truncate">{file.file_name}</p>
                            <p className="text-xs text-gray-400">{getExtension(file.file_name)}</p>
                          </div>
                        </div>
                      </td>
                      <td className="px-4 py-3 text-sm text-gray-400 hidden sm:table-cell">
                        {formatFileSize(file.file_size || 0)}
                      </td>
                      <td className="px-4 py-3 text-sm text-gray-400 hidden md:table-cell">
                        v{file.current_version_num}
                      </td>
                      <td className="px-4 py-3">
                        <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${
                          file.sharing_status === 'public'
                            ? 'bg-green-100 text-green-700'
                            : 'bg-gray-100 text-gray-400'
                        }`}>
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
                            className="p-1.5 text-gray-400 hover:bg-gray-100 rounded-lg"
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
                                  navigator.clipboard.writeText(generateShareUrl(file.unique_share_hash))
                                  toast.success('Share link copied!')
                                  setActiveMenu(null)
                                }}
                                className="flex items-center gap-2 w-full px-4 py-2 text-sm text-gray-200 hover:bg-dark-500"
                              >
                                <Download size={16} />
                                Copy Share Link
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
                              <hr className="my-1 border-dark-400" />
                              <button
                                onClick={() => {
                                  setDeleteConfirm(file)
                                  setActiveMenu(null)
                                }}
                                className="flex items-center gap-2 w-full px-4 py-2 text-sm text-red-600 hover:bg-red-50"
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
