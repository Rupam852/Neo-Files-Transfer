import { Outlet, NavLink, useNavigate } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext'
import {
  LayoutDashboard,
  Files,
  Share2,
  Settings,
  LogOut,
  Menu,
  X,
  Upload,
  Bell,
  ChevronDown,
} from 'lucide-react'
import { useState, useRef, useEffect } from 'react'

const navItems = [
  { to: '/dashboard', icon: LayoutDashboard, label: 'Dashboard', end: true },
  { to: '/dashboard/files', icon: Files, label: 'Files' },
  { to: '/dashboard/shared', icon: Share2, label: 'Shared Files' },
  { to: '/dashboard/settings', icon: Settings, label: 'Settings' },
]

export default function DashboardLayout() {
  const { profile, signOut } = useAuth()
  const navigate = useNavigate()
  const [sidebarOpen, setSidebarOpen] = useState(false)
  const [profileOpen, setProfileOpen] = useState(false)
  const profileRef = useRef(null)

  useEffect(() => {
    function handleClick(e) {
      if (profileRef.current && !profileRef.current.contains(e.target)) {
        setProfileOpen(false)
      }
    }
    document.addEventListener('mousedown', handleClick)
    return () => document.removeEventListener('mousedown', handleClick)
  }, [])

  async function handleSignOut() {
    await signOut()
    navigate('/login')
  }

  function handleUploadClick() {
    navigate('/dashboard/files')
    window.dispatchEvent(new CustomEvent('trigger-upload'))
  }

  return (
    <div className="min-h-screen bg-dark-800 flex">
      {/* Mobile Overlay */}
      {sidebarOpen && (
        <div
          className="fixed inset-0 bg-black/60 z-30 lg:hidden"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      {/* Sidebar */}
      <aside className={`
        fixed lg:static inset-y-0 left-0 z-40 w-64 bg-dark-700 border-r border-dark-400
        transform transition-transform duration-200 ease-in-out
        ${sidebarOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'}
      `}>
        {/* Logo */}
        <div className="h-16 flex items-center gap-3 px-6 border-b border-dark-400">
          <div className="w-8 h-8 bg-primary-600 rounded-lg flex items-center justify-center">
            <span className="text-white font-bold text-sm">NF</span>
          </div>
          <span className="font-semibold text-gray-100">Neo Files</span>
          <button
            className="ml-auto lg:hidden text-gray-400 hover:text-gray-200"
            onClick={() => setSidebarOpen(false)}
          >
            <X size={20} />
          </button>
        </div>

        {/* Nav */}
        <nav className="p-4 space-y-1">
          {navItems.map(item => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.end}
              onClick={() => setSidebarOpen(false)}
              className={({ isActive }) =>
                `flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors ${
                  isActive
                    ? 'bg-primary-600/20 text-primary-400'
                    : 'text-gray-400 hover:bg-dark-500 hover:text-gray-200'
                }`
              }
            >
              <item.icon size={20} />
              {item.label}
            </NavLink>
          ))}
        </nav>

        {/* User Info at Bottom */}
        <div className="absolute bottom-0 left-0 right-0 p-4 border-t border-dark-400">
          <div className="flex items-center gap-3">
            <img
              src={profile?.avatar_url || '/favicon.svg'}
              alt="Avatar"
              className="w-9 h-9 rounded-full object-cover ring-2 ring-dark-300"
            />
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium text-gray-200 truncate">
                {profile?.name || 'User'}
              </p>
              <p className="text-xs text-gray-500 truncate">
                {profile?.email || ''}
              </p>
            </div>
            <button
              onClick={handleSignOut}
              className="text-gray-500 hover:text-red-400 transition-colors"
              title="Sign Out"
            >
              <LogOut size={18} />
            </button>
          </div>
        </div>
      </aside>

      {/* Main Content */}
      <div className="flex-1 flex flex-col min-w-0">
        {/* Top Header */}
        <header className="h-16 bg-dark-700 border-b border-dark-400 flex items-center justify-between px-4 lg:px-6">
          <div className="flex items-center gap-4">
            <button
              className="lg:hidden text-gray-400 hover:text-gray-200"
              onClick={() => setSidebarOpen(true)}
            >
              <Menu size={24} />
            </button>
          </div>

          <div className="flex items-center gap-3">
            <button
              onClick={handleUploadClick}
              className="btn-primary flex items-center gap-2 text-sm"
            >
              <Upload size={16} />
              <span className="hidden sm:inline">Upload</span>
            </button>
            <button className="relative p-2 text-gray-400 hover:text-gray-200 rounded-lg hover:bg-dark-500">
              <Bell size={20} />
            </button>
            <div className="relative" ref={profileRef}>
              <button
                onClick={() => setProfileOpen(!profileOpen)}
                className="flex items-center gap-2 p-1.5 rounded-lg hover:bg-dark-500"
              >
                <img
                  src={profile?.avatar_url || '/favicon.svg'}
                  alt="Avatar"
                  className="w-8 h-8 rounded-full object-cover"
                />
                <ChevronDown size={16} className="text-gray-400" />
              </button>
              {profileOpen && (
                <div className="absolute right-0 mt-2 w-48 bg-dark-600 rounded-lg shadow-xl border border-dark-400 py-1 z-50">
                  <div className="px-4 py-2 border-b border-dark-400">
                    <p className="text-sm font-medium text-gray-200 truncate">{profile?.name}</p>
                    <p className="text-xs text-gray-400 truncate">{profile?.email}</p>
                  </div>
                  <NavLink
                    to="/dashboard/settings"
                    onClick={() => setProfileOpen(false)}
                    className="flex items-center gap-2 px-4 py-2 text-sm text-gray-300 hover:bg-dark-500"
                  >
                    <Settings size={16} /> Settings
                  </NavLink>
                  <button
                    onClick={handleSignOut}
                    className="flex items-center gap-2 px-4 py-2 text-sm text-red-400 hover:bg-dark-500 w-full text-left"
                  >
                    <LogOut size={16} /> Sign Out
                  </button>
                </div>
              )}
            </div>
          </div>
        </header>

        {/* Page Content */}
        <main className="flex-1 p-4 lg:p-6 overflow-auto">
          <Outlet />
        </main>
      </div>
    </div>
  )
}
