import { useEffect, useState } from 'react'
import { useAuth } from '../contexts/AuthContext'
import { supabase } from '../services/supabase'
import toast from 'react-hot-toast'
import { Copy, Globe, Lock, Link2 } from 'lucide-react'
import { generateShareUrl, generateDirectDownloadUrl, formatDate } from '../utils/helpers'

export default function SharedFilesPage() {
  const { user } = useAuth()
  const [files, setFiles] = useState([])
  const [loading, setLoading] = useState(true)
  const [processingText, setProcessingText] = useState(null)
  const [shareModal, setShareModal] = useState(null)

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
    setProcessingText(newStatus === 'public' ? 'Making file public...' : 'Making file private...')
    try {
      await supabase
        .from('shared_files')
        .update({ sharing_status: newStatus })
        .eq('id', file.id)

      toast.success(`Link is now ${newStatus}`)
      loadSharedFiles()
    } catch (err) {
      toast.error('Failed to update')
    } finally {
      setProcessingText(null)
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
                  <span className={`inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-medium border ${
                    file.sharing_status === 'public'
                      ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20'
                      : 'bg-amber-500/10 text-amber-400 border-amber-500/20'
                  }`}>
                    {file.sharing_status === 'public' ? <Globe size={12} className="text-emerald-400 animate-pulse" /> : <Lock size={12} className="text-amber-400" />}
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
                  onClick={() => setShareModal(file)}
                  className="btn-secondary text-sm flex items-center gap-1.5"
                >
                  <Copy size={14} /> Share
                </button>
                <button
                  onClick={() => toggleStatus(file)}
                  className={`text-sm flex items-center gap-1.5 py-2 px-4 rounded-lg font-medium transition-colors border ${
                    file.sharing_status === 'public'
                      ? 'bg-dark-500 text-gray-300 border-dark-300 hover:bg-dark-400 hover:text-gray-200'
                      : 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20 hover:bg-emerald-500/20'
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

      {/* Share Links Modal */}
      {shareModal && (
        <div className="fixed inset-0 bg-black/40 z-50 flex items-center justify-center p-4" onClick={() => setShareModal(null)}>
          <div className="bg-dark-600 rounded-xl shadow-xl p-6 w-full max-w-md" onClick={e => e.stopPropagation()}>
            <div className="space-y-5 font-sans text-left">
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
