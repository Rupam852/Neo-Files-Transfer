import { useEffect, useState } from 'react'
import { useAuth } from '../contexts/AuthContext'
import { supabase } from '../services/supabase'
import toast from 'react-hot-toast'
import { Copy, Globe, Lock, Link2 } from 'lucide-react'
import { generateShareUrl, formatDate } from '../utils/helpers'

export default function SharedFilesPage() {
  const { user } = useAuth()
  const [files, setFiles] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    loadSharedFiles()
  }, [])

  async function loadSharedFiles() {
    try {
      const { data } = await supabase
        .from('shared_files')
        .select('*')
        .eq('user_id', user.id)
        .order('created_at', { ascending: false })

      setFiles(data || [])
    } catch (err) {
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  async function toggleStatus(file) {
    const newStatus = file.sharing_status === 'public' ? 'private' : 'public'
    try {
      await supabase
        .from('shared_files')
        .update({ sharing_status: newStatus })
        .eq('id', file.id)

      toast.success(`Link is now ${newStatus}`)
      loadSharedFiles()
    } catch (err) {
      toast.error('Failed to update')
    }
  }

  function copyLink(hash) {
    navigator.clipboard.writeText(generateShareUrl(hash))
    toast.success('Link copied to clipboard!')
  }

  if (loading) {
    return (
      <div className="flex justify-center py-12">
        <div className="w-8 h-8 border-4 border-primary-600 border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-bold text-gray-50">Shared Files</h1>
      <p className="text-gray-500 text-sm">
        Manage your file share links. Toggle between public and private access.
      </p>

      {files.length === 0 ? (
        <div className="card text-center py-12">
          <Link2 size={48} className="mx-auto text-gray-500 mb-4" />
          <p className="text-gray-500">No shared files yet. Upload a file to generate a share link.</p>
        </div>
      ) : (
        <div className="space-y-3">
          {files.map(file => (
            <div key={file.id} className="card flex flex-col sm:flex-row sm:items-center gap-4">
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 mb-1">
                  <h3 className="text-sm font-medium text-gray-100 truncate">{file.file_name}</h3>
                  <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium ${
                    file.sharing_status === 'public'
                      ? 'bg-green-900/30 text-green-400'
                      : 'bg-dark-500 text-gray-500'
                  }`}>
                    {file.sharing_status === 'public' ? <Globe size={12} /> : <Lock size={12} />}
                    {file.sharing_status}
                  </span>
                </div>
                <div className="flex items-center gap-2">
                  <code className="text-xs text-gray-500 bg-dark-500 px-2 py-1 rounded truncate max-w-xs">
                    {generateShareUrl(file.unique_share_hash)}
                  </code>
                </div>
                <p className="text-xs text-gray-500 mt-1">
                  Created {formatDate(file.created_at)} · v{file.current_version_num}
                </p>
              </div>
              <div className="flex items-center gap-2 flex-shrink-0">
                <button
                  onClick={() => copyLink(file.unique_share_hash)}
                  className="btn-secondary text-sm flex items-center gap-1.5"
                >
                  <Copy size={14} /> Copy
                </button>
                <button
                  onClick={() => toggleStatus(file)}
                  className={`text-sm flex items-center gap-1.5 py-2 px-4 rounded-lg font-medium transition-colors ${
                    file.sharing_status === 'public'
                      ? 'bg-dark-500 text-gray-500 hover:bg-dark-400'
                      : 'bg-green-900/30 text-green-400 hover:bg-green-200'
                  }`}
                >
                  {file.sharing_status === 'public' ? (
                    <><Lock size={14} /> Make Private</>
                  ) : (
                    <><Globe size={14} /> Make Public</>
                  )}
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
