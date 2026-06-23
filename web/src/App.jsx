import { useEffect } from 'react'
import { Routes, Route, Navigate } from 'react-router-dom'
import { useAuth } from './contexts/AuthContext'

import { ShieldAlert, LogOut } from 'lucide-react'

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
import PrivacyPolicyPage from './pages/PrivacyPolicyPage'
import TermsOfServicePage from './pages/TermsOfServicePage'

// Admin Pages
import AdminLoginPage from './pages/AdminLoginPage'
import AdminDashboardPage from './pages/AdminDashboardPage'

function LoadingScreen() {
  return (
    <div className="min-h-screen flex items-center justify-center bg-[#030712]">
      <div className="flex flex-col items-center gap-4">
        <div className="w-10 h-10 border-4 border-primary-600 border-t-transparent rounded-full animate-spin" />
        <p className="text-gray-400 text-sm">Loading...</p>
      </div>
    </div>
  )
}

function TemporaryBlockScreen() {
  const { signOut } = useAuth()

  return (
    <div className="min-h-screen w-full bg-[#030712] text-gray-100 flex items-center justify-center p-4 sm:p-6 lg:p-8 font-['Plus_Jakarta_Sans'] relative overflow-hidden">
      {/* Import Premium Fonts */}
      <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Space+Grotesk:wght@500;600;700&display=swap" rel="stylesheet" />

      {/* Futuristic Background Light Glows */}
      <div className="absolute top-[-10%] left-[-10%] w-[50%] h-[50%] rounded-full bg-red-500/5 blur-[120px] pointer-events-none" />
      <div className="absolute bottom-[-10%] right-[-10%] w-[50%] h-[50%] rounded-full bg-red-500/5 blur-[120px] pointer-events-none" />

      {/* Main Card */}
      <div className="w-full max-w-md bg-slate-950/80 backdrop-blur-3xl border border-red-500/10 rounded-3xl p-6 sm:p-8 shadow-2xl relative z-10 text-center space-y-6">
        <div className="w-16 h-16 bg-red-500/10 border border-red-500/20 rounded-2xl flex items-center justify-center mx-auto text-red-400">
          <ShieldAlert size={36} className="animate-pulse" />
        </div>
        
        <div className="space-y-2">
          <h2 className="text-2xl font-bold text-white font-['Space_Grotesk']">Account Temporarily Paused</h2>
          <p className="text-sm text-slate-400">
            Your access has been temporarily suspended by the administrator. Your files and data remain securely stored.
          </p>
          <div className="bg-red-500/5 border border-red-500/10 rounded-xl p-3 text-xs text-red-400 font-semibold mt-2">
            Please contact developer support.
          </div>
        </div>

        <button
          onClick={signOut}
          className="w-full bg-dark-500 hover:bg-dark-400 border border-dark-300 text-gray-200 py-3 rounded-xl font-bold flex items-center justify-center gap-2 transition-all duration-300 active:scale-[0.98]"
        >
          <LogOut size={18} /> Sign Out
        </button>
      </div>
    </div>
  )
}

// HomeRoute resolves the base URL page dynamically based on login and roles
function HomeRoute() {
  const { user, isAdmin, isPaused, loading } = useAuth()

  if (loading) return <LoadingScreen />

  if (!user) {
    return <LandingPage />
  }

  if (isAdmin) {
    return <AdminDashboardPage />
  }

  if (isPaused) {
    return <TemporaryBlockScreen />
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
        <Route path="privacy" element={<PrivacyPolicyPage />} />
        <Route path="terms" element={<TermsOfServicePage />} />
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
