import { useState, useEffect } from 'react'
import { useAuth } from '../contexts/AuthContext'
import { supabase } from '../services/supabase'
import { useNavigate } from 'react-router-dom'
import toast from 'react-hot-toast'
import { 
  User, FolderInput, Shield, LogOut, Check, AlertTriangle, 
  Sparkles, RefreshCw, CheckCircle2
} from 'lucide-react'
import { formatErrorMessage } from '../utils/helpers'
import { useBodyScrollLock } from '../hooks/useBodyScrollLock'
import LogoutConfirmModal from '../components/LogoutConfirmModal'

export default function SettingsPage() {
  const { profile, signOut, refreshProfile, signInWithGoogle } = useAuth()
  const navigate = useNavigate()
  const [activeTab, setActiveTab] = useState('profile')
  const [displayName, setDisplayName] = useState(profile?.name || '')
  const [saving, setSaving] = useState(false)
  const [autoCreating, setAutoCreating] = useState(false)
  const [showLogoutConfirm, setShowLogoutConfirm] = useState(false)
  const [showRecreateConfirm, setShowRecreateConfirm] = useState(false)

  useBodyScrollLock(Boolean(showLogoutConfirm || showRecreateConfirm || autoCreating))
  const [validationError, setValidationError] = useState(null)
  const [existingFilesCount, setExistingFilesCount] = useState(0)

  const tabs = [
    { id: 'profile', label: 'Profile', icon: User },
    { id: 'drive', label: 'Google Drive', icon: FolderInput },
    { id: 'security', label: 'Security', icon: Shield },
  ]

  useEffect(() => {
    if (profile?.id) {
      checkExistingFilesCount()
    }
  }, [profile?.id])

  async function checkExistingFilesCount() {
    try {
      const { count, error } = await supabase
        .from('shared_files')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', profile.id)
      
      if (!error && count !== null) {
        setExistingFilesCount(count)
      }
    } catch (e) {
      console.warn('Could not fetch existing file count:', e)
    }
  }

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
      toast.error(formatErrorMessage(err))
    } finally {
      setSaving(false)
    }
  }

  // 1-Click Auto Setup / Connect Google Drive Folder
  async function handleAutoSetupClick() {
    if (!profile?.google_refresh_token) {
      toast.error('Please connect your Google Account first.')
      signInWithGoogle(true)
      return
    }

    if (profile?.drive_folder_id) {
      setShowRecreateConfirm(true)
    } else {
      await executeDirectAutoCreate()
    }
  }

  async function executeDirectAutoCreate() {
    setAutoCreating(true)
    setValidationError(null)
    try {
      const { data: { session } } = await supabase.auth.getSession()
      const token = session?.access_token

      const res = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/create-folder`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            name: 'Neo Files Transfer',
            parent_drive_folder_id: 'root',
          }),
        }
      )

      const result = await res.json()
      if (!res.ok) throw new Error(result.error || 'Failed to auto-create folder in Google Drive')

      // Save folder ID in user profile
      const { error } = await supabase
        .from('user_profiles')
        .update({
          drive_folder_id: result.file_id,
          is_folder_verified: true,
        })
        .eq('id', profile.id)

      if (error) throw error

      toast.success('Neo Files Transfer folder created & connected successfully!')
      refreshProfile()
    } catch (err) {
      console.error('Auto create folder error:', err)
      const errMsg = formatErrorMessage(err)
      setValidationError(errMsg)
      toast.error(errMsg)
    } finally {
      setAutoCreating(false)
    }
  }

  function handleSignOut() {
    setShowLogoutConfirm(true)
  }

  async function confirmSignOut() {
    await supabase.from('activity_logs').insert({
      user_id: profile?.id,
      action: 'logout',
      details: 'User logged out',
    })
    await signOut()
    navigate('/login', { replace: true })
  }

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-gray-100 font-['Space_Grotesk']">Settings</h1>

      {/* Tabs */}
      <div className="flex border-b border-dark-400 gap-4">
        {tabs.map(tab => {
          const Icon = tab.icon
          return (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`pb-3 px-1 text-sm font-medium flex items-center gap-2 border-b-2 transition-colors ${
                activeTab === tab.id
                  ? 'border-indigo-500 text-indigo-400'
                  : 'border-transparent text-gray-400 hover:text-gray-300'
              }`}
            >
              <Icon size={16} />
              {tab.label}
            </button>
          )
        })}
      </div>

      {/* Profile Tab */}
      {activeTab === 'profile' && (
        <div className="card max-w-lg space-y-4">
          <h3 className="font-semibold text-gray-100">Profile Information</h3>
          <div>
            <label className="block text-sm font-medium text-gray-200 mb-1">
              Display Name
            </label>
            <input
              type="text"
              className="input-field"
              value={displayName}
              onChange={e => setDisplayName(e.target.value)}
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-200 mb-1">
              Email
            </label>
            <input
              type="email"
              className="input-field opacity-60 cursor-not-allowed"
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
        <div className="card max-w-xl space-y-5">
          <div className="flex items-start justify-between">
            <div>
              <h3 className="font-semibold text-gray-100 text-lg">Google Drive Setup</h3>
              <p className="text-xs text-gray-400 mt-1 leading-relaxed">
                Connect your Google Drive storage so Neo Files Transfer can securely store and stream your files.
              </p>
            </div>
            {profile?.drive_folder_id && (
              <span className="flex items-center gap-1 text-xs font-semibold text-emerald-400 bg-emerald-500/10 border border-emerald-500/20 px-3 py-1 rounded-full">
                <Check size={14} /> Ready
              </span>
            )}
          </div>

          {/* Connection Status Card */}
          <div className="bg-dark-500/80 rounded-2xl p-4 border border-dark-300 space-y-3">
            <div className="flex items-center justify-between">
              <h4 className="text-xs font-semibold text-gray-300 uppercase tracking-wider">OAuth Connection</h4>
              {profile?.google_refresh_token ? (
                <span className="flex items-center gap-1.5 text-xs font-medium text-green-400 bg-green-500/10 px-2.5 py-0.5 rounded-full border border-green-500/20">
                  <span className="w-1.5 h-1.5 rounded-full bg-green-400 animate-pulse" />
                  Account Linked
                </span>
              ) : (
                <span className="flex items-center gap-1.5 text-xs font-medium text-red-400 bg-red-500/10 px-2.5 py-0.5 rounded-full border border-red-500/20">
                  <AlertTriangle size={12} /> Unlinked
                </span>
              )}
            </div>
            <p className="text-xs text-gray-400 leading-relaxed">
              Google Drive access keys are encrypted and stored in your profile. 
              {!profile?.google_refresh_token && " Please link your Google Drive below to enable 1-click folder creation and uploads."}
            </p>
            {!profile?.google_refresh_token && (
              <button
                onClick={() => signInWithGoogle(true)}
                className="w-full btn-primary text-xs flex items-center justify-center gap-2 py-2.5 shadow-lg shadow-indigo-500/20"
              >
                <Sparkles size={14} />
                Link / Re-authorize Google Account
              </button>
            )}
          </div>

          {/* Current Folder Info */}
          {profile?.drive_folder_id && (
            <div className="bg-emerald-500/10 dark:bg-emerald-950/40 border border-emerald-500/30 rounded-2xl p-4 space-y-3 shadow-sm">
              <div className="flex items-center gap-2">
                <CheckCircle2 size={18} className="text-emerald-600 dark:text-emerald-400" />
                <span className="text-sm font-bold text-emerald-800 dark:text-emerald-200">Connected Storage Folder</span>
              </div>
              <div className="flex items-center justify-between text-xs bg-emerald-500/10 dark:bg-black/30 p-2.5 rounded-xl border border-emerald-500/20 dark:border-white/5">
                <span className="text-gray-600 dark:text-gray-400 font-medium">Folder ID:</span>
                <span className="font-mono text-emerald-700 dark:text-emerald-400 select-all font-bold">{profile.drive_folder_id}</span>
              </div>
              {existingFilesCount > 0 && (
                <p className="text-[11px] text-gray-600 dark:text-gray-400">
                  📁 <strong className="text-gray-900 dark:text-gray-200">{existingFilesCount} files</strong> currently stored and accessible through your links.
                </p>
              )}
            </div>
          )}

          {/* Primary Action: 1-Click Auto Setup */}
          <div className="space-y-3 pt-2">
            <button
              onClick={handleAutoSetupClick}
              disabled={autoCreating || !profile?.google_refresh_token}
              className="w-full py-3.5 px-4 rounded-xl font-bold text-sm bg-gradient-to-r from-indigo-600 via-purple-600 to-indigo-600 hover:from-indigo-500 hover:to-purple-500 text-white shadow-xl shadow-indigo-600/25 flex items-center justify-center gap-2.5 transition-all duration-300 transform active:scale-[0.99] disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {autoCreating ? (
                <>
                  <RefreshCw size={16} className="animate-spin" />
                  Creating Neo Drive Folder...
                </>
              ) : profile?.drive_folder_id ? (
                <>
                  <Sparkles size={16} />
                  Re-create & Connect Neo Drive Folder
                </>
              ) : (
                <>
                  <Sparkles size={16} />
                  Auto-Create & Connect Neo Drive Folder
                </>
              )}
            </button>
            <p className="text-[11px] text-center text-gray-500 dark:text-gray-400">
              ⚡ Automatically creates a secure <code>Neo Files Transfer</code> folder in your Drive. Zero manual setup required!
            </p>

            {profile?.drive_folder_id && (
              <div className="bg-indigo-500/10 dark:bg-indigo-950/30 border border-indigo-500/20 rounded-xl p-3 text-[11px] leading-relaxed space-y-1">
                <p className="font-bold text-indigo-800 dark:text-indigo-200 flex items-center gap-1.5">
                  <span>ℹ️</span> Note for Re-connecting Folder:
                </p>
                <p className="text-gray-600 dark:text-gray-300">
                  Creating a new folder will set it as your active destination. Existing files will remain in your previous folder and keep working. You can optionally move them manually in Google Drive if you wish.
                </p>
              </div>
            )}
          </div>

          {validationError && (
            <div className="bg-red-500/10 dark:bg-red-900/30 border border-red-500/30 rounded-xl p-3.5 flex items-start gap-2.5 text-xs">
              <AlertTriangle size={16} className="text-red-600 dark:text-red-400 mt-0.5 flex-shrink-0" />
              <div>
                <p className="font-bold text-red-700 dark:text-red-300">Notice:</p>
                <p className="text-red-600 dark:text-red-400 mt-0.5 leading-relaxed">{validationError}</p>
                <p className="text-indigo-600 dark:text-indigo-300 mt-2 font-medium">
                  👉 Click the <strong>"Auto-Create & Connect"</strong> button above to create a fresh secure folder.
                </p>
              </div>
            </div>
          )}
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

      {/* Re-create / Connect Folder Confirmation Modal */}
      {showRecreateConfirm && (
        <div className="fixed inset-0 bg-black/70 backdrop-blur-sm z-50 flex items-center justify-center p-4 animate-fade-in">
          <div className="bg-dark-600 border border-dark-400 rounded-3xl max-w-md w-full p-6 sm:p-7 space-y-5 shadow-2xl animate-scale-in">
            <div className="space-y-3 text-center">
              <div className="w-14 h-14 bg-indigo-500/10 border border-indigo-500/30 rounded-2xl flex items-center justify-center mx-auto text-indigo-400 shadow-inner">
                <Sparkles size={28} />
              </div>
              <h3 className="text-lg font-bold text-gray-50 font-['Space_Grotesk']">
                Create & Connect New Drive Folder?
              </h3>
              <div className="text-xs text-gray-400 leading-relaxed text-left bg-dark-500/60 p-4 rounded-2xl border border-white/5 space-y-2.5">
                <p className="text-gray-200 font-medium">
                  A fresh <strong>Neo Files Transfer</strong> folder will be created in your Google Drive and set as your primary upload destination.
                </p>
                <div className="text-indigo-300 pt-2 border-t border-white/5 space-y-1.5">
                  <p className="font-semibold text-indigo-200">📌 Important Note for Existing Files:</p>
                  <p className="text-gray-300">
                    • Your existing uploaded files will remain in your previous folder and their download links will stay <strong>100% active</strong>.
                  </p>
                  <p className="text-gray-300">
                    • If you want all files in one place, you can <strong>manually move/shift</strong> your files from your old folder into the new folder on Google Drive.
                  </p>
                </div>
              </div>
            </div>
            <div className="flex gap-3">
              <button
                onClick={() => setShowRecreateConfirm(false)}
                className="flex-1 py-2.5 bg-dark-500 hover:bg-dark-400 border border-dark-300 text-gray-300 rounded-xl text-xs font-semibold transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={() => {
                  setShowRecreateConfirm(false)
                  executeDirectAutoCreate()
                }}
                className="flex-1 py-2.5 bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl text-xs font-bold transition-colors shadow-lg shadow-indigo-600/30"
              >
                Confirm & Create Folder
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Sign Out Confirmation Modal */}
      {/* Sign Out Confirmation Modal */}
      <LogoutConfirmModal
        isOpen={showLogoutConfirm}
        onClose={() => setShowLogoutConfirm(false)}
        onConfirm={confirmSignOut}
      />
    </div>
  )
}
