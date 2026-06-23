import { useEffect, useState } from 'react'
import { useAuth } from '../contexts/AuthContext'
import { supabase } from '../services/supabase'
import { Files, Share2, Globe, Download, FolderOpen } from 'lucide-react'
import { useNavigate } from 'react-router-dom'

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

  useEffect(() => {
    async function loadStats() {
      if (!user) return
      try {
        const { data: files } = await supabase
          .from('shared_files')
          .select('id, sharing_status, unique_share_hash, is_folder')
          .eq('user_id', user.id)

        if (files) {
          setStats({
            totalFiles: files.filter(f => !f.is_folder).length,
            sharedFiles: files.filter(f => f.unique_share_hash !== null).length,
            publicLinks: files.filter(f => f.sharing_status === 'public' && f.unique_share_hash !== null).length,
            totalDownloads: 0,
          })
        }
      } catch (err) {
        console.error(err)
      } finally {
        setLoading(false)
      }
    }
    loadStats()
  }, [user])

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
        />
        <StatCard
          icon={Share2}
          label="Shared Files"
          value={stats.sharedFiles}
          color="purple"
          loading={loading}
        />
        <StatCard
          icon={Globe}
          label="Public Links"
          value={stats.publicLinks}
          color="green"
          loading={loading}
        />
        <StatCard
          icon={Download}
          label="Downloads"
          value={stats.totalDownloads}
          color="orange"
          loading={loading}
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
    </div>
  )
}

function StatCard({ icon: Icon, label, value, color, loading }) {
  const colors = {
    blue: 'bg-blue-600/20 text-blue-400',
    purple: 'bg-purple-600/20 text-purple-400',
    green: 'bg-green-600/20 text-green-400',
    orange: 'bg-amber-500/20 text-amber-400',
  }
  return (
    <div className="card flex items-center gap-4">
      <div className={`w-10 h-10 rounded-lg flex items-center justify-center ${colors[color]}`}>
        <Icon size={20} />
      </div>
      <div>
        <p className="text-2xl font-bold text-gray-100 leading-none">
          {loading ? '—' : value}
        </p>
        <p className="text-xs text-gray-400 mt-1">{label}</p>
      </div>
    </div>
  )
}
