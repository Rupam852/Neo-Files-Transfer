import { Routes, Route, Navigate } from 'react-router-dom'
import { useAuth } from './contexts/AuthContext'

// Layouts
import MainLayout from './layouts/MainLayout'
import DashboardLayout from './layouts/DashboardLayout'
import AdminLayout from './layouts/AdminLayout'

// Public Pages
import LandingPage from './pages/LandingPage'
import LoginPage from './pages/LoginPage'
import AuthCallback from './pages/AuthCallback'
import AccessDeniedPage from './pages/AccessDeniedPage'
import FileNotFoundPage from './pages/FileNotFoundPage'
import DownloadPage from './pages/DownloadPage'

// Protected Pages
import DashboardPage from './pages/DashboardPage'
import FilesPage from './pages/FilesPage'
import SharedFilesPage from './pages/SharedFilesPage'
import SettingsPage from './pages/SettingsPage'
import VersionPage from './pages/VersionPage'

// Admin Pages
import AdminLoginPage from './pages/AdminLoginPage'
import AdminDashboardPage from './pages/AdminDashboardPage'

function ProtectedRoute({ children }) {
  const { user, loading } = useAuth()
  if (loading) return <LoadingScreen />
  if (!user) return <Navigate to="/login" replace />
  return children
}

function AdminRoute({ children }) {
  const { user, isAdmin, loading } = useAuth()
  if (loading) return <LoadingScreen />
  if (!user) return <Navigate to="/admin" replace />
  if (!isAdmin) return <Navigate to="/admin" replace />
  return children
}

function LoadingScreen() {
  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="flex flex-col items-center gap-4">
        <div className="w-10 h-10 border-4 border-primary-600 border-t-transparent rounded-full animate-spin" />
        <p className="text-gray-500 text-sm">Loading...</p>
      </div>
    </div>
  )
}

export default function App() {
  return (
    <Routes>
      {/* Public Routes */}
      <Route path="/" element={<MainLayout />}>
        <Route index element={<LandingPage />} />
        <Route path="login" element={<LoginPage />} />
        <Route path="auth/callback" element={<AuthCallback />} />
      </Route>

      {/* Admin Routes */}
      <Route path="/admin" element={<AdminLayout />}>
        <Route index element={<AdminLoginPage />} />
        <Route path="dashboard" element={
          <AdminRoute><AdminDashboardPage /></AdminRoute>
        } />
      </Route>

      {/* Protected Routes */}
      <Route path="/dashboard" element={
        <ProtectedRoute><DashboardLayout /></ProtectedRoute>
      }>
        <Route index element={<DashboardPage />} />
        <Route path="files" element={<FilesPage />} />
        <Route path="shared" element={<SharedFilesPage />} />
        <Route path="settings" element={<SettingsPage />} />
        <Route path="files/:fileId/versions" element={<VersionPage />} />
      </Route>

      {/* Download Routes */}
      <Route path="/download/:hash" element={<DownloadPage />} />

      {/* Error Pages */}
      <Route path="/access-denied" element={<AccessDeniedPage />} />
      <Route path="*" element={<FileNotFoundPage />} />
    </Routes>
  )
}
