import { useEffect } from 'react'
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

// Admin Pages
import AdminLoginPage from './pages/AdminLoginPage'
import AdminDashboardPage from './pages/AdminDashboardPage'

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

// HomeRoute resolves the base URL page dynamically based on login and roles
function HomeRoute() {
  const { user, isAdmin, loading } = useAuth()

  if (loading) return <LoadingScreen />

  if (!user) {
    return <LandingPage />
  }

  if (isAdmin) {
    return <AdminDashboardPage />
  }

  return <DashboardLayout />
}

export default function App() {
  useEffect(() => {
    let timeout;
    const handleScroll = () => {
      document.documentElement.classList.add('is-scrolling');
      document.body.classList.add('is-scrolling');
      clearTimeout(timeout);
      timeout = setTimeout(() => {
        document.documentElement.classList.remove('is-scrolling');
        document.body.classList.remove('is-scrolling');
      }, 1000);
    };
    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => {
      window.removeEventListener('scroll', handleScroll);
      clearTimeout(timeout);
    };
  }, []);

  return (
    <Routes>
      {/* Public Routes */}
      <Route path="/" element={<MainLayout />}>
        <Route index element={<HomeRoute />} />
        <Route path="login" element={<LoginPage />} />
        <Route path="auth/callback" element={<AuthCallback />} />
      </Route>

      {/* Admin Route */}
      <Route path="/admin" element={<AdminLayout />}>
        <Route index element={<AdminLoginPage />} />
      </Route>

      {/* Download Routes */}
      <Route path="/download/:hash" element={<DownloadPage />} />

      {/* Error Pages */}
      <Route path="/access-denied" element={<AccessDeniedPage />} />
      <Route path="*" element={<FileNotFoundPage />} />
    </Routes>
  )
}
