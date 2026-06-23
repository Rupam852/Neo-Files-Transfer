import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../services/supabase'
import { useAuth } from '../contexts/AuthContext'
import toast from 'react-hot-toast'
import { Shield, AlertTriangle } from 'lucide-react'

export default function AdminLoginPage() {
  const { user, isAdmin, signInWithGoogle, loading } = useAuth()
  const navigate = useNavigate()
  const [loggingIn, setLoggingIn] = useState(false)

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="w-10 h-10 border-4 border-primary-600 border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }

  if (user && isAdmin) {
    navigate('/', { replace: true })
    return null
  }

  async function handleAdminLogin() {
    setLoggingIn(true)
    try {
      await signInWithGoogle()
    } catch (err) {
      toast.error('Admin login failed')
    } finally {
      setLoggingIn(false)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center px-4">
      <div className="w-full max-w-sm">
        <div className="text-center mb-8">
          <div className="w-12 h-12 bg-primary-600 rounded-xl flex items-center justify-center mx-auto mb-4">
            <Shield size={24} className="text-white" />
          </div>
          <h1 className="text-2xl font-bold text-gray-50">Admin Portal</h1>
          <p className="text-gray-400 text-sm mt-2">
            Neo Files Transfer Administration
          </p>
        </div>

        <div className="card">
          {user && !isAdmin && (
            <div className="bg-amber-50 border border-amber-200 rounded-lg p-3 mb-4 flex items-start gap-2">
              <AlertTriangle size={16} className="text-amber-500 mt-0.5 flex-shrink-0" />
              <p className="text-sm text-amber-800">
                This account does not have admin privileges.
              </p>
            </div>
          )}

          <button
            onClick={handleAdminLogin}
            disabled={loggingIn}
            className="w-full flex items-center justify-center gap-3 bg-dark-500 border border-dark-300 hover:bg-dark-400 text-gray-200 font-medium py-3 px-4 rounded-lg transition-colors disabled:opacity-50"
          >
            <svg className="w-5 h-5" viewBox="0 0 24 24">
              <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 01-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z" fill="#4285F4" />
              <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853" />
              <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05" />
              <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335" />
            </svg>
            {loggingIn ? 'Signing in...' : 'Sign in with Google'}
          </button>
        </div>

        <p className="text-center text-sm text-gray-400 mt-6">
          <a href="/" className="text-primary-600 hover:underline">Back to Home</a>
        </p>
      </div>
    </div>
  )
}
