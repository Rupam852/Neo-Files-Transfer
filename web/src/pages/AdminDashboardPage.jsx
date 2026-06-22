import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../services/supabase'
import { useAuth } from '../contexts/AuthContext'
import toast from 'react-hot-toast'
import {
  Search, Check, X, Trash2, Phone, Mail,
  LogOut, Users, UserCheck, Clock, ShieldCheck,
  Settings, Activity,
} from 'lucide-react'
import { formatDate } from '../utils/helpers'

export default function AdminDashboardPage() {
  const { profile, signOut } = useAuth()
  const navigate = useNavigate()
  const [pendingUsers, setPendingUsers] = useState([])
  const [approvedUsers, setApprovedUsers] = useState([])
  const [activeTab, setActiveTab] = useState('pending')
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(true)
  const [systemSettings, setSystemSettings] = useState({})

  useEffect(() => {
    fetchData()
  }, [])

  async function fetchData() {
    setLoading(true)
    try {
      const [pendingRes, approvedRes, settingsRes] = await Promise.all([
        supabase.from('pending_registrations').select('*').order('submitted_at', { ascending: false }),
        supabase.from('approved_users').select('*').order('approved_at', { ascending: false }),
        supabase.from('system_settings').select('*'),
      ])
      setPendingUsers(pendingRes.data || [])
      setApprovedUsers(approvedRes.data || [])
      const settings = {}
      settingsRes.data?.forEach(s => { settings[s.key] = s.value })
      setSystemSettings(settings)
    } catch (err) {
      console.error(err)
    } finally {
      setLoading(false)
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

      toast.success(`Approved user ${email} deleted`)
      fetchData()
    } catch (err) {
      console.error(err)
      toast.error('Failed to delete approved user')
    }
  }

  async function toggleSetting(key) {
    const newVal = !systemSettings[key]
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

      setSystemSettings({ ...systemSettings, [key]: newVal })
      toast.success(`${key} ${newVal ? 'enabled' : 'disabled'}`)
    } catch (err) {
      toast.error('Failed to update setting')
    }
  }

  async function handleSignOut() {
    await supabase.from('admin_activity_logs').insert({
      admin_id: profile?.id,
      action: 'admin_logout',
      details: 'Admin logged out',
    })
    await signOut()
    navigate('/')
  }

  const filteredPending = pendingUsers.filter(u =>
    u.name?.toLowerCase().includes(search.toLowerCase()) ||
    u.email?.toLowerCase().includes(search.toLowerCase())
  )

  const filteredApproved = approvedUsers.filter(u =>
    u.email?.toLowerCase().includes(search.toLowerCase())
  )

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

      <div className="max-w-7xl mx-auto p-4 lg:p-6">
        {/* Stats */}
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
          <StatCard icon={Users} label="Total Registrations" value={pendingUsers.length + approvedUsers.length} color="blue" />
          <StatCard icon={Clock} label="Pending" value={pendingUsers.filter(u => u.status === 'pending').length} color="orange" />
          <StatCard icon={UserCheck} label="Approved" value={approvedUsers.length} color="green" />
          <StatCard icon={ShieldCheck} label="Active Users" value={approvedUsers.length} color="primary" />
        </div>

        {/* Tabs */}
        <div className="flex items-center gap-1 bg-dark-600 rounded-lg border border-dark-400 p-1 mb-6 w-fit">
          <button
            onClick={() => setActiveTab('pending')}
            className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
              activeTab === 'pending' ? 'bg-primary-600 text-white' : 'text-gray-300 hover:bg-dark-500'
            }`}
          >
            Pending ({pendingUsers.filter(u => u.status === 'pending').length})
          </button>
          <button
            onClick={() => setActiveTab('approved')}
            className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
              activeTab === 'approved' ? 'bg-primary-600 text-white' : 'text-gray-300 hover:bg-dark-500'
            }`}
          >
            Approved ({approvedUsers.length})
          </button>
          <button
            onClick={() => setActiveTab('settings')}
            className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
              activeTab === 'settings' ? 'bg-primary-600 text-white' : 'text-gray-300 hover:bg-dark-500'
            }`}
          >
            <Settings size={16} className="inline mr-1" />
            Settings
          </button>
        </div>

        {/* Search */}
        {activeTab !== 'settings' && (
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
                        <th className="text-left text-xs font-medium text-gray-400 uppercase tracking-wider px-4 py-3">Phone</th>
                        <th className="text-left text-xs font-medium text-gray-400 uppercase tracking-wider px-4 py-3">Status</th>
                        <th className="text-left text-xs font-medium text-gray-400 uppercase tracking-wider px-4 py-3">Submitted</th>
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
                            <td className="px-4 py-3 text-sm text-gray-400">{user.email}</td>
                            <td className="px-4 py-3 text-sm text-gray-400">{user.phone}</td>
                            <td className="px-4 py-3">
                              <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${
                                user.status === 'pending' ? 'bg-amber-900/30 text-amber-400' :
                                user.status === 'approved' ? 'bg-green-900/30 text-green-400' :
                                'bg-red-900/30 text-red-400'
                              }`}>
                                {user.status}
                              </span>
                            </td>
                            <td className="px-4 py-3 text-sm text-gray-400">{formatDate(user.submitted_at)}</td>
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
                        <th className="text-left text-xs font-medium text-gray-400 uppercase tracking-wider px-4 py-3">Approved At</th>
                        <th className="text-left text-xs font-medium text-gray-400 uppercase tracking-wider px-4 py-3">Actions</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-dark-400">
                      {filteredApproved.length === 0 ? (
                        <tr>
                          <td colSpan={3} className="text-center py-8 text-gray-400 text-sm">
                            No approved users
                          </td>
                        </tr>
                      ) : (
                        filteredApproved.map(user => (
                          <tr key={user.id} className="hover:bg-dark-500">
                            <td className="px-4 py-3 text-sm font-medium text-gray-100">{user.email}</td>
                            <td className="px-4 py-3 text-sm text-gray-400">{formatDate(user.approved_at)}</td>
                            <td className="px-4 py-3">
                              <div className="flex items-center gap-1">
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
          </>
        )}
      </div>
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
        <p className="text-2xl font-bold text-gray-100">{value}</p>
        <p className="text-xs text-gray-400">{label}</p>
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
