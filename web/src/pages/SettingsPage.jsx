import { useState } from 'react'
import { useAuth } from '../contexts/AuthContext'
import { supabase } from '../services/supabase'
import { useNavigate } from 'react-router-dom'
import toast from 'react-hot-toast'
import { User, FolderInput, Shield, LogOut, Check, AlertTriangle } from 'lucide-react'
import { extractFolderId } from '../utils/helpers'

export default function SettingsPage() {
  const { profile, signOut, refreshProfile } = useAuth()
  const navigate = useNavigate()
  const [activeTab, setActiveTab] = useState('profile')
  const [displayName, setDisplayName] = useState(profile?.name || '')
  const [folderUrl, setFolderUrl] = useState('')
  const [saving, setSaving] = useState(false)
  const [verifying, setVerifying] = useState(false)

  const tabs = [
    { id: 'profile', label: 'Profile', icon: User },
    { id: 'drive', label: 'Google Drive', icon: FolderInput },
    { id: 'security', label: 'Security', icon: Shield },
  ]

  async function saveProfile() {
    setSaving(true)
    try {
      const { error } = await supabase
        .from('user_profiles')
        .update({ name: displayName })
        .eq('id', profile.id)

      if (error) throw error
      toast.success('Profile updated')
      refreshProfile()
    } catch (err) {
      toast.error('Failed to update profile')
    } finally {
      setSaving(false)
    }
  }

  async function verifyAndSaveFolder() {
    if (!folderUrl.trim()) {
      toast.error('Please enter a Google Drive folder link')
      return
    }

    const folderId = extractFolderId(folderUrl)
    if (!folderId) {
      toast.error('Invalid Google Drive folder URL')
      return
    }

    setVerifying(true)
    try {
      const { data: { session } } = await supabase.auth.getSession()
      const token = session?.access_token

      const res = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/validate-folder`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ folder_id: folderId }),
        }
      )

      const result = await res.json()
      if (!res.ok) throw new Error(result.error || 'Folder validation failed')

      // Save folder ID
      const { error } = await supabase
        .from('user_profiles')
        .update({
          drive_folder_id: folderId,
          is_folder_verified: true,
        })
        .eq('id', profile.id)

      if (error) throw error

      toast.success('Folder connected successfully!')
      refreshProfile()
    } catch (err) {
      console.error(err)
      toast.error(err.message || 'This folder is not publicly accessible.')
    } finally {
      setVerifying(false)
    }
  }

  async function handleSignOut() {
    await supabase.from('activity_logs').insert({
      user_id: profile?.id,
      action: 'logout',
      details: 'User logged out',
    })
    await signOut()
    navigate('/login')
  }

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-gray-50">Settings</h1>

      {/* Tabs */}
      <div className="flex items-center gap-1 bg-dark-600 rounded-lg border border-dark-400 p-1 w-fit">
        {tabs.map(tab => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={`flex items-center gap-2 px-4 py-2 rounded-md text-sm font-medium transition-colors ${
              activeTab === tab.id ? 'bg-primary-600 text-white' : 'text-gray-300 hover:bg-dark-500'
            }`}
          >
            <tab.icon size={16} />
            {tab.label}
          </button>
        ))}
      </div>

      {/* Profile Tab */}
      {activeTab === 'profile' && (
        <div className="card max-w-lg space-y-4">
          <div className="flex items-center gap-4 pb-4 border-b border-dark-400">
            <img
              src={profile?.avatar_url || '/favicon.svg'}
              alt="Avatar"
              className="w-16 h-16 rounded-full object-cover"
            />
            <div>
              <p className="font-medium text-gray-100">{profile?.name}</p>
              <p className="text-sm text-gray-500">{profile?.email}</p>
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-200 mb-1">Display Name</label>
            <input
              type="text"
              className="input-field"
              value={displayName}
              onChange={e => setDisplayName(e.target.value)}
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-200 mb-1">Email</label>
            <input
              type="email"
              className="input-field bg-dark-500 cursor-not-allowed"
              value={profile?.email || ''}
              disabled
            />
          </div>
          <button
            onClick={saveProfile}
            disabled={saving}
            className="btn-primary text-sm"
          >
            {saving ? 'Saving...' : 'Save Changes'}
          </button>
        </div>
      )}

      {/* Drive Tab */}
      {activeTab === 'drive' && (
        <div className="card max-w-lg space-y-4">
          <h3 className="font-semibold text-gray-100">Google Drive Folder</h3>
          <p className="text-sm text-gray-500">
            Connect your Google Drive folder where Neo Files will store your uploaded files.
          </p>

          {profile?.drive_folder_id && (
            <div className="bg-green-900/30 border border-green-600/30 rounded-lg p-3 flex items-center gap-2">
              <Check size={16} className="text-green-400" />
              <div>
                <p className="text-sm font-medium text-green-200">Folder Connected</p>
                <p className="text-xs text-green-400">ID: {profile.drive_folder_id}</p>
              </div>
            </div>
          )}

          <div>
            <label className="block text-sm font-medium text-gray-200 mb-1">
              Google Drive Folder Link
            </label>
            <input
              type="url"
              className="input-field"
              placeholder="https://drive.google.com/drive/folders/xxxxxxxx"
              value={folderUrl}
              onChange={e => setFolderUrl(e.target.value)}
            />
            <p className="text-xs text-gray-500 mt-1">
              The folder must be set to "Anyone with the link" in Google Drive.
            </p>
          </div>

          <div className="bg-amber-900/30 border border-amber-600/30 rounded-lg p-3 flex items-start gap-2">
            <AlertTriangle size={16} className="text-amber-400 mt-0.5 flex-shrink-0" />
            <p className="text-xs text-amber-300">
              Make sure the folder sharing setting is "Anyone with the link can view" before connecting.
            </p>
          </div>

          <button
            onClick={verifyAndSaveFolder}
            disabled={verifying}
            className="btn-primary text-sm"
          >
            {verifying ? 'Verifying...' : 'Verify & Save Folder'}
          </button>
        </div>
      )}

      {/* Security Tab */}
      {activeTab === 'security' && (
        <div className="card max-w-lg space-y-4">
          <h3 className="font-semibold text-gray-100">Security</h3>
          <p className="text-sm text-gray-500">
            Your account is secured with Google OAuth. Sessions are managed by Supabase Authentication.
          </p>
          <div className="space-y-2 text-sm text-gray-300">
            <div className="flex items-center gap-2">
              <Check size={16} className="text-green-400" />
              Google OAuth Authentication
            </div>
            <div className="flex items-center gap-2">
              <Check size={16} className="text-green-400" />
              JWT Session Management
            </div>
            <div className="flex items-center gap-2">
              <Check size={16} className="text-green-400" />
              Row Level Security (RLS)
            </div>
          </div>
          <hr className="border-dark-400" />
          <button
            onClick={handleSignOut}
            className="btn-danger flex items-center gap-2 text-sm"
          >
            <LogOut size={16} /> Sign Out
          </button>
        </div>
      )}
    </div>
  )
}
