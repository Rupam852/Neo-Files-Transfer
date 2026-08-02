import { useEffect, useState } from 'react'
import { useAuth } from '../contexts/AuthContext'
import { supabase } from '../services/supabase'
import { Files, Share2, Globe, Download, FolderOpen, X, Copy, Check, ExternalLink } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { toast } from 'react-hot-toast'

export default function DashboardPage({ onNavigate }) {
  const { user, profile } = useAuth()
  const navigate = useNavigate()

  function goTo(path) {
    if (onNavigate) {
      const tab = path.split('/').pop() || 'dashboard'
      onNavigate(tab)
    } else {
      navigate(path)
    }
  }

  const [stats, setStats] = useState({
    totalFiles: 0,
    sharedFiles: 0,
    publicLinks: 0,
    totalDownloads: 0,
  })
  const [loading, setLoading] = useState(true)
  const [downloadFilesList, setDownloadFilesList] = useState([])
  const [showDownloadsModal, setShowDownloadsModal] = useState(false)
  const [copiedId, setCopiedId] = useState(null)

  useEffect(() => {
    async function loadStats() {
      if (!user) return
      try {
        const { data: files } = await supabase
          .from('shared_files')
          .select('id, file_name, sharing_status, unique_share_hash, is_folder, download_count, created_at')
          .eq('user_id', user.id)

        if (files) {
          const sumDownloads = files.reduce((acc, f) => acc + (f.download_count || 0), 0)
          setStats({
            totalFiles: files.filter(f => !f.is_folder).length,
            sharedFiles: files.filter(f => f.unique_share_hash !== null).length,
            publicLinks: files.filter(f => f.sharing_status === 'public' && f.unique_share_hash !== null).length,
            totalDownloads: sumDownloads,
          })

          // Filter files that have generated share links or downloads > 0
          const trackedFiles = files
            .filter(f => f.unique_share_hash !== null || (f.download_count || 0) > 0)
            .sort((a, b) => (b.download_count || 0) - (a.download_count || 0))

          setDownloadFilesList(trackedFiles)
        }
      } catch (err) {
        console.error(err)
      } finally {
        setLoading(false)
      }
    }
    loadStats()
  }, [user])

  function copyShareLink(hash, id) {
    const link = `${window.location.origin}/s/${hash}`
    navigator.clipboard.writeText(link)
    setCopiedId(id)
    toast.success('Share link copied!')
    setTimeout(() => setCopiedId(null), 2000)
  }

  // Check if folder is configured
  const showFolderWarning = !profile?.drive_folder_id

  return (
    <div className="space-y-6">
      {/* Welcome */}
      <div>
        <h1 className="text-2xl font-bold text-gray-50">
          Welcome, {profile?.name || 'User'}
        </h1>
        <p className="text-gray-400 text-sm mt-1">
          Manage your files and share links from your dashboard.
        </p>
      </div>

      {/* Folder Warning */}
      {showFolderWarning && (
        <div className="bg-amber-900/30 border border-amber-600/30 rounded-xl p-4 flex items-start gap-3">
          <FolderOpen size={20} className="text-amber-400 mt-0.5 flex-shrink-0" />
          <div className="flex-1">
            <p className="text-sm font-medium text-amber-200">Google Drive folder not configured</p>
            <p className="text-xs text-amber-400 mt-0.5">
              Please connect your Google Drive folder in Settings to start uploading files.
            </p>
          </div>
          <button
            onClick={() => goTo('/dashboard/settings')}
            className="btn-primary text-xs py-1.5 px-3"
          >
            Configure
          </button>
        </div>
      )}

      {/* Stats Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          icon={Files}
          label="Total Files"
          value={stats.totalFiles}
          color="blue"
          loading={loading}
          onClick={() => goTo('/dashboard/files')}
          hint="Click to view files"
        />
        <StatCard
          icon={Share2}
          label="Shared Files"
          value={stats.sharedFiles}
          color="purple"
          loading={loading}
          onClick={() => goTo('/dashboard/shared')}
          hint="Click to view shared links"
        />
        <StatCard
          icon={Globe}
          label="Public Links"
          value={stats.publicLinks}
          color="green"
          loading={loading}
          onClick={() => goTo('/dashboard/shared')}
          hint="Click to view public links"
        />
        <StatCard
          icon={Download}
          label="Downloads"
          value={stats.totalDownloads}
          color="orange"
          loading={loading}
          onClick={() => setShowDownloadsModal(true)}
          hint="Click for download counts"
        />
      </div>

      {/* Quick Actions */}
      <div className="card">
        <h2 className="font-semibold text-gray-100 mb-4">Quick Actions</h2>
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
          <button
            onClick={() => goTo('/dashboard/files')}
            className="flex flex-col items-center gap-2 p-4 rounded-xl border border-dark-400 hover:bg-dark-500 transition-colors"
          >
            <div className="w-10 h-10 bg-dark-500 border-dark-400 hover:bg-dark-400 rounded-lg flex items-center justify-center">
              <Files size={20} className="text-blue-400" />
            </div>
            <span className="text-sm font-medium text-gray-200">My Files</span>
          </button>
          <button
            onClick={() => goTo('/dashboard/shared')}
            className="flex flex-col items-center gap-2 p-4 rounded-xl border border-dark-400 hover:bg-dark-500 transition-colors"
          >
            <div className="w-10 h-10 bg-dark-500 border-dark-400 rounded-lg flex items-center justify-center">
              <Share2 size={20} className="text-purple-400" />
            </div>
            <span className="text-sm font-medium text-gray-200">Shared</span>
          </button>
          <button
            onClick={() => {
              goTo('/dashboard/files')
              window.dispatchEvent(new CustomEvent('trigger-upload'))
            }}
            className="flex flex-col items-center gap-2 p-4 rounded-xl border border-dark-400 hover:bg-dark-500 transition-colors"
          >
            <div className="w-10 h-10 bg-dark-500 border-dark-400 rounded-lg flex items-center justify-center">
              <Download size={20} className="text-green-400" />
            </div>
            <span className="text-sm font-medium text-gray-200">Upload</span>
          </button>
          <button
            onClick={() => goTo('/dashboard/settings')}
            className="flex flex-col items-center gap-2 p-4 rounded-xl border border-dark-400 hover:bg-dark-500 transition-colors"
          >
            <div className="w-10 h-10 bg-dark-500 border-dark-400 rounded-lg flex items-center justify-center">
              <FolderOpen size={20} className="text-gray-400" />
            </div>
            <span className="text-sm font-medium text-gray-200">Settings</span>
          </button>
        </div>
      </div>

      {/* Downloads Breakdown Modal */}
      {showDownloadsModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/75 backdrop-blur-sm animate-fade-in" onClick={() => setShowDownloadsModal(false)}>
          <div className="bg-dark-600 border border-dark-400 rounded-2xl w-full max-w-lg shadow-2xl overflow-hidden flex flex-col max-h-[85vh]" onClick={(e) => e.stopPropagation()}>
            {/* Header */}
            <div className="flex items-center justify-between px-6 py-4 border-b border-dark-400 bg-dark-700/50">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-amber-500/20 flex items-center justify-center text-amber-400">
                  <Download size={20} />
                </div>
                <div>
                  <h3 className="text-lg font-bold text-gray-100">Download Statistics</h3>
                  <p className="text-xs text-gray-400">
                    Total Downloads: <span className="font-semibold text-amber-400">{stats.totalDownloads}</span>
                  </p>
                </div>
              </div>
              <button
                onClick={() => setShowDownloadsModal(false)}
                className="p-1.5 text-gray-400 hover:text-gray-200 hover:bg-dark-500 rounded-lg transition-colors"
              >
                <X size={18} />
              </button>
            </div>

            {/* Content List */}
            <div className="p-6 overflow-y-auto space-y-3 flex-1">
              {downloadFilesList.length === 0 ? (
                <div className="text-center py-8 text-gray-400">
                  <Download size={36} className="mx-auto mb-2 text-gray-500" />
                  <p className="text-sm font-medium">No generated share links yet.</p>
                  <p className="text-xs text-gray-500 mt-1">Generate a share link on any file to track its download counts.</p>
                </div>
              ) : (
                downloadFilesList.map((file) => (
                  <div key={file.id} className="flex items-center justify-between p-3.5 bg-dark-500/60 border border-dark-400/60 rounded-xl hover:border-dark-300 transition-all">
                    <div className="min-w-0 flex-1 pr-3">
                      <div className="flex items-center gap-2 mb-1">
                        <span className={`px-2 py-0.5 text-[10px] font-semibold rounded-full border ${
                          file.sharing_status === 'public'
                            ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20'
                            : 'bg-amber-500/10 text-amber-400 border-amber-500/20'
                        }`}>
                          {file.sharing_status}
                        </span>
                        <p className="text-sm font-medium text-gray-100 truncate">{file.file_name}</p>
                      </div>
                      <p className="text-xs text-gray-400 truncate">
                        Link: {window.location.origin}/s/{file.unique_share_hash}
                      </p>
                    </div>

                    <div className="flex items-center gap-2.5 flex-shrink-0">
                      <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-amber-500/15 border border-amber-500/30 text-amber-300 text-xs font-bold">
                        <Download size={13} />
                        {file.download_count || 0}
                      </span>
                      <button
                        onClick={() => copyShareLink(file.unique_share_hash, file.id)}
                        className="p-2 bg-dark-400 hover:bg-dark-300 text-gray-300 rounded-lg transition-colors"
                        title="Copy Share Link"
                      >
                        {copiedId === file.id ? <Check size={15} className="text-emerald-400" /> : <Copy size={15} />}
                      </button>
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

function StatCard({ icon: Icon, label, value, color, loading, onClick, hint }) {
  const colors = {
    blue: 'bg-blue-600/20 text-blue-400',
    purple: 'bg-purple-600/20 text-purple-400',
    green: 'bg-green-600/20 text-green-400',
    orange: 'bg-amber-500/20 text-amber-400',
  }
  return (
    <div
      onClick={onClick}
      className="card flex items-center gap-4 cursor-pointer hover:border-primary-500/40 hover:bg-dark-500/40 transition-all group relative"
      title={hint}
    >
      <div className={`w-10 h-10 rounded-lg flex items-center justify-center ${colors[color]}`}>
        <Icon size={20} />
      </div>
      <div className="flex-1">
        <p className="text-2xl font-bold text-gray-100 leading-none">
          {loading ? '—' : value}
        </p>
        <p className="text-xs text-gray-400 mt-1">{label}</p>
      </div>
    </div>
  )
}
