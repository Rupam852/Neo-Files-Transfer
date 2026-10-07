import { useState, useEffect, useRef } from 'react'
import { supabase } from '../services/supabase'
import { useAuth } from '../contexts/AuthContext'
import toast from 'react-hot-toast'
import {
  Bell, CheckCheck, Trash2, Download, CheckCircle2,
  ShieldAlert, Info, Sparkles, X, ExternalLink
} from 'lucide-react'

export default function NotificationBell() {
  const { user } = useAuth()
  const [notifications, setNotifications] = useState([])
  const [unreadCount, setUnreadCount] = useState(0)
  const [isOpen, setIsOpen] = useState(false)
  const [loading, setLoading] = useState(false)
  const dropdownRef = useRef(null)

  useEffect(() => {
    if (!user?.id) return

    loadNotifications()

    // Real-time listener for new incoming notifications
    const channel = supabase
      .channel(`user_notifications_${user.id}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'notifications',
          filter: `user_id=eq.${user.id}`
        },
        (payload) => {
          const newNotif = payload.new
          setNotifications(prev => [newNotif, ...prev.filter(n => n.id !== newNotif.id)])
          setUnreadCount(prev => prev + 1)

          // Instant high-visibility in-app toast notification
          toast(
            (t) => (
              <div className="flex items-start gap-3 py-0.5">
                <div className="w-8 h-8 rounded-full bg-primary-500/20 text-primary-400 flex items-center justify-center flex-shrink-0 mt-0.5">
                  <Bell size={16} className="animate-bounce" />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-xs font-bold text-gray-100">{newNotif.title || 'Notification'}</p>
                  <p className="text-xs text-gray-300 mt-0.5 leading-relaxed">{newNotif.message}</p>
                </div>
                <button
                  onClick={() => toast.dismiss(t.id)}
                  className="text-gray-500 hover:text-gray-300 p-1"
                >
                  <X size={14} />
                </button>
              </div>
            ),
            {
              duration: 5000,
              position: 'top-right',
              style: {
                background: '#1e293b',
                color: '#fff',
                border: '1px solid rgba(99, 102, 241, 0.3)',
                boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.5), 0 8px 10px -6px rgba(0, 0, 0, 0.5)',
                borderRadius: '1rem',
                padding: '12px 16px',
              }
            }
          )
        }
      )
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'notifications',
          filter: `user_id=eq.${user.id}`
        },
        (payload) => {
          const updated = payload.new
          setNotifications(prev => prev.map(n => n.id === updated.id ? updated : n))
          recalcUnread()
        }
      )
      .on(
        'postgres_changes',
        {
          event: 'DELETE',
          schema: 'public',
          table: 'notifications',
          filter: `user_id=eq.${user.id}`
        },
        (payload) => {
          const deletedId = payload.old?.id
          if (deletedId) {
            setNotifications(prev => prev.filter(n => n.id !== deletedId))
            recalcUnread()
          }
        }
      )
      .subscribe()

    // Close on outside click
    function handleOutsideClick(e) {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target)) {
        setIsOpen(false)
      }
    }
    document.addEventListener('mousedown', handleOutsideClick)

    return () => {
      supabase.removeChannel(channel)
      document.removeEventListener('mousedown', handleOutsideClick)
    }
  }, [user?.id])

  async function loadNotifications() {
    if (!user?.id) return
    setLoading(true)
    try {
      const { data, error } = await supabase
        .from('notifications')
        .select('*')
        .eq('user_id', user.id)
        .order('created_at', { ascending: false })
        .limit(40)

      if (error) throw error
      const items = data || []
      setNotifications(items)
      setUnreadCount(items.filter(n => !n.is_read).length)
    } catch (err) {
      console.error('Failed to load notifications:', err)
    } finally {
      setLoading(false)
    }
  }

  function recalcUnread() {
    setNotifications(prev => {
      setUnreadCount(prev.filter(n => !n.is_read).length)
      return prev
    })
  }

  async function markAsRead(notifId) {
    try {
      setNotifications(prev => prev.map(n => n.id === notifId ? { ...n, is_read: true } : n))
      setUnreadCount(prev => Math.max(0, prev - 1))
      await supabase
        .from('notifications')
        .update({ is_read: true })
        .eq('id', notifId)
    } catch (err) {
      console.error('Failed to mark notification as read:', err)
    }
  }

  async function markAllAsRead() {
    if (unreadCount === 0) return
    try {
      setNotifications(prev => prev.map(n => ({ ...n, is_read: true })))
      setUnreadCount(0)
      await supabase
        .from('notifications')
        .update({ is_read: true })
        .eq('user_id', user.id)
        .eq('is_read', false)
      toast.success('All marked as read')
    } catch (err) {
      toast.error('Failed to mark all as read: ' + err.message)
    }
  }

  async function clearAllNotifications() {
    if (notifications.length === 0) return
    try {
      setNotifications([])
      setUnreadCount(0)
      await supabase
        .from('notifications')
        .delete()
        .eq('user_id', user.id)
      toast.success('Notifications cleared')
    } catch (err) {
      toast.error('Failed to clear notifications: ' + err.message)
    }
  }

  async function deleteNotification(e, notifId) {
    e.stopPropagation()
    try {
      setNotifications(prev => prev.filter(n => n.id !== notifId))
      recalcUnread()
      await supabase
        .from('notifications')
        .delete()
        .eq('id', notifId)
    } catch (err) {
      console.error('Failed to delete notification:', err)
    }
  }

  function getNotificationIcon(type) {
    switch (type) {
      case 'download':
        return <Download size={14} className="text-primary-400" />
      case 'approval':
        return <CheckCircle2 size={14} className="text-emerald-400" />
      case 'security':
        return <ShieldAlert size={14} className="text-amber-400" />
      default:
        return <Info size={14} className="text-indigo-400" />
    }
  }

  function formatTimeAgo(dateString) {
    if (!dateString) return 'Just now'
    const now = new Date()
    const past = new Date(dateString)
    const diffSec = Math.floor((now - past) / 1000)

    if (diffSec < 45) return 'Just now'
    if (diffSec < 3600) return `${Math.floor(diffSec / 60)}m ago`
    if (diffSec < 86400) return `${Math.floor(diffSec / 3600)}h ago`
    return `${Math.floor(diffSec / 86400)}d ago`
  }

  return (
    <div className="relative" ref={dropdownRef}>
      {/* Bell Icon Button */}
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="relative p-2 rounded-lg text-gray-400 hover:text-gray-200 hover:bg-dark-500 transition-colors"
        title="Notifications"
      >
        <Bell size={19} className={unreadCount > 0 ? 'text-primary-400' : ''} />
        {unreadCount > 0 && (
          <span className="absolute top-1 right-1 min-w-[16px] h-[16px] px-1 bg-red-500 text-white text-[9.5px] font-extrabold rounded-full flex items-center justify-center border-2 border-dark-700 leading-none pointer-events-none">
            {unreadCount > 99 ? '99+' : unreadCount}
          </span>
        )}
      </button>

      {/* Dropdown Panel */}
      {isOpen && (
        <div className="absolute right-0 mt-2 w-80 sm:w-96 bg-dark-600 border border-dark-400/90 rounded-2xl shadow-2xl py-0 z-50 animate-scale-in overflow-hidden">
          {/* Header */}
          <div className="flex items-center justify-between px-4 py-3 bg-dark-500/70 border-b border-dark-400/80">
            <div className="flex items-center gap-2">
              <Bell size={16} className="text-primary-400" />
              <h3 className="text-xs font-bold text-gray-100 uppercase tracking-wider">
                Notifications
              </h3>
              {unreadCount > 0 && (
                <span className="text-[10px] bg-primary-500/20 text-primary-400 border border-primary-500/30 px-1.5 py-0.5 rounded-full font-bold">
                  {unreadCount} new
                </span>
              )}
            </div>

            <div className="flex items-center gap-1">
              {unreadCount > 0 && (
                <button
                  onClick={markAllAsRead}
                  className="p-1.5 text-gray-400 hover:text-primary-400 hover:bg-dark-400 rounded-lg text-xs font-medium transition-colors"
                  title="Mark all as read"
                >
                  <CheckCheck size={14} />
                </button>
              )}
              {notifications.length > 0 && (
                <button
                  onClick={clearAllNotifications}
                  className="p-1.5 text-gray-400 hover:text-red-400 hover:bg-dark-400 rounded-lg text-xs font-medium transition-colors"
                  title="Clear all notifications"
                >
                  <Trash2 size={14} />
                </button>
              )}
            </div>
          </div>

          {/* List */}
          <div className="max-h-80 overflow-y-auto divide-y divide-dark-500/80">
            {loading && notifications.length === 0 ? (
              <div className="py-8 text-center">
                <div className="w-5 h-5 border-2 border-primary-500 border-t-transparent rounded-full animate-spin mx-auto" />
              </div>
            ) : notifications.length === 0 ? (
              <div className="py-10 text-center space-y-2 px-4">
                <div className="w-10 h-10 rounded-full bg-dark-500 text-gray-500 flex items-center justify-center mx-auto">
                  <Bell size={18} />
                </div>
                <p className="text-xs font-semibold text-gray-300">No notifications yet</p>
                <p className="text-[11px] text-gray-500 leading-relaxed">
                  You will receive real-time alerts when someone downloads your shared files or when your account is approved.
                </p>
              </div>
            ) : (
              notifications.map((notif) => (
                <div
                  key={notif.id}
                  onClick={() => !notif.is_read && markAsRead(notif.id)}
                  className={`p-3.5 flex items-start gap-3 transition-colors cursor-pointer group ${
                    notif.is_read ? 'bg-dark-600/60 hover:bg-dark-500/50' : 'bg-primary-500/5 hover:bg-primary-500/10'
                  }`}
                >
                  {/* Icon Indicator */}
                  <div className={`w-7 h-7 rounded-lg flex items-center justify-center flex-shrink-0 mt-0.5 ${
                    notif.is_read ? 'bg-dark-500' : 'bg-primary-500/15 border border-primary-500/20'
                  }`}>
                    {getNotificationIcon(notif.type)}
                  </div>

                  {/* Body */}
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between gap-1 mb-0.5">
                      <p className={`text-xs font-semibold truncate ${
                        notif.is_read ? 'text-gray-300' : 'text-gray-100'
                      }`}>
                        {notif.title}
                      </p>
                      <span className="text-[10px] text-gray-500 flex-shrink-0">
                        {formatTimeAgo(notif.created_at)}
                      </span>
                    </div>

                    <p className={`text-xs leading-relaxed ${
                      notif.is_read ? 'text-gray-400' : 'text-gray-200'
                    }`}>
                      {notif.message}
                    </p>

                    {/* Optional metadata info (e.g. Device / Browser) */}
                    {notif.metadata?.device_type && (
                      <p className="text-[10px] text-gray-500 mt-1 font-mono">
                        {notif.metadata.device_type} · {notif.metadata.browser || 'Browser'}
                      </p>
                    )}
                  </div>

                  {/* Individual Delete Button on hover */}
                  <button
                    onClick={(e) => deleteNotification(e, notif.id)}
                    className="opacity-0 group-hover:opacity-100 p-1 text-gray-500 hover:text-red-400 hover:bg-dark-400 rounded transition-all"
                    title="Delete"
                  >
                    <X size={12} />
                  </button>
                </div>
              ))
            )}
          </div>
        </div>
      )}
    </div>
  )
}
