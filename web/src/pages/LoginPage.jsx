import { useAuth } from '../contexts/AuthContext'
import { useNavigate, Link } from 'react-router-dom'
import { useEffect } from 'react'
import { supabase } from '../services/supabase'
import toast from 'react-hot-toast'
import { Shield, ArrowLeft, AlertTriangle, LogIn } from 'lucide-react'

export default function LoginPage() {
  const { signInWithGoogle, user, loading } = useAuth()
  const navigate = useNavigate()

  useEffect(() => {
    if (user && !loading) {
      navigate('/')
    }
  }, [user, loading, navigate])

  async function handleLogin() {
    try {
      // Check if user is approved
      const { data: { user: currentUser } } = await supabase.auth.getUser()
      if (!currentUser) {
        await signInWithGoogle()
      }
    } catch (err) {
      console.error(err)
      toast.error('Login failed. Please try again.')
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-[#030712]">
        <div className="w-10 h-10 border-4 border-indigo-600 border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-[#030712] text-gray-100 flex items-center justify-center p-4 sm:p-6 lg:p-8 font-['Plus_Jakarta_Sans'] relative overflow-hidden">
      {/* Import Premium Fonts */}
      <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Space+Grotesk:wght@500;600;700&display=swap" rel="stylesheet" />

      {/* Futuristic Background Light Glows */}
      <div className="absolute top-[-10%] left-[-10%] w-[50%] h-[50%] rounded-full bg-indigo-500/5 blur-[120px] pointer-events-none" />
      <div className="absolute bottom-[-10%] right-[-10%] w-[50%] h-[50%] rounded-full bg-purple-500/5 blur-[120px] pointer-events-none" />

      {/* Main Container Card */}
      <div className="w-full max-w-4xl bg-slate-950/80 backdrop-blur-3xl border border-slate-900 rounded-3xl overflow-hidden shadow-2xl flex flex-col md:flex-row h-auto md:h-[600px] relative z-10">
        
        {/* Left Side: Dark Blue Rounded Panel with App Logo */}
        <div className="hidden md:flex md:w-1/2 m-3 rounded-2xl bg-gradient-to-br from-indigo-950/50 via-[#0a152e] to-[#040914] border border-slate-900/60 p-8 flex-col justify-between relative overflow-hidden">
          {/* Background Light Effects inside panel */}
          <div className="absolute -top-12 -left-12 w-48 h-48 rounded-full bg-indigo-500/10 blur-[80px] pointer-events-none" />
          <div className="absolute -bottom-12 -right-12 w-48 h-48 rounded-full bg-purple-500/10 blur-[80px] pointer-events-none" />
          <div className="absolute inset-0 bg-[linear-gradient(to_right,#ffffff01_1px,transparent_1px),linear-gradient(to_bottom,#ffffff01_1px,transparent_1px)] bg-[size:20px_20px] pointer-events-none" />

          {/* Logo */}
          <div className="flex items-center gap-3 z-10">
            <img 
              src="/favicon.png" 
              alt="Neo Files Logo" 
              className="w-10 h-10 object-contain"
            />
            <span className="font-bold text-xl tracking-tight text-white font-['Space_Grotesk']">
              Neo<span className="text-indigo-400">Files</span>
            </span>
          </div>

          {/* Visual Feature Info */}
          <div className="space-y-6 z-10 my-auto">
            <div className="inline-flex items-center gap-2 px-3 py-1 bg-indigo-500/10 border border-indigo-500/20 text-indigo-400 rounded-full text-xs font-semibold uppercase tracking-wider">
              <Shield size={12} className="animate-pulse" />
              SECURE CONSOLE
            </div>
            <h2 className="text-3xl font-extrabold text-white font-['Space_Grotesk'] leading-tight">
              Private Proxy & <br />
              <span className="bg-clip-text text-transparent bg-gradient-to-r from-indigo-400 to-pink-400">
                Storage Shield
              </span>
            </h2>
            <p className="text-slate-400 text-sm leading-relaxed font-normal">
              Bypass direct storage API exposure. Keep files secure with granular row level security, sharing controls, and full auditing dashboard.
            </p>
          </div>

          {/* Footer inside Left Panel */}
          <div className="z-10 flex items-center justify-center text-[11px] text-slate-500 font-medium">
            <span>Neo Files Transfer</span>
          </div>
        </div>

        {/* Right Side: Interactive Login Interface */}
        <div className="w-full md:w-1/2 p-8 sm:p-10 md:p-12 flex flex-col justify-between">
          
          {/* Logo fallback for mobile view */}
          <div className="flex md:hidden items-center justify-center gap-3 mb-8">
            <img 
              src="/favicon.png" 
              alt="Neo Files Logo" 
              className="w-9 h-9 object-contain"
            />
            <span className="font-bold text-lg text-white font-['Space_Grotesk']">
              Neo<span className="text-indigo-400">Files</span>
            </span>
          </div>

          {/* Header Title block */}
          <div className="space-y-2.5 text-center md:text-left mt-auto md:mt-0 mb-8">
            <h1 className="text-2xl sm:text-3xl font-extrabold text-white font-['Space_Grotesk'] flex items-center justify-center md:justify-start gap-2">
              Welcome Back
            </h1>
            <p className="text-xs sm:text-sm text-slate-400">
              Sign in to gain entry into your private console node.
            </p>
          </div>

          {/* Google Login Action block */}
          <div className="space-y-6 my-auto">
            <button
              onClick={handleLogin}
              className="w-full flex items-center justify-center gap-3 bg-slate-900/50 hover:bg-slate-900 border border-slate-800 hover:border-slate-700 text-gray-200 hover:text-white font-semibold py-3.5 px-4 rounded-xl transition-all duration-300 transform hover:scale-[1.01] active:scale-[0.99] shadow-lg shadow-black/20 cursor-pointer"
            >
              <svg className="w-5 h-5 flex-shrink-0" viewBox="0 0 24 24">
                <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 01-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z" fill="#4285F4" />
                <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853" />
                <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05" />
                <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335" />
              </svg>
              <span>Continue with Google</span>
            </button>

            {/* Warning Alert inside form area */}
            <div className="bg-amber-500/5 border border-amber-500/10 rounded-xl p-3.5 flex items-start gap-3">
              <AlertTriangle size={16} className="text-amber-400 mt-0.5 flex-shrink-0" />
              <p className="text-[11px] text-amber-300/80 leading-relaxed">
                Ensure your current Google account email matches your requested email invitation. Unapproved users will be restricted from accessing storage consoles.
              </p>
            </div>
          </div>

          {/* Back Navigation bottom block */}
          <div className="mt-8 mb-auto md:mb-0 text-center md:text-left">
            <Link 
              to="/" 
              className="inline-flex items-center gap-2 text-xs font-semibold text-slate-500 hover:text-indigo-400 transition-colors"
            >
              <ArrowLeft size={14} />
              Back to Home
            </Link>
          </div>

        </div>

      </div>
    </div>
  )
}
