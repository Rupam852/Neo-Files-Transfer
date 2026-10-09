import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../services/supabase'
import { useAuth } from '../contexts/AuthContext'
import toast from 'react-hot-toast'
import {
  Search, Check, X, Trash2, Phone, Mail,
  LogOut, Users, UserCheck, Clock, ShieldCheck,
  Settings, Activity, Pause, Play, Bell, Send,
  Radio, Smartphone, AlertTriangle, Sparkles,
} from 'lucide-react'
import { formatDate } from '../utils/helpers'
import ThemeToggle from '../components/ThemeToggle'
import { useBodyScrollLock } from '../hooks/useBodyScrollLock'

export default function AdminDashboardPage() {
  const { profile, adminRecord, signOut } = useAuth()
  const navigate = useNavigate()
  const [pendingUsers, setPendingUsers] = useState([])
  const [approvedUsers, setApprovedUsers] = useState([])
  const [adminsList, setAdminsList] = useState([])
  const [activeTab, setActiveTab] = useState('pending')
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(true)
  const [systemSettings, setSystemSettings] = useState({})
  const [newAdminEmail, setNewAdminEmail] = useState('')
  const [addingAdmin, setAddingAdmin] = useState(false)
  const [showLogoutConfirm, setShowLogoutConfirm] = useState(false)

  // Broadcast & Push Notification State
  const [broadcastTitle, setBroadcastTitle] = useState('')
  const [broadcastBody, setBroadcastBody] = useState('')
  const [broadcastTargetType, setBroadcastTargetType] = useState('topic') // 'topic' | 'user'
  const [broadcastTopic, setBroadcastTopic] = useState('all_users') // 'all_users' | 'app_updates'
  const [broadcastUserId, setBroadcastUserId] = useState('')
  const [sendingBroadcast, setSendingBroadcast] = useState(false)

  useBodyScrollLock(showLogoutConfirm)

  const navigateTab = (tab, push = true) => {
    setActiveTab(tab)
    try {
      if (push && window.history?.pushState) {
        window.history.pushState({ adminTab: tab }, '')
      }
    } catch (e) {
      console.error('History API error:', e)
    }
  }

  useEffect(() => {
    // Set initial history state on mount
    try {
      if (window.history?.replaceState) {
        window.history.replaceState({ adminTab: activeTab }, '')
      }
    } catch (e) {
      console.error('History API error on mount:', e)
    }

    const handlePopState = (event) => {
      if (event.state && event.state.adminTab) {
        setActiveTab(event.state.adminTab)
      } else {
        setActiveTab('pending')
      }
    }

    window.addEventListener('popstate', handlePopState)
    return () => window.removeEventListener('popstate', handlePopState)
  }, [])

  useEffect(() => {
    fetchData(true)

    // Subscribe to realtime updates for pending_registrations
    const pendingChannel = supabase
      .channel('pending-registrations-changes')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'pending_registrations' },
        () => {
          fetchData(false)
        }
      )
      .subscribe()

    // Subscribe to realtime updates for approved_users
    const approvedChannel = supabase
      .channel('approved-users-changes')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'approved_users' },
        () => {
          fetchData(false)
        }
      )
      .subscribe()

    // Subscribe to realtime updates for system_settings
    const settingsChannel = supabase
      .channel('system-settings-changes')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'system_settings' },
        async () => {
          try {
            const { data } = await supabase.from('system_settings').select('*')
            const settings = {}
            data?.forEach(s => { settings[s.key] = s.value })
            setSystemSettings(settings)
          } catch (e) {
            console.error('Failed to sync settings:', e)
          }
        }
      )
      .subscribe()

    // Subscribe to realtime updates for admins
    const adminsChannel = supabase
      .channel('admins-changes')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'admins' },
        () => {
          fetchData(false)
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(pendingChannel)
      supabase.removeChannel(approvedChannel)
      supabase.removeChannel(settingsChannel)
      supabase.removeChannel(adminsChannel)
    }
  }, [])

  async function fetchData(showSpinner = false) {
    if (showSpinner) setLoading(true)
    try {
      // Background auto-cleanup of activity logs older than 7 days
      const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString()
      supabase.from('activity_logs').delete().lt('created_at', sevenDaysAgo).then(() => {}).catch(() => {})
      supabase.from('admin_activity_logs').delete().lt('created_at', sevenDaysAgo).then(() => {}).catch(() => {})

      const [pendingRes, approvedRes, settingsRes, adminsRes, profilesRes] = await Promise.all([
        supabase.from('pending_registrations').select('*').order('submitted_at', { ascending: false }),
        supabase.from('approved_users').select('*').order('approved_at', { ascending: false }),
        supabase.from('system_settings').select('*'),
        supabase.from('admins').select('*'),
        supabase.from('user_profiles').select('id, avatar_url'),
      ])
      setPendingUsers(pendingRes.data || [])
      setApprovedUsers(approvedRes.data || [])
      
      const profiles = profilesRes.data || []
      const profileMap = new Map(profiles.map(p => [p.id, p.avatar_url]))
      const adminsWithAvatars = (adminsRes.data || []).map(admin => ({
        ...admin,
        avatar_url: profileMap.get(admin.user_id) || ''
      }))
      setAdminsList(adminsWithAvatars)

      const settings = {}
      settingsRes.data?.forEach(s => { settings[s.key] = s.value })
      setSystemSettings(settings)
    } catch (err) {
      console.error(err)
    } finally {
      if (showSpinner) setLoading(false)
    }
  }

  async function sendStatusEmail(email, action) {
    try {
      const { data: { session } } = await supabase.auth.getSession()
      if (!session) {
        console.warn('No active session found, cannot send status email')
        return
      }
      const response = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/mail-service/notify-user`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${session.access_token}`,
          },
          body: JSON.stringify({ email, action }),
        }
      )
      if (!response.ok) {
        const errData = await response.json().catch(() => ({}))
        console.error('Failed to send email notification:', errData.error || response.statusText)
      }
    } catch (err) {
      console.error('Error calling mail-service notify-user:', err)
    }
  }

  async function approveUser(user) {
    try {
      // Add to approved_users
      const { error: insertError } = await supabase.from('approved_users').insert({
        email: user.email,
        approved_by: profile?.id,
      })
      if (insertError) throw insertError

      // Update pending status
      await supabase
        .from('pending_registrations')
        .update({ status: 'approved' })
        .eq('id', user.id)

      // Log admin activity
      await supabase.from('admin_activity_logs').insert({
        admin_id: profile?.id,
        action: 'user_approval',
        details: `Approved user: ${user.email}`,
      })

      // Send notification email asynchronously (non-blocking)
      sendStatusEmail(user.email, 'approved')

      toast.success(`${user.name} has been approved`)
      fetchData()
    } catch (err) {
      console.error(err)
      toast.error(`Failed to approve user: ${err.message || JSON.stringify(err)}`)
    }
  }

  async function rejectUser(user) {
    try {
      await supabase
        .from('pending_registrations')
        .update({ status: 'rejected' })
        .eq('id', user.id)

      await supabase.from('admin_activity_logs').insert({
        admin_id: profile?.id,
        action: 'user_rejection',
        details: `Rejected user: ${user.email}`,
      })

      // Send notification email asynchronously (non-blocking)
      sendStatusEmail(user.email, 'rejected')

      toast.success(`${user.name} has been rejected`)
      fetchData()
    } catch (err) {
      toast.error('Failed to reject user')
    }
  }

  async function deleteUser(id) {
    if (!confirm('Are you sure you want to delete this registration?')) return
    try {
      await supabase.from('pending_registrations').delete().eq('id', id)
      toast.success('Registration deleted')
      fetchData()
    } catch (err) {
      toast.error('Failed to delete')
    }
  }

  async function deleteApprovedUser(email) {
    if (adminEmails.has(email.toLowerCase())) {
      toast.error('Cannot delete or revoke approval for an Administrator.')
      return
    }

    if (!confirm(`Are you sure you want to delete and revoke approval for ${email}?`)) return
    try {
      // Delete from approved_users
      const { error: approvedError } = await supabase
        .from('approved_users')
        .delete()
        .eq('email', email)
      
      if (approvedError) throw approvedError

      // Delete from pending_registrations
      const { error: pendingError } = await supabase
        .from('pending_registrations')
        .delete()
        .eq('email', email)

      if (pendingError) throw pendingError

      // Log admin activity
      await supabase.from('admin_activity_logs').insert({
        admin_id: profile?.id,
        action: 'user_revoke_approval',
        details: `Revoked approval and deleted registration for: ${email}`,
      })

      // Send notification email asynchronously (non-blocking)
      sendStatusEmail(email, 'suspended')

      toast.success(`Approved user ${email} deleted`)
      fetchData()
    } catch (err) {
      console.error(err)
      toast.error('Failed to delete approved user')
    }
  }

  async function togglePauseUser(user) {
    if (adminRecord?.role !== 'super_admin') {
      toast.error('Only the Super Administrator can pause or resume user accounts.')
      return
    }

    const newPausedState = !user.is_paused
    try {
      const { error } = await supabase
        .from('approved_users')
        .update({ is_paused: newPausedState })
        .eq('id', user.id)

      if (error) throw error

      await supabase.from('admin_activity_logs').insert({
        admin_id: profile?.id,
        action: newPausedState ? 'user_pause' : 'user_resume',
        details: `${newPausedState ? 'Paused' : 'Resumed'} user account: ${user.email}`,
      })

      toast.success(`User ${user.email} has been ${newPausedState ? 'paused' : 'resumed'}`)
      fetchData()
    } catch (err) {
      console.error(err)
      toast.error(`Failed to update user status: ${err.message || JSON.stringify(err)}`)
    }
  }

  async function handleAddAdmin(e) {
    e.preventDefault()
    if (!newAdminEmail.trim()) return

    const emailToPromote = newAdminEmail.trim().toLowerCase()

    if (adminRecord?.role !== 'super_admin') {
      toast.error('Only the Super Administrator can add other administrators.')
      return
    }

    setAddingAdmin(true)
    try {
      // 1. Find user in user_profiles
      const { data: userProfile, error: profileErr } = await supabase
        .from('user_profiles')
        .select('id, email')
        .eq('email', emailToPromote)
        .maybeSingle()

      if (profileErr) throw profileErr

      if (!userProfile) {
        toast.error('User must sign up and log in once before being promoted to admin.')
        setAddingAdmin(false)
        return
      }

      // 2. Check if already an admin
      const isAlreadyAdmin = adminsList.some(a => a.email.toLowerCase() === emailToPromote)
      if (isAlreadyAdmin) {
        toast.error('This user is already an administrator.')
        setAddingAdmin(false)
        return
      }

      // 3. Insert into admins table
      const { error: insertErr } = await supabase
        .from('admins')
        .insert({
          user_id: userProfile.id,
          email: userProfile.email,
          role: 'admin',
        })

      if (insertErr) throw insertErr

      // 4. Log admin activity
      await supabase.from('admin_activity_logs').insert({
        admin_id: profile?.id,
        action: 'admin_added',
        details: `Promoted user ${emailToPromote} to admin`,
      })

      toast.success(`${emailToPromote} has been promoted to Admin`)
      setNewAdminEmail('')
      fetchData()
    } catch (err) {
      console.error(err)
      toast.error(`Failed to add admin: ${err.message || JSON.stringify(err)}`)
    } finally {
      setAddingAdmin(false)
    }
  }

  async function handleDeleteAdmin(admin) {
    if (adminRecord?.role !== 'super_admin') {
      toast.error('Only the Super Administrator can remove administrators.')
      return
    }

    if (admin.email.toLowerCase() === profile?.email?.toLowerCase()) {
      toast.error('You cannot remove yourself as an administrator.')
      return
    }

    if (!confirm(`Are you sure you want to remove administrator access for ${admin.email}?`)) return

    try {
      const { error: deleteErr } = await supabase
        .from('admins')
        .delete()
        .eq('id', admin.id)

      if (deleteErr) throw deleteErr

      // Log admin activity
      await supabase.from('admin_activity_logs').insert({
        admin_id: profile?.id,
        action: 'admin_removed',
        details: `Removed admin: ${admin.email}`,
      })

      toast.success(`Removed administrator access for ${admin.email}`)
      fetchData()
    } catch (err) {
      console.error(err)
      toast.error(`Failed to remove admin: ${err.message || JSON.stringify(err)}`)
    }
  }

  async function handleSendBroadcast(e) {
    if (e) e.preventDefault()
    if (!broadcastTitle.trim() || !broadcastBody.trim()) {
      toast.error('Please fill in both Title and Message.')
      return
    }

    if (broadcastTargetType === 'user' && !broadcastUserId) {
      toast.error('Please select a target user.')
      return
    }

    setSendingBroadcast(true)
    try {
      const target = broadcastTargetType === 'topic' ? broadcastTopic : broadcastUserId
      const { data, error } = await supabase.functions.invoke('broadcast-notification', {
        body: {
          title: broadcastTitle.trim(),
          body: broadcastBody.trim(),
          targetType: broadcastTargetType,
          target,
        },
      })

      if (error) throw error
      if (data?.error) throw new Error(data.error)

      toast.success(`Push notification sent successfully! (${data?.sentCount ?? 1} sent)`)
      setBroadcastTitle('')
      setBroadcastBody('')
    } catch (err) {
      console.error('Broadcast error:', err)
      toast.error(`Failed to send broadcast: ${err.message || 'Unknown error'}`)
    } finally {
      setSendingBroadcast(false)
    }
  }

  async function toggleSetting(key) {
    let currentVal
    if (key === 'maintenance_mode') {
      currentVal = !!systemSettings[key]
    } else {
      currentVal = systemSettings[key] !== false
    }
    const newVal = !currentVal

    // Update local state immediately for instant feedback
    setSystemSettings(prev => ({ ...prev, [key]: newVal }))

    try {
      await supabase
        .from('system_settings')
        .upsert({ key, value: newVal }, { onConflict: 'key' })
      
      const action = newVal ? `${key}_enabled` : `${key}_disabled`
      await supabase.from('admin_activity_logs').insert({
        admin_id: profile?.id,
        action,
        details: `Toggled ${key}: ${newVal}`,
      })

      // Auto broadcast FCM notification for maintenance mode
      if (key === 'maintenance_mode') {
        try {
          await supabase.functions.invoke('broadcast-notification', {
            body: {
              title: newVal ? '⚠️ Neo Files Maintenance Mode' : '✅ Neo Files is Back Online',
              body: newVal
                ? 'App is currently undergoing scheduled maintenance. Services will resume shortly.'
                : 'Maintenance is complete! You can now upload and share files normally.',
              targetType: 'topic',
              target: 'all_users',
            },
          })
        } catch (fcmErr) {
          console.error('Maintenance FCM broadcast error:', fcmErr)
        }
      }

      toast.success(`${key.replaceAll('_', ' ')} ${newVal ? 'enabled' : 'disabled'}`)
    } catch (err) {
      // Revert state on error
      setSystemSettings(prev => ({ ...prev, [key]: currentVal }))
      toast.error('Failed to update setting')
    }
  }

  function handleSignOut() {
    setShowLogoutConfirm(true)
  }

  async function confirmSignOut() {
    await supabase.from('admin_activity_logs').insert({
      admin_id: profile?.id,
      action: 'admin_logout',
      details: 'Admin logged out',
    })
    await signOut()
    navigate('/', { replace: true })
  }

  const adminEmails = new Set(adminsList.map(a => a.email.toLowerCase()))

  const filteredPending = pendingUsers.filter(u =>
    u.status === 'pending' &&
    !adminEmails.has(u.email?.toLowerCase()) && (
      u.name?.toLowerCase().includes(search.toLowerCase()) ||
      u.email?.toLowerCase().includes(search.toLowerCase())
    )
  )

  const filteredApproved = approvedUsers.filter(u =>
    !adminEmails.has(u.email?.toLowerCase()) &&
    u.email?.toLowerCase().includes(search.toLowerCase())
  )

  const pendingCount = pendingUsers.filter(u => u.status === 'pending' && !adminEmails.has(u.email?.toLowerCase())).length
  const approvedCount = approvedUsers.filter(u => !adminEmails.has(u.email?.toLowerCase())).length

  return (
    <div className="min-h-screen bg-dark-800">
      {/* Header */}
      <header className="bg-dark-700 border-b border-dark-400 h-16 flex items-center justify-between px-4 lg:px-6">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 bg-primary-600 rounded-lg flex items-center justify-center">
            <ShieldCheck size={16} className="text-white" />
          </div>
          <span className="font-semibold text-gray-100">Admin Dashboard</span>
        </div>
        <div className="flex items-center gap-3">
          {profile?.avatar_url && (
            <img
              src={profile.avatar_url}
              alt="Avatar"
              className="w-8 h-8 rounded-full border border-dark-300 object-cover"
            />
          )}
          <ThemeToggle />
          <span className="text-sm text-gray-400 hidden sm:block">{profile?.email}</span>
          <button
            onClick={handleSignOut}
            className="text-gray-400 hover:text-red-400 p-2"
            title="Sign Out"
          >
            <LogOut size={18} />
          </button>
        </div>
      </header>

      <div className="max-w-7xl mx-auto p-4 lg:p-6 pb-24">
        {/* Stats */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
          <StatCard icon={Users} label="Total Registrations" value={pendingCount + approvedCount} color="blue" />
          <StatCard icon={Clock} label="Pending" value={pendingCount} color="orange" />
          <StatCard icon={UserCheck} label="Approved" value={approvedCount} color="green" />
          <StatCard icon={ShieldCheck} label="Administrators" value={adminsList.length} color="primary" />
        </div>

        {/* Tabs */}
        <div className="flex flex-wrap items-center gap-1 bg-dark-600 rounded-lg border border-dark-400 p-1 mb-6 w-fit">
          <button
            onClick={() => navigateTab('pending')}
            className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
              activeTab === 'pending' ? 'bg-primary-600 text-white' : 'text-gray-300 hover:bg-dark-500'
            }`}
          >
            Pending ({pendingCount})
          </button>
          <button
            onClick={() => navigateTab('approved')}
            className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
              activeTab === 'approved' ? 'bg-primary-600 text-white' : 'text-gray-300 hover:bg-dark-500'
            }`}
          >
            Approved ({approvedCount})
          </button>
          <button
            onClick={() => navigateTab('admins')}
            className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
              activeTab === 'admins' ? 'bg-primary-600 text-white' : 'text-gray-300 hover:bg-dark-500'
            }`}
          >
            <ShieldCheck size={16} className="inline mr-1" />
            Admins ({adminsList.length})
          </button>
          <button
            onClick={() => navigateTab('broadcast')}
            className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
              activeTab === 'broadcast' ? 'bg-primary-600 text-white' : 'text-gray-300 hover:bg-dark-500'
            }`}
          >
            <Radio size={16} className="inline mr-1" />
            Broadcast
          </button>
          <button
            onClick={() => navigateTab('settings')}
            className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
              activeTab === 'settings' ? 'bg-primary-600 text-white' : 'text-gray-300 hover:bg-dark-500'
            }`}
          >
            <Settings size={16} className="inline mr-1" />
            Settings
          </button>
        </div>

        {/* Search */}
        {activeTab !== 'settings' && activeTab !== 'admins' && activeTab !== 'broadcast' && (
          <div className="mb-4">
            <div className="relative max-w-md">
              <Search size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
              <input
                type="text"
                placeholder="Search by name or email..."
                className="input-field pl-10"
                value={search}
                onChange={e => setSearch(e.target.value)}
              />
            </div>
          </div>
        )}

        {/* Content */}
        {loading ? (
          <div className="flex justify-center py-12">
            <div className="w-8 h-8 border-4 border-primary-600 border-t-transparent rounded-full animate-spin" />
          </div>
        ) : (
          <>
            {/* Pending Tab */}
            {activeTab === 'pending' && (
              <div className="bg-dark-600 rounded-xl border border-dark-300 overflow-hidden">
                <div className="overflow-x-auto">
                  <table className="w-full">
                    <thead>
                      <tr className="bg-dark-500 border-b border-dark-300">
                        <th className="text-left text-xs font-medium text-gray-400 uppercase tracking-wider px-4 py-3">Name</th>
                        <th className="text-left text-xs font-medium text-gray-400 uppercase tracking-wider px-4 py-3">Email</th>
                        <th className="text-left text-xs font-medium text-gray-400 uppercase tracking-wider px-4 py-3 hidden md:table-cell">Phone</th>
                        <th className="text-left text-xs font-medium text-gray-400 uppercase tracking-wider px-4 py-3">Status</th>
                        <th className="text-left text-xs font-medium text-gray-400 uppercase tracking-wider px-4 py-3 hidden sm:table-cell">Submitted</th>
                        <th className="text-left text-xs font-medium text-gray-400 uppercase tracking-wider px-4 py-3">Actions</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-dark-400">
                      {filteredPending.length === 0 ? (
                        <tr>
                          <td colSpan={6} className="text-center py-8 text-gray-400 text-sm">
                            No pending registrations
                          </td>
                        </tr>
                      ) : (
                        filteredPending.map(user => (
                          <tr key={user.id} className="hover:bg-dark-500">
                            <td className="px-4 py-3 text-sm font-medium text-gray-100">{user.name}</td>
                            <td className="px-4 py-3 text-sm text-gray-400 truncate max-w-[150px] sm:max-w-xs">{user.email}</td>
                            <td className="px-4 py-3 text-sm text-gray-400 hidden md:table-cell">{user.phone}</td>
                            <td className="px-4 py-3">
                              <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${
                                user.status === 'pending' ? 'bg-amber-900/30 text-amber-400' :
                                user.status === 'approved' ? 'bg-green-900/30 text-green-400' :
                                'bg-red-900/30 text-red-400'
                              }`}>
                                {user.status}
                              </span>
                            </td>
                            <td className="px-4 py-3 text-sm text-gray-400 hidden sm:table-cell">{formatDate(user.submitted_at)}</td>
                            <td className="px-4 py-3">
                              <div className="flex items-center gap-1">
                                {user.status === 'pending' && (
                                  <>
                                    <button
                                      onClick={() => approveUser(user)}
                                      className="p-1.5 text-green-400 hover:bg-dark-500 rounded-lg"
                                      title="Approve"
                                    >
                                      <Check size={16} />
                                    </button>
                                    <button
                                      onClick={() => rejectUser(user)}
                                      className="p-1.5 text-red-400 hover:bg-dark-500 rounded-lg"
                                      title="Reject"
                                    >
                                      <X size={16} />
                                    </button>
                                  </>
                                )}
                                <button
                                  onClick={() => deleteUser(user.id)}
                                  className="p-1.5 text-gray-400 hover:bg-dark-500 rounded-lg"
                                  title="Delete"
                                >
                                  <Trash2 size={16} />
                                </button>
                                <a
                                  href={`mailto:${user.email}`}
                                  className="p-1.5 text-blue-400 hover:bg-dark-500 rounded-lg"
                                  title="Email"
                                >
                                  <Mail size={16} />
                                </a>
                                <a
                                  href={`tel:${user.phone}`}
                                  className="p-1.5 text-gray-400 hover:bg-dark-500 rounded-lg"
                                  title="Call"
                                >
                                  <Phone size={16} />
                                </a>
                              </div>
                            </td>
                          </tr>
                        ))
                      )}
                    </tbody>
                  </table>
                </div>
              </div>
            )}

            {/* Approved Tab */}
            {activeTab === 'approved' && (
              <div className="bg-dark-600 rounded-xl border border-dark-300 overflow-hidden">
                <div className="overflow-x-auto">
                  <table className="w-full">
                    <thead>
                      <tr className="bg-dark-500 border-b border-dark-300">
                        <th className="text-left text-xs font-medium text-gray-400 uppercase tracking-wider px-4 py-3">Email</th>
                        <th className="text-left text-xs font-medium text-gray-400 uppercase tracking-wider px-4 py-3">Status</th>
                        <th className="text-left text-xs font-medium text-gray-400 uppercase tracking-wider px-4 py-3 hidden sm:table-cell">Approved At</th>
                        <th className="text-left text-xs font-medium text-gray-400 uppercase tracking-wider px-4 py-3">Actions</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-dark-400">
                      {filteredApproved.length === 0 ? (
                        <tr>
                          <td colSpan={4} className="text-center py-8 text-gray-400 text-sm">
                            No approved users
                          </td>
                        </tr>
                      ) : (
                        filteredApproved.map(user => (
                          <tr key={user.id} className="hover:bg-dark-500">
                            <td className="px-4 py-3 text-sm font-medium text-gray-100 truncate max-w-[150px] sm:max-w-xs">{user.email}</td>
                            <td className="px-4 py-3">
                              <span className={`inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-medium border ${
                                user.is_paused
                                  ? 'bg-amber-500/10 text-amber-400 border-amber-500/20'
                                  : 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20'
                              }`}>
                                <span className={`w-1.5 h-1.5 rounded-full ${
                                  user.is_paused ? 'bg-amber-400' : 'bg-emerald-400 animate-pulse'
                                }`} />
                                {user.is_paused ? 'Paused' : 'Active'}
                              </span>
                            </td>
                            <td className="px-4 py-3 text-sm text-gray-400 hidden sm:table-cell">{formatDate(user.approved_at)}</td>
                            <td className="px-4 py-3">
                              <div className="flex items-center gap-1">
                                {adminRecord?.role === 'super_admin' && (
                                  <button
                                    onClick={() => togglePauseUser(user)}
                                    className={`p-1.5 rounded-lg ${
                                      user.is_paused
                                        ? 'text-emerald-400 hover:bg-emerald-500/10'
                                        : 'text-amber-400 hover:bg-amber-500/10'
                                    }`}
                                    title={user.is_paused ? "Resume Account" : "Pause Account"}
                                  >
                                    {user.is_paused ? <Play size={16} /> : <Pause size={16} />}
                                  </button>
                                )}
                                <button
                                  onClick={() => deleteApprovedUser(user.email)}
                                  className="p-1.5 text-red-400 hover:bg-dark-500 rounded-lg"
                                  title="Revoke Approval & Delete"
                                >
                                  <Trash2 size={16} />
                                </button>
                                <a
                                  href={`mailto:${user.email}`}
                                  className="p-1.5 text-blue-400 hover:bg-dark-500 rounded-lg"
                                  title="Email"
                                >
                                  <Mail size={16} />
                                </a>
                              </div>
                            </td>
                          </tr>
                        ))
                      )}
                    </tbody>
                  </table>
                </div>
              </div>
            )}

            {/* Admins Tab */}
            {activeTab === 'admins' && (
              <div className="space-y-6">
                {/* Add Admin Form (visible only to super_admin) */}
                {adminRecord?.role === 'super_admin' ? (
                  <div className="card max-w-lg">
                    <h3 className="font-semibold text-gray-100 flex items-center gap-2 mb-4">
                      <ShieldCheck size={18} className="text-primary-400" /> Promote User to Admin
                    </h3>
                    <form onSubmit={handleAddAdmin} className="space-y-4">
                      <div>
                        <label className="block text-xs font-medium text-gray-400 uppercase tracking-wider mb-2">
                          User Email Address
                        </label>
                        <input
                          type="email"
                          placeholder="user@example.com"
                          className="input-field"
                          value={newAdminEmail}
                          onChange={e => setNewAdminEmail(e.target.value)}
                          required
                          disabled={addingAdmin}
                        />
                        <p className="text-xs text-gray-500 mt-1">
                          The user must have logged into the system at least once before they can be promoted.
                        </p>
                      </div>
                      <button
                        type="submit"
                        className="btn-primary flex items-center justify-center gap-2 w-full"
                        disabled={addingAdmin}
                      >
                        {addingAdmin ? (
                          <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                        ) : 'Promote to Admin'}
                      </button>
                    </form>
                  </div>
                ) : (
                  <div className="card max-w-lg bg-dark-600/50 border border-amber-900/30">
                    <p className="text-sm text-amber-400 flex items-center gap-2">
                      <ShieldCheck size={16} /> Only the Super Administrator can add or remove other administrators.
                    </p>
                  </div>
                )}

                {/* Admins List */}
                <div className="bg-dark-600 rounded-xl border border-dark-300 overflow-hidden">
                  <div className="px-4 py-3 bg-dark-500 border-b border-dark-300 flex items-center justify-between">
                    <h3 className="font-semibold text-gray-100">Administrators List</h3>
                  </div>
                  <div className="overflow-x-auto">
                    <table className="w-full">
                      <thead>
                        <tr className="bg-dark-500 border-b border-dark-300">
                          <th className="text-left text-xs font-medium text-gray-400 uppercase tracking-wider px-4 py-3">Email</th>
                          <th className="text-left text-xs font-medium text-gray-400 uppercase tracking-wider px-4 py-3">Role</th>
                          <th className="text-left text-xs font-medium text-gray-400 uppercase tracking-wider px-4 py-3 hidden sm:table-cell">Added At</th>
                          {adminRecord?.role === 'super_admin' && (
                            <th className="text-left text-xs font-medium text-gray-400 uppercase tracking-wider px-4 py-3">Actions</th>
                          )}
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-dark-400">
                        {adminsList.map(admin => (
                          <tr key={admin.id} className="hover:bg-dark-500">
                            <td className="px-4 py-3 text-sm font-medium text-gray-100 flex items-center gap-2 truncate max-w-[150px] sm:max-w-xs">
                              {admin.avatar_url ? (
                                <img
                                  src={admin.avatar_url}
                                  alt="Avatar"
                                  className="w-6 h-6 rounded-full border border-dark-300 object-cover flex-shrink-0"
                                />
                              ) : (
                                <div className="w-6 h-6 bg-primary-600/25 border border-primary-500/20 text-primary-400 rounded-full flex items-center justify-center text-[10px] font-bold flex-shrink-0">
                                  A
                                </div>
                              )}
                              <span>{admin.email}</span>
                            </td>
                            <td className="px-4 py-3 text-sm">
                              <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                                admin.role === 'super_admin' ? 'bg-purple-900/30 text-purple-400' : 'bg-primary-900/30 text-primary-400'
                              }`}>
                                {admin.role === 'super_admin' ? 'Super Admin' : 'Admin'}
                              </span>
                            </td>
                            <td className="px-4 py-3 text-sm text-gray-400 hidden sm:table-cell">{formatDate(admin.created_at)}</td>
                            {adminRecord?.role === 'super_admin' && (
                              <td className="px-4 py-3 text-sm">
                                {admin.email.toLowerCase() !== profile?.email?.toLowerCase() && admin.role !== 'super_admin' ? (
                                  <button
                                    onClick={() => handleDeleteAdmin(admin)}
                                    className="p-1.5 text-red-400 hover:bg-dark-500 rounded-lg transition-colors"
                                    title="Revoke Admin Access"
                                  >
                                    <Trash2 size={16} />
                                  </button>
                                ) : (
                                  <span className="text-xs text-gray-500 italic">No actions available</span>
                                )}
                              </td>
                            )}
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>
            )}

            {/* Settings Tab */}
            {activeTab === 'settings' && (
              <div className="card max-w-lg space-y-4">
                <h3 className="font-semibold text-gray-100 flex items-center gap-2">
                  <Activity size={18} /> System Controls
                </h3>
                <SettingToggle
                  label="Maintenance Mode"
                  description="When enabled, the platform shows a maintenance page to all users."
                  checked={systemSettings.maintenance_mode || false}
                  onChange={() => toggleSetting('maintenance_mode')}
                />
                <SettingToggle
                  label="Downloads Enabled"
                  description="Allow users to download files through share links."
                  checked={systemSettings.downloads_enabled !== false}
                  onChange={() => toggleSetting('downloads_enabled')}
                />
                <SettingToggle
                  label="Sharing Enabled"
                  description="Allow users to generate new share links."
                  checked={systemSettings.sharing_enabled !== false}
                  onChange={() => toggleSetting('sharing_enabled')}
                />
              </div>
            )}

            {/* Broadcast & Push Notifications Tab */}
            {activeTab === 'broadcast' && (
              <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                {/* Compose Form */}
                <div className="lg:col-span-2 card space-y-5">
                  <div className="flex items-center justify-between border-b border-dark-400 pb-4">
                    <div>
                      <h3 className="font-semibold text-lg text-gray-100 flex items-center gap-2">
                        <Radio size={20} className="text-primary-400" /> Push Broadcast Console
                      </h3>
                      <p className="text-xs text-gray-400 mt-1">
                        Send real-time push notifications to Android devices even when the app is completely closed.
                      </p>
                    </div>
                    <span className="px-2.5 py-1 bg-green-500/10 border border-green-500/20 text-green-400 rounded-full text-xs font-semibold flex items-center gap-1.5">
                      <span className="w-2 h-2 rounded-full bg-green-400 animate-pulse" /> FCM Live
                    </span>
                  </div>

                  <form onSubmit={handleSendBroadcast} className="space-y-4">
                    {/* Target Selector */}
                    <div>
                      <label className="block text-xs font-semibold text-gray-300 uppercase tracking-wider mb-2">
                        Broadcast Target
                      </label>
                      <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
                        <button
                          type="button"
                          onClick={() => { setBroadcastTargetType('topic'); setBroadcastTopic('all_users'); }}
                          className={`p-3 rounded-xl border text-left transition-all ${
                            broadcastTargetType === 'topic' && broadcastTopic === 'all_users'
                              ? 'bg-primary-600/15 border-primary-500 text-white'
                              : 'bg-dark-500/50 border-dark-400 text-gray-400 hover:bg-dark-500'
                          }`}
                        >
                          <div className="font-semibold text-sm flex items-center gap-2">
                            <Users size={16} /> All Active Users
                          </div>
                          <div className="text-xs text-gray-400 mt-1">/topics/all_users</div>
                        </button>

                        <button
                          type="button"
                          onClick={() => { setBroadcastTargetType('topic'); setBroadcastTopic('app_updates'); }}
                          className={`p-3 rounded-xl border text-left transition-all ${
                            broadcastTargetType === 'topic' && broadcastTopic === 'app_updates'
                              ? 'bg-primary-600/15 border-primary-500 text-white'
                              : 'bg-dark-500/50 border-dark-400 text-gray-400 hover:bg-dark-500'
                          }`}
                        >
                          <div className="font-semibold text-sm flex items-center gap-2">
                            <Smartphone size={16} /> App Updates
                          </div>
                          <div className="text-xs text-gray-400 mt-1">/topics/app_updates</div>
                        </button>

                        <button
                          type="button"
                          onClick={() => setBroadcastTargetType('user')}
                          className={`p-3 rounded-xl border text-left transition-all ${
                            broadcastTargetType === 'user'
                              ? 'bg-primary-600/15 border-primary-500 text-white'
                              : 'bg-dark-500/50 border-dark-400 text-gray-400 hover:bg-dark-500'
                          }`}
                        >
                          <div className="font-semibold text-sm flex items-center gap-2">
                            <UserCheck size={16} /> Specific User
                          </div>
                          <div className="text-xs text-gray-400 mt-1">Target individual device</div>
                        </button>
                      </div>
                    </div>

                    {/* Specific User Dropdown */}
                    {broadcastTargetType === 'user' && (
                      <div>
                        <label className="block text-xs font-semibold text-gray-300 uppercase tracking-wider mb-1.5">
                          Select User
                        </label>
                        <select
                          className="input-field"
                          value={broadcastUserId}
                          onChange={(e) => setBroadcastUserId(e.target.value)}
                        >
                          <option value="">-- Choose User --</option>
                          {approvedUsers.map((u) => (
                            <option key={u.id} value={u.user_id || u.id}>
                              {u.email} ({u.name || 'User'})
                            </option>
                          ))}
                        </select>
                      </div>
                    )}

                    {/* Notification Title */}
                    <div>
                      <label className="block text-xs font-semibold text-gray-300 uppercase tracking-wider mb-1.5">
                        Notification Title
                      </label>
                      <input
                        type="text"
                        placeholder="e.g. ⚠️ Scheduled Maintenance Notice"
                        className="input-field"
                        value={broadcastTitle}
                        onChange={(e) => setBroadcastTitle(e.target.value)}
                        maxLength={100}
                      />
                    </div>

                    {/* Notification Message */}
                    <div>
                      <label className="block text-xs font-semibold text-gray-300 uppercase tracking-wider mb-1.5">
                        Notification Message Body
                      </label>
                      <textarea
                        rows={4}
                        placeholder="Enter the notification description that users will see in their phone status bar..."
                        className="input-field resize-none"
                        value={broadcastBody}
                        onChange={(e) => setBroadcastBody(e.target.value)}
                        maxLength={300}
                      />
                    </div>

                    {/* Submit Button */}
                    <button
                      type="submit"
                      disabled={sendingBroadcast}
                      className="w-full py-3 bg-gradient-to-r from-primary-600 to-indigo-600 hover:from-primary-500 hover:to-indigo-500 text-white rounded-xl text-sm font-semibold flex items-center justify-center gap-2 transition-all shadow-lg shadow-primary-600/25 disabled:opacity-50"
                    >
                      {sendingBroadcast ? (
                        <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                      ) : (
                        <>
                          <Send size={16} /> Send Push Broadcast
                        </>
                      )}
                    </button>
                  </form>
                </div>

                {/* Quick Presets & Tips */}
                <div className="space-y-4">
                  <div className="card space-y-3">
                    <h4 className="font-semibold text-gray-100 flex items-center gap-2 text-sm">
                      <Sparkles size={16} className="text-amber-400" /> Quick Notification Templates
                    </h4>
                    <div className="space-y-2">
                      <button
                        type="button"
                        onClick={() => {
                          setBroadcastTitle('⚠️ Scheduled System Maintenance')
                          setBroadcastBody('Neo Files will undergo routine server updates today. Please complete critical uploads.')
                          setBroadcastTargetType('topic')
                          setBroadcastTopic('all_users')
                        }}
                        className="w-full text-left p-3 rounded-lg bg-dark-500/50 hover:bg-dark-500 border border-dark-400 transition-colors"
                      >
                        <div className="text-xs font-semibold text-amber-400 flex items-center gap-1.5">
                          <AlertTriangle size={13} /> Maintenance Notice
                        </div>
                        <div className="text-xs text-gray-400 mt-1">
                          Scheduled system maintenance announcement template
                        </div>
                      </button>

                      <button
                        type="button"
                        onClick={() => {
                          setBroadcastTitle('🚀 New App Update Available!')
                          setBroadcastBody('A new update with improved upload speed and background transfer is now available. Tap to update!')
                          setBroadcastTargetType('topic')
                          setBroadcastTopic('app_updates')
                        }}
                        className="w-full text-left p-3 rounded-lg bg-dark-500/50 hover:bg-dark-500 border border-dark-400 transition-colors"
                      >
                        <div className="text-xs font-semibold text-primary-400 flex items-center gap-1.5">
                          <Smartphone size={13} /> App Update Notice
                        </div>
                        <div className="text-xs text-gray-400 mt-1">
                          Notify users of a newly released version build
                        </div>
                      </button>

                      <button
                        type="button"
                        onClick={() => {
                          setBroadcastTitle('✅ System Online & Operational')
                          setBroadcastBody('All Neo Files services are running smoothly at peak performance. Enjoy fast file sharing!')
                          setBroadcastTargetType('topic')
                          setBroadcastTopic('all_users')
                        }}
                        className="w-full text-left p-3 rounded-lg bg-dark-500/50 hover:bg-dark-500 border border-dark-400 transition-colors"
                      >
                        <div className="text-xs font-semibold text-green-400 flex items-center gap-1.5">
                          <Check size={13} /> All Systems Normal
                        </div>
                        <div className="text-xs text-gray-400 mt-1">
                          Post-maintenance recovery announcement
                        </div>
                      </button>
                    </div>
                  </div>

                  <div className="card space-y-2 bg-dark-600/60">
                    <h4 className="font-semibold text-gray-100 flex items-center gap-2 text-xs uppercase tracking-wider">
                      <Bell size={14} className="text-primary-400" /> How Closed-App Push Works
                    </h4>
                    <p className="text-xs text-gray-400 leading-relaxed">
                      Android devices maintain an OS-level connection to Google Play Services. Even if the user swipes away Neo Files or the phone screen is locked, these push broadcasts will instantly pop up in the status bar tray.
                    </p>
                  </div>
                </div>
              </div>
            )}
          </>
        )}
      </div>

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

function StatCard({ icon: Icon, label, value, color }) {
  const colors = {
    blue: 'bg-blue-600/20 text-blue-400',
    orange: 'bg-amber-600/20 text-amber-400',
    green: 'bg-green-600/20 text-green-400',
    primary: 'bg-primary-600/20 text-primary-400',
  }
  return (
    <div className="card flex items-center gap-4">
      <div className={`w-10 h-10 rounded-lg flex items-center justify-center ${colors[color]}`}>
        <Icon size={20} />
      </div>
      <div>
        <p className="text-2xl font-bold text-gray-100 leading-none">{value}</p>
        <p className="text-xs text-gray-400 mt-1">{label}</p>
      </div>
    </div>
  )
}

function SettingToggle({ label, description, checked, onChange }) {
  return (
    <div className="flex items-start justify-between gap-4 py-3 border-b border-dark-400 last:border-0">
      <div>
        <p className="text-sm font-medium text-gray-100">{label}</p>
        <p className="text-xs text-gray-400 mt-0.5">{description}</p>
      </div>
      <button
        onClick={onChange}
        className={`relative w-11 h-6 rounded-full transition-colors flex-shrink-0 ${
          checked ? 'bg-primary-600' : 'bg-dark-200'
        }`}
      >
        <span className={`absolute top-0.5 left-0.5 w-5 h-5 bg-white rounded-full transition-transform ${
          checked ? 'translate-x-5' : 'translate-x-0'
        }`} />
      </button>
    </div>
  )
}
