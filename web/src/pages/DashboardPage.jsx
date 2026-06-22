import { useEffect, useState } from 'react'
import { useAuth } from '../contexts/AuthContext'
import { supabase } from '../services/supabase'
import { Files, Share2, Globe, Download, FolderOpen } from 'lucide-react'
import { useNavigate } from 'react-router-dom'

export default function DashboardPage() {
  const { profile } = useAuth()
  const navigate = useNavigate()
  const [stats, setStats] = useState({
    totalFiles: 0,
    publicLinks: 0,
    privateLinks: 0,
    totalDownloads: 0,
  })
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function loadStats() {
      try {
        const { data: files } = await supabase
          .from('shared_files')
          .select('id, sharing_status')

        if (files) {
          setStats({
            totalFiles: files.length,
            publicLinks: files.filter(f => f.sharing_status === 'public').length,
            privateLinks: files.filter(f => f.sharing_status === 'private').length,
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
  }, [])

  // Check if folder is configured
  const showFolderWarning = !profile?.drive_folder_id

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">
          Welcome, {profile?.name || 'User'}
        </h1>
        <p className="text-gray-500 text-sm mt-1">
          Manage your files and share links from your dashboard.
        </p>
      </div>

      {/* Folder Warning */}
      {showFolderWarning && (
        <div className="bg-amber-50 border border-amber-200 rounded-xl p-4 flex items-start gap-3">
          <FolderOpen size={20} className="text-amber-500 mt-0.5 flex-shrink-0" />
          <div className="flex-1">
            <p className="text-sm font-medium text-amber-800">Google Drive folder not configured</p>
            <p className="text-xs text-amber-600 mt-0.5">
              Please connect your Google Drive folder in Settings to start uploading files.
            </p>
          </div>
          <button
            onClick={() => navigate('/dashboard/settings')}
            className="btn-primary text-xs py-1.5 px-3"
          >
            Configure
          </button>
        </div>
      )}

      {/* Stats Grid */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
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
          value={stats.publicLinks + stats.privateLinks}
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
        <h2 className="font-semibold text-gray-800 mb-4">Quick Actions</h2>
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
          <button
            onClick={() => navigate('/dashboard/files')}
            className="flex flex-col items-center gap-2 p-4 rounded-xl border border-gray-200 hover:bg-gray-50 transition-colors"
          >
            <div className="w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center">
              <Files size={20} className="text-blue-600" />
            </div>
            <span className="text-sm font-medium text-gray-700">My Files</span>
          </button>
          <button
            onClick={() => navigate('/dashboard/shared')}
            className="flex flex-col items-center gap-2 p-4 rounded-xl border border-gray-200 hover:bg-gray-50 transition-colors"
          >
            <div className="w-10 h-10 bg-purple-100 rounded-lg flex items-center justify-center">
              <Share2 size={20} className="text-purple-600" />
            </div>
            <span className="text-sm font-medium text-gray-700">Shared</span>
          </button>
          <button
            onClick={() => {
              navigate('/dashboard/files')
              window.dispatchEvent(new CustomEvent('trigger-upload'))
            }}
            className="flex flex-col items-center gap-2 p-4 rounded-xl border border-gray-200 hover:bg-gray-50 transition-colors"
          >
            <div className="w-10 h-10 bg-green-100 rounded-lg flex items-center justify-center">
              <Download size={20} className="text-green-600" />
            </div>
            <span className="text-sm font-medium text-gray-700">Upload</span>
          </button>
          <button
            onClick={() => navigate('/dashboard/settings')}
            className="flex flex-col items-center gap-2 p-4 rounded-xl border border-gray-200 hover:bg-gray-50 transition-colors"
          >
            <div className="w-10 h-10 bg-gray-100 rounded-lg flex items-center justify-center">
              <FolderOpen size={20} className="text-gray-600" />
            </div>
            <span className="text-sm font-medium text-gray-700">Settings</span>
          </button>
        </div>
      </div>
    </div>
  )
}

function StatCard({ icon: Icon, label, value, color, loading }) {
  const colors = {
    blue: 'bg-blue-50 text-blue-600',
    purple: 'bg-purple-50 text-purple-600',
    green: 'bg-green-50 text-green-600',
    orange: 'bg-amber-50 text-amber-600',
  }
  return (
    <div className="card flex items-center gap-4">
      <div className={`w-10 h-10 rounded-lg flex items-center justify-center ${colors[color]}`}>
        <Icon size={20} />
      </div>
      <div>
        <p className="text-2xl font-bold text-gray-800">
          {loading ? '—' : value}
        </p>
        <p className="text-xs text-gray-500">{label}</p>
      </div>
    </div>
  )
}
