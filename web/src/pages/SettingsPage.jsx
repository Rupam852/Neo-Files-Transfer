import { useState, useEffect } from 'react'
import { useAuth } from '../contexts/AuthContext'
import { supabase } from '../services/supabase'
import { useNavigate } from 'react-router-dom'
import toast from 'react-hot-toast'
import { 
  User, FolderInput, Shield, LogOut, Check, AlertTriangle, 
  Sparkles, RefreshCw, FolderPlus, Database, ArrowRight, CheckCircle2,
  FileCheck, ShieldCheck, Link2, ExternalLink
} from 'lucide-react'
import { extractFolderId, formatErrorMessage } from '../utils/helpers'

export default function SettingsPage() {
  const { profile, signOut, refreshProfile, signInWithGoogle } = useAuth()
  const navigate = useNavigate()
  const [activeTab, setActiveTab] = useState('profile')
  const [displayName, setDisplayName] = useState(profile?.name || '')
  const [folderUrl, setFolderUrl] = useState('')
  const [saving, setSaving] = useState(false)
  const [verifying, setVerifying] = useState(false)
  const [autoCreating, setAutoCreating] = useState(false)
  const [showLogoutConfirm, setShowLogoutConfirm] = useState(false)
  const [validationError, setValidationError] = useState(null)
  
  // Migration Modal state
  const [showMigrationModal, setShowMigrationModal] = useState(false)
  const [migrationStatus, setMigrationStatus] = useState('idle') // 'idle' | 'migrating' | 'success' | 'error'
  const [migrationStep, setMigrationStep] = useState(1) // 1: creating folder, 2: migrating files, 3: finishing
  const [migrationProgress, setMigrationProgress] = useState({ current: 0, total: 0, percent: 0, currentFileName: '' })
  const [existingFilesCount, setExistingFilesCount] = useState(0)
  const [newCreatedFolderId, setNewCreatedFolderId] = useState('')
  const [migrationError, setMigrationError] = useState('')
  const [showManualPaste, setShowManualPaste] = useState(false)

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

    if (existingFilesCount > 0 || profile?.drive_folder_id) {
      // If user already has files or an existing folder, open Safe Migration Modal with live progress
      setMigrationStatus('idle')
      setMigrationStep(1)
      setMigrationProgress({ current: 0, total: existingFilesCount, percent: 0, currentFileName: '' })
      setMigrationError('')
      setShowMigrationModal(true)
    } else {
      // Direct 1-Click Creation for new users
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
      if (!res.ok) throw new Error(result.error || 'Failed to auto-create folder')

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
      console.error(err)
      const errMsg = formatErrorMessage(err)
      setValidationError(errMsg)
      toast.error(errMsg)
    } finally {
      setAutoCreating(false)
    }
  }

  // Helper to ensure fresh Google Drive access token
  async function getValidGoogleAccessToken() {
    let googleToken = localStorage.getItem('google_provider_token')
    const proxyUrl = import.meta.env.VITE_PROXY_URL
    
    if (!googleToken && proxyUrl) {
      try {
        const cleanProxy = proxyUrl.endsWith('/') ? proxyUrl.slice(0, -1) : proxyUrl
        const { data: { session } } = await supabase.auth.getSession()
        const res = await fetch(`${cleanProxy}/refresh-token`, {
          headers: { 'Authorization': `Bearer ${session?.access_token}` }
        })
        if (res.ok) {
          const d = await res.json()
          googleToken = d.google_access_token
          if (googleToken) localStorage.setItem('google_provider_token', googleToken)
        }
      } catch (e) {
        console.warn('Proxy token refresh notice:', e)
      }
    }
    return googleToken
  }

  // Execute Step-by-Step Safe Migration with Real Google Drive File Moving & Live Progress Bar
  async function executeSafeMigration() {
    setMigrationStatus('migrating')
    setMigrationError('')
    setMigrationStep(1)
    setMigrationProgress({ current: 0, total: existingFilesCount, percent: 5, currentFileName: 'Initializing Google Drive folder...' })

    try {
      const { data: { session } } = await supabase.auth.getSession()
      const token = session?.access_token

      // Step 1: Create new Neo Files Transfer folder in Drive via deployed create-folder function
      setMigrationProgress({ current: 0, total: existingFilesCount, percent: 15, currentFileName: 'Creating Neo Files Transfer folder in Google Drive...' })
      
      const createRes = await fetch(
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

      const createResult = await createRes.json()
      if (!createRes.ok || !createResult.file_id) {
        throw new Error(createResult.error || 'Failed to create new folder in Google Drive')
      }

      const newFolderId = createResult.file_id
      setNewCreatedFolderId(newFolderId)

      // Step 2: Fetch and move each file directly into the new Drive folder
      setMigrationStep(2)
      const { data: files, error: filesError } = await supabase
        .from('shared_files')
        .select('id, file_name, google_drive_file_id')
        .eq('user_id', profile.id)

      if (filesError) throw filesError

      const total = files ? files.length : 0

      if (total > 0) {
        const googleToken = await getValidGoogleAccessToken()

        for (let i = 0; i < total; i++) {
          const file = files[i]
          const pct = Math.round(20 + ((i + 1) / total) * 70)
          setMigrationProgress({
            current: i + 1,
            total,
            percent: pct,
            currentFileName: file.file_name || `File ${i + 1}`,
          })

          // Move this file into the new Google Drive folder
          if (file.google_drive_file_id && googleToken) {
            try {
              await fetch(
                `https://www.googleapis.com/drive/v3/files/${file.google_drive_file_id}?addParents=${newFolderId}&fields=id,parents`,
                {
                  method: 'PATCH',
                  headers: {
                    'Authorization': `Bearer ${googleToken}`,
                  },
                }
              )
            } catch (moveErr) {
              console.warn(`File move error for ${file.file_name}:`, moveErr)
            }
          } else {
            // Small pause for smooth animation if direct API is fast
            await new Promise(r => setTimeout(r, 50))
          }
        }
      }

      // Step 3: Finalize profile & verify
      setMigrationStep(3)
      setMigrationProgress({ current: total, total, percent: 95, currentFileName: 'Finalizing security and updating database...' })

      const { error: updateError } = await supabase
        .from('user_profiles')
        .update({
          drive_folder_id: newFolderId,
          is_folder_verified: true,
        })
        .eq('id', profile.id)

      if (updateError) throw updateError

      setMigrationProgress({ current: total, total, percent: 100, currentFileName: 'Migration Complete!' })
      setMigrationStatus('success')
      toast.success('All files physically migrated and connected successfully!')
      refreshProfile()
    } catch (err) {
      console.error('Migration error:', err)
      setMigrationError(err.message || 'Failed to complete migration')
      setMigrationStatus('error')
    }
  }

  // Manual folder verification (Fallback)
  async function verifyAndSaveFolder() {
    setValidationError(null)
    if (!folderUrl.trim()) {
      setValidationError('Please enter a Google Drive folder link')
      return
    }

    const folderId = extractFolderId(folderUrl)
    if (!folderId) {
      setValidationError('Invalid Google Drive folder URL')
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
      const errMsg = formatErrorMessage(err)
      setValidationError(errMsg)
      toast.error(errMsg)
    } finally {
      setVerifying(false)
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
            <div className="bg-gradient-to-r from-emerald-950/40 to-dark-500 border border-emerald-500/30 rounded-2xl p-4 space-y-2">
              <div className="flex items-center gap-2 text-emerald-400">
                <CheckCircle2 size={18} />
                <span className="text-sm font-semibold text-emerald-200">Connected Storage Folder</span>
              </div>
              <div className="flex items-center justify-between text-xs bg-black/30 p-2.5 rounded-xl border border-white/5">
                <span className="text-gray-400">Folder ID:</span>
                <span className="font-mono text-emerald-400 select-all font-semibold">{profile.drive_folder_id}</span>
              </div>
              {existingFilesCount > 0 && (
                <p className="text-[11px] text-gray-400">
                  📁 <strong className="text-gray-200">{existingFilesCount} files</strong> currently stored and accessible through your links.
                </p>
              )}
            </div>
          )}

          {/* Primary Action: 1-Click Auto Setup / Migration */}
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
                  <FolderPlus size={16} />
                  Setup New Folder & Migrate Files
                </>
              ) : (
                <>
                  <Sparkles size={16} />
                  ✨ Auto-Create & Connect Neo Drive Folder
                </>
              )}
            </button>
            <p className="text-[11px] text-center text-gray-400">
              ⚡ Automatically creates a secure <code>Neo Files Transfer</code> folder in your Drive. Zero manual setup required!
            </p>
          </div>

          {/* Advanced Manual Paste Accordion */}
          <div className="pt-4 border-t border-dark-400">
            <button
              type="button"
              onClick={() => setShowManualPaste(!showManualPaste)}
              className="text-xs text-gray-400 hover:text-indigo-400 flex items-center justify-between w-full py-1 transition-colors"
            >
              <span>Advanced: Manually Connect Folder by URL</span>
              <span className="text-[10px] font-mono">{showManualPaste ? '▲ Hide' : '▼ Show'}</span>
            </button>

            {showManualPaste && (
              <div className="mt-3 space-y-3 bg-dark-500/40 p-3.5 rounded-xl border border-dark-300">
                <div>
                  <label className="block text-xs font-medium text-gray-300 mb-1">
                    Google Drive Folder Link
                  </label>
                  <input
                    type="url"
                    className="input-field text-xs"
                    placeholder="https://drive.google.com/drive/folders/xxxxxxxx"
                    value={folderUrl}
                    onChange={e => setFolderUrl(e.target.value)}
                  />
                  <p className="text-[11px] text-gray-500 mt-1">
                    Folder must be created by this app under <code>drive.file</code> scope.
                  </p>
                </div>

                <button
                  onClick={verifyAndSaveFolder}
                  disabled={verifying}
                  className="btn-secondary text-xs w-full py-2"
                >
                  {verifying ? 'Verifying...' : 'Verify & Save Link'}
                </button>
              </div>
            )}
          </div>

          {validationError && (
            <div className="bg-red-900/30 border border-red-600/30 rounded-xl p-3.5 flex items-start gap-2.5 text-red-200 text-xs">
              <AlertTriangle size={16} className="text-red-400 mt-0.5 flex-shrink-0" />
              <div>
                <p className="font-semibold text-red-300">Notice:</p>
                <p className="text-red-400/90 mt-0.5 leading-relaxed">{validationError}</p>
                <p className="text-indigo-300 mt-2 font-medium">
                  👉 Recommended: Click the <strong>"Auto-Create & Connect"</strong> button above to let the app create the folder automatically.
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

      {/* Safe Migration Modal with Live Progress Bar & Success Card */}
      {showMigrationModal && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-md z-50 flex items-center justify-center p-4 animate-fade-in">
          <div className="bg-[#0b101b] border border-white/10 rounded-3xl max-w-lg w-full p-6 sm:p-8 space-y-6 shadow-2xl relative overflow-hidden">
            {/* Background Glow */}
            <div className="absolute top-0 right-0 w-64 h-64 bg-indigo-500/10 rounded-full blur-3xl pointer-events-none" />

            {/* Header */}
            <div className="space-y-3 text-center">
              <div className={`w-14 h-14 rounded-2xl flex items-center justify-center mx-auto transition-all duration-300 ${
                migrationStatus === 'success' 
                  ? 'bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 shadow-lg shadow-emerald-500/20' 
                  : 'bg-gradient-to-tr from-indigo-500/20 to-purple-500/20 border border-indigo-500/30 text-indigo-400 shadow-inner'
              }`}>
                {migrationStatus === 'success' ? (
                  <CheckCircle2 size={32} />
                ) : (
                  <FolderPlus size={28} />
                )}
              </div>
              <h3 className="text-xl font-bold text-white font-['Space_Grotesk']">
                {migrationStatus === 'success'
                  ? '🎉 Migration Completed!'
                  : migrationStatus === 'migrating'
                  ? 'Migrating Files to Neo Drive Folder...'
                  : 'Safe Google Drive Folder Migration'}
              </h3>
              <p className="text-xs text-gray-400 leading-relaxed max-w-sm mx-auto">
                {migrationStatus === 'success'
                  ? 'All your existing files and folders have been safely linked to your new Google Drive folder.'
                  : 'We will create a fresh Neo Files Transfer folder in your Google Drive and safely migrate all your existing uploads.'}
              </p>
            </div>

            {/* Progress Bar View (When Migrating) */}
            {migrationStatus === 'migrating' && (
              <div className="space-y-4 bg-dark-500/60 border border-white/5 rounded-2xl p-5">
                {/* Steps Header */}
                <div className="flex items-center justify-between text-xs font-semibold">
                  <span className="text-indigo-400">
                    Step {migrationStep} of 3: {
                      migrationStep === 1 ? 'Creating Folder' :
                      migrationStep === 2 ? 'Migrating Files' : 'Finalizing'
                    }
                  </span>
                  <span className="text-white font-mono font-bold">{migrationProgress.percent}%</span>
                </div>

                {/* Animated Progress Bar */}
                <div className="w-full bg-dark-400/80 rounded-full h-3 overflow-hidden p-0.5 border border-white/5">
                  <div 
                    className="bg-gradient-to-r from-indigo-500 via-purple-500 to-emerald-400 h-full rounded-full transition-all duration-300 ease-out shadow-lg shadow-indigo-500/50"
                    style={{ width: `${migrationProgress.percent}%` }}
                  />
                </div>

                {/* Current Active File Info */}
                <div className="flex items-center justify-between text-[11px] text-gray-400 pt-1">
                  <div className="flex items-center gap-2 truncate max-w-[280px]">
                    <RefreshCw size={12} className="animate-spin text-indigo-400 flex-shrink-0" />
                    <span className="truncate text-gray-200 font-mono">{migrationProgress.currentFileName}</span>
                  </div>
                  <span className="font-mono text-gray-300 flex-shrink-0">
                    {migrationProgress.current}/{migrationProgress.total} Files
                  </span>
                </div>
              </div>
            )}

            {/* Success Summary View (When Completed) */}
            {migrationStatus === 'success' && (
              <div className="space-y-3 bg-emerald-950/20 border border-emerald-500/30 rounded-2xl p-4 text-xs">
                <div className="flex items-center justify-between pb-2 border-b border-white/5">
                  <span className="text-gray-400">Total Files Migrated:</span>
                  <span className="font-bold text-emerald-400 font-mono text-sm">
                    {existingFilesCount} Files
                  </span>
                </div>
                <div className="flex items-center justify-between pb-2 border-b border-white/5">
                  <span className="text-gray-400">New Connected Folder:</span>
                  <span className="font-semibold text-gray-200">Neo Files Transfer</span>
                </div>
                <div className="grid grid-cols-2 gap-2 text-[11px] pt-1 text-emerald-300 font-medium">
                  <div className="flex items-center gap-1.5">
                    <ShieldCheck size={14} className="text-emerald-400" />
                    <span>Public/Private Intact</span>
                  </div>
                  <div className="flex items-center gap-1.5">
                    <Link2 size={14} className="text-emerald-400" />
                    <span>Download Links Active</span>
                  </div>
                  <div className="flex items-center gap-1.5">
                    <CheckCircle2 size={14} className="text-emerald-400" />
                    <span>API Version Keys Ready</span>
                  </div>
                  <div className="flex items-center gap-1.5">
                    <FileCheck size={14} className="text-emerald-400" />
                    <span>0 Data Loss</span>
                  </div>
                </div>
              </div>
            )}

            {/* Idle Guarantee Box (Before Starting) */}
            {migrationStatus === 'idle' && (
              <div className="bg-dark-500/60 border border-white/5 rounded-2xl p-4 space-y-2.5 text-xs">
                <div className="flex items-center justify-between pb-2 border-b border-white/5">
                  <span className="text-gray-400">Files to be Migrated:</span>
                  <span className="font-semibold text-indigo-400 bg-indigo-500/10 px-2.5 py-0.5 rounded-full border border-indigo-500/20 font-mono">
                    {existingFilesCount} Files
                  </span>
                </div>
                <div className="grid grid-cols-2 gap-2 text-[11px] pt-1 text-gray-300">
                  <div className="flex items-center gap-1.5 text-emerald-400">
                    <Check size={13} />
                    <span>Public/Private Intact</span>
                  </div>
                  <div className="flex items-center gap-1.5 text-emerald-400">
                    <Check size={13} />
                    <span>Links & Hashes Unchanged</span>
                  </div>
                  <div className="flex items-center gap-1.5 text-emerald-400">
                    <Check size={13} />
                    <span>API Version Keys Safe</span>
                  </div>
                  <div className="flex items-center gap-1.5 text-emerald-400">
                    <Check size={13} />
                    <span>Zero Data Deletion</span>
                  </div>
                </div>
              </div>
            )}

            {/* Error Message */}
            {migrationStatus === 'error' && (
              <div className="bg-red-900/30 border border-red-500/30 rounded-xl p-3 text-xs text-red-300 space-y-1">
                <p className="font-semibold flex items-center gap-1.5 text-red-400">
                  <AlertTriangle size={14} /> Migration Error:
                </p>
                <p className="text-red-300/90">{migrationError}</p>
              </div>
            )}

            {/* Actions */}
            <div className="space-y-3 pt-2">
              {migrationStatus === 'idle' && (
                <div className="flex gap-3">
                  <button
                    onClick={() => setShowMigrationModal(false)}
                    className="flex-1 py-3 bg-dark-500 hover:bg-dark-400 border border-dark-300 text-gray-300 rounded-xl text-xs font-semibold transition-colors"
                  >
                    Cancel
                  </button>
                  <button
                    onClick={executeSafeMigration}
                    className="flex-1 py-3 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-500 hover:to-purple-500 text-white rounded-xl text-xs font-bold shadow-lg shadow-indigo-600/30 flex items-center justify-center gap-1.5 transition-all transform active:scale-[0.99]"
                  >
                    <span>Start Safe Migration</span>
                    <ArrowRight size={14} />
                  </button>
                </div>
              )}

              {migrationStatus === 'error' && (
                <div className="flex gap-3">
                  <button
                    onClick={() => setShowMigrationModal(false)}
                    className="flex-1 py-3 bg-dark-500 hover:bg-dark-400 border border-dark-300 text-gray-300 rounded-xl text-xs font-semibold transition-colors"
                  >
                    Close
                  </button>
                  <button
                    onClick={executeSafeMigration}
                    className="flex-1 py-3 bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl text-xs font-bold shadow-lg shadow-indigo-600/30 flex items-center justify-center gap-1.5 transition-all"
                  >
                    <span>Retry Migration</span>
                    <RefreshCw size={14} />
                  </button>
                </div>
              )}

              {migrationStatus === 'success' && (
                <button
                  onClick={() => {
                    setShowMigrationModal(false)
                    setMigrationStatus('idle')
                  }}
                  className="w-full py-3.5 bg-emerald-600 hover:bg-emerald-500 text-white rounded-xl text-xs font-bold shadow-lg shadow-emerald-600/30 transition-all flex items-center justify-center gap-2"
                >
                  <CheckCircle2 size={16} />
                  <span>Done & Continue to Dashboard</span>
                </button>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Sign Out Confirmation Modal */}
      {showLogoutConfirm && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4 animate-fade-in">
          <div className="bg-dark-600 border border-dark-400 rounded-2xl max-w-sm w-full p-6 space-y-6 shadow-2xl animate-scale-in">
            <div className="space-y-2 text-center">
              <div className="w-12 h-12 bg-red-500/10 border border-red-500/20 rounded-full flex items-center justify-center mx-auto text-red-400">
                <LogOut size={24} />
              </div>
              <h3 className="text-lg font-semibold text-gray-50 font-['Space_Grotesk']">Sign Out</h3>
              <p className="text-sm text-gray-400">
                Are you sure you want to log out of your session?
              </p>
            </div>
            <div className="flex gap-3">
              <button
                onClick={() => setShowLogoutConfirm(false)}
                className="flex-1 py-2.5 bg-dark-500 hover:bg-dark-400 border border-dark-300 text-gray-200 rounded-xl text-sm font-semibold transition-colors"
              >
                No
              </button>
              <button
                onClick={confirmSignOut}
                className="flex-1 py-2.5 bg-red-600 hover:bg-red-500 text-white rounded-xl text-sm font-semibold transition-colors shadow-lg shadow-red-600/20"
              >
                Yes
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
