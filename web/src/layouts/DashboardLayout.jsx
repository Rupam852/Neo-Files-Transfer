import { useNavigate } from 'react-router-dom'
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
  ChevronDown,
} from 'lucide-react'
import { useState, useRef, useEffect } from 'react'

// Import Dashboard Pages directly for State-based rendering
import DashboardPage from '../pages/DashboardPage'
import FilesPage from '../pages/FilesPage'
import SharedFilesPage from '../pages/SharedFilesPage'
import SettingsPage from '../pages/SettingsPage'
import VersionPage from '../pages/VersionPage'

const navItems = [
  { id: 'dashboard', icon: LayoutDashboard, label: 'Dashboard' },
  { id: 'files', icon: Files, label: 'Files' },
  { id: 'shared', icon: Share2, label: 'Shared Files' },
  { id: 'settings', icon: Settings, label: 'Settings' },
]

export default function DashboardLayout() {
  const { profile, signOut } = useAuth()
  const navigate = useNavigate()
  const [sidebarOpen, setSidebarOpen] = useState(false)
  const [profileOpen, setProfileOpen] = useState(false)
  const [showLogoutConfirm, setShowLogoutConfirm] = useState(false)
  const profileRef = useRef(null)

  const [currentTab, setCurrentTab] = useState(() => {
    try {
      return localStorage.getItem('activeTab') || 'dashboard'
    } catch (e) {
      return 'dashboard'
    }
  })
  const [selectedFileId, setSelectedFileId] = useState(() => {
    try {
      return localStorage.getItem('activeFileId') || null
    } catch (e) {
      return null
    }
  })

  const navigateTab = (tab, fileId = null, push = true) => {
    setCurrentTab(tab)
    setSelectedFileId(fileId)
    try {
      localStorage.setItem('activeTab', tab)
      if (fileId) {
        localStorage.setItem('activeFileId', fileId)
      } else {
        localStorage.removeItem('activeFileId')
      }
      if (push && window.history?.pushState) {
        window.history.pushState({ tab, fileId }, '')
      }
    } catch (e) {
      console.error('History API error:', e)
    }
  }

  useEffect(() => {
    // Restore and setup initial history state on mount
    try {
      const currentState = window.history.state
      if (currentState && currentState.tab) {
        setCurrentTab(currentState.tab)
        setSelectedFileId(currentState.fileId || null)
        localStorage.setItem('activeTab', currentState.tab)
        if (currentState.fileId) {
          localStorage.setItem('activeFileId', currentState.fileId)
        } else {
          localStorage.removeItem('activeFileId')
        }
      } else {
        const storedTab = localStorage.getItem('activeTab') || 'dashboard'
        const storedFileId = localStorage.getItem('activeFileId') || null
        if (window.history?.replaceState) {
          window.history.replaceState({ tab: storedTab, fileId: storedFileId }, '')
        }
      }
    } catch (e) {
      console.error('History API error on mount:', e)
    }

    const handlePopState = (event) => {
      if (event.state && event.state.tab) {
        setCurrentTab(event.state.tab)
        setSelectedFileId(event.state.fileId || null)
        try {
          localStorage.setItem('activeTab', event.state.tab)
          if (event.state.fileId) {
            localStorage.setItem('activeFileId', event.state.fileId)
          } else {
            localStorage.removeItem('activeFileId')
          }
        } catch (e) {}
      } else {
        setCurrentTab('dashboard')
        setSelectedFileId(null)
        try {
          localStorage.setItem('activeTab', 'dashboard')
          localStorage.removeItem('activeFileId')
        } catch (e) {}
      }
    }

    function handleClick(e) {
      if (profileRef.current && !profileRef.current.contains(e.target)) {
        setProfileOpen(false)
      }
    }

    window.addEventListener('popstate', handlePopState)
    document.addEventListener('mousedown', handleClick)
    return () => {
      window.removeEventListener('popstate', handlePopState)
      document.removeEventListener('mousedown', handleClick)
    }
  }, [])

  function handleSignOut() {
    setShowLogoutConfirm(true)
    setProfileOpen(false)
  }

  async function confirmSignOut() {
    await signOut()
    navigate('/login', { replace: true })
  }

  function handleUploadClick() {
    navigateTab('files')
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
          <img 
            src="/favicon.png" 
            alt="Neo Files Logo" 
            className="w-8 h-8 object-contain"
          />
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
            <button
              key={item.id}
              onClick={() => {
                navigateTab(item.id)
                setSidebarOpen(false)
              }}
              className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors ${
                currentTab === item.id
                  ? 'bg-primary-600/20 text-primary-400'
                  : 'text-gray-400 hover:bg-dark-500 hover:text-gray-200'
              }`}
            >
              <item.icon size={20} />
              {item.label}
            </button>
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
            {currentTab !== 'files' && (
              <button
                onClick={handleUploadClick}
                className="btn-primary flex items-center gap-2 text-sm"
              >
                <Upload size={16} />
                <span className="hidden sm:inline">Upload</span>
              </button>
            )}
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
                  <button
                    onClick={() => {
                      navigateTab('settings')
                      setProfileOpen(false)
                    }}
                    className="flex items-center gap-2 px-4 py-2 text-sm text-gray-300 hover:bg-dark-500 w-full text-left"
                  >
                    <Settings size={16} /> Settings
                  </button>
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
          {currentTab === 'dashboard' && <DashboardPage onNavigate={(tab) => navigateTab(tab)} />}
          {currentTab === 'files' && <FilesPage onViewVersions={(fileId) => navigateTab('versions', fileId)} />}
          {currentTab === 'shared' && <SharedFilesPage />}
          {currentTab === 'settings' && <SettingsPage />}
          {currentTab === 'versions' && <VersionPage fileId={selectedFileId} onBack={() => window.history.back()} />}
        </main>
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
