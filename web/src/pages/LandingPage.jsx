import { useState } from 'react'
import { Link } from 'react-router-dom'
import { supabase } from '../services/supabase'
import toast from 'react-hot-toast'
import { 
  Cloud, Shield, Link2, ArrowRight, AlertTriangle, 
  LogIn, UserCheck, HardDrive, Share2, Layers, CheckCircle2 
} from 'lucide-react'

export default function LandingPage() {
  const [formData, setFormData] = useState({ name: '', phone: '', email: '' })
  const [submitting, setSubmitting] = useState(false)

  async function handleSubmit(e) {
    e.preventDefault()
    if (!formData.name || !formData.phone || !formData.email) {
      toast.error('All fields are required')
      return
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    if (!emailRegex.test(formData.email)) {
      toast.error('Please enter a valid email address')
      return
    }

    setSubmitting(true)
    try {
      const { data: existing } = await supabase
        .from('pending_registrations')
        .select('id')
        .eq('email', formData.email.toLowerCase())
        .in('status', ['pending', 'approved'])
        .maybeSingle()

      if (existing) {
        toast.error('This email is already registered')
        return
      }

      const { error } = await supabase
        .from('pending_registrations')
        .insert({
          name: formData.name,
          phone: formData.phone,
          email: formData.email.toLowerCase(),
          status: 'pending',
        })

      if (error) throw error

      toast.success('Registration submitted! Please wait for admin approval.')
      setFormData({ name: '', phone: '', email: '' })
    } catch (err) {
      console.error(err)
      toast.error('Registration failed. Please try again.')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="min-h-screen bg-[#070b14] text-gray-100 font-['Plus_Jakarta_Sans'] relative overflow-hidden selection:bg-primary-600/30 selection:text-white">
      {/* Import Premium Fonts */}
      <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Space+Grotesk:wght@500;600;700&display=swap" rel="stylesheet" />

      {/* Futuristic Background Mesh Gradients */}
      <div className="absolute top-[-10%] left-[-10%] w-[50%] h-[50%] rounded-full bg-primary-600/10 blur-[130px] pointer-events-none animate-pulse duration-[8s]" />
      <div className="absolute bottom-[-10%] right-[-10%] w-[60%] h-[60%] rounded-full bg-purple-600/10 blur-[150px] pointer-events-none animate-pulse duration-[10s]" />
      <div className="absolute top-[30%] left-[40%] w-[300px] h-[300px] rounded-full bg-teal-500/5 blur-[100px] pointer-events-none" />

      {/* Subtle Grid Overlay */}
      <div className="absolute inset-0 bg-[linear-gradient(to_right,#ffffff03_1px,transparent_1px),linear-gradient(to_bottom,#ffffff03_1px,transparent_1px)] bg-[size:40px_40px] pointer-events-none" />

      {/* Header */}
      <header className="relative z-10 border-b border-white/5 bg-[#070b14]/50 backdrop-blur-md sticky top-0">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 h-20 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-gradient-to-tr from-primary-600 to-purple-600 rounded-xl flex items-center justify-center shadow-lg shadow-primary-600/20">
              <span className="text-white font-extrabold text-base tracking-wider font-['Space_Grotesk']">NF</span>
            </div>
            <span className="font-bold text-xl tracking-tight text-white font-['Space_Grotesk']">
              Neo<span className="text-primary-500">Files</span>
            </span>
          </div>

          <nav className="hidden md:flex items-center gap-8 text-sm font-medium text-gray-400">
            <a href="#features" className="hover:text-white transition-colors">Features</a>
            <a href="#security" className="hover:text-white transition-colors">Security</a>
            <a href="#register" className="hover:text-white transition-colors">Register</a>
          </nav>

          <div className="flex items-center gap-3">
            <Link 
              to="/login" 
              className="px-5 py-2.5 bg-white/5 hover:bg-white/10 text-white border border-white/10 rounded-xl text-sm font-semibold transition-all duration-200 flex items-center gap-2 hover:shadow-[0_0_15px_rgba(255,255,255,0.05)]"
            >
              <LogIn size={15} />
              Login
            </Link>
          </div>
        </div>
      </header>

      {/* Hero & Registration Section */}
      <section className="relative z-10 max-w-6xl mx-auto px-4 sm:px-6 pt-16 pb-24 lg:pt-24 lg:pb-32">
        <div className="grid lg:grid-cols-12 gap-12 lg:gap-8 items-center">
          
          {/* Left Side: Headline & Copy */}
          <div className="lg:col-span-7 space-y-8 text-center lg:text-left">
            <div className="inline-flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-primary-600/10 to-purple-600/10 border border-primary-500/20 text-primary-400 rounded-full text-xs font-semibold uppercase tracking-wider">
              <Cloud size={14} className="animate-bounce" />
              Advanced File Management
            </div>
            
            <h1 className="text-4xl sm:text-5xl lg:text-6xl font-extrabold text-white tracking-tight leading-[1.1] font-['Space_Grotesk']">
              Secure Cloud <br />
              <span className="bg-clip-text text-transparent bg-gradient-to-r from-primary-400 via-purple-400 to-teal-400">
                File Distribution
              </span>
            </h1>

            <p className="text-base sm:text-lg text-gray-400 max-w-xl mx-auto lg:mx-0 leading-relaxed">
              Upload files to your custom Google Drive storage and generate proxy download links. 
              Track version histories, share anonymously, and keep your primary drive private.
            </p>

            {/* Micro Feature Indicators */}
            <div className="grid sm:grid-cols-3 gap-4 pt-4 text-left max-w-md mx-auto lg:mx-0">
              <div className="flex items-center gap-2 text-sm text-gray-300">
                <CheckCircle2 size={16} className="text-teal-400 flex-shrink-0" />
                <span>Infinite Storage</span>
              </div>
              <div className="flex items-center gap-2 text-sm text-gray-300">
                <CheckCircle2 size={16} className="text-primary-400 flex-shrink-0" />
                <span>Encrypted Proxy</span>
              </div>
              <div className="flex items-center gap-2 text-sm text-gray-300">
                <CheckCircle2 size={16} className="text-purple-400 flex-shrink-0" />
                <span>Version History</span>
              </div>
            </div>
          </div>

          {/* Right Side: Glassmorphic Registration Widget */}
          <div id="register" className="lg:col-span-5 relative">
            {/* Widget Glow Backdrop */}
            <div className="absolute inset-0 bg-gradient-to-tr from-primary-600/20 to-purple-600/20 rounded-2xl filter blur-xl opacity-70 pointer-events-none" />

            <div className="relative bg-white/[0.02] backdrop-blur-2xl border border-white/10 shadow-2xl p-8 rounded-2xl space-y-6">
              <div className="space-y-2 text-center lg:text-left">
                <h3 className="text-2xl font-bold text-white font-['Space_Grotesk'] flex items-center justify-center lg:justify-start gap-2">
                  <UserCheck size={22} className="text-primary-400" />
                  Request Access
                </h3>
                <p className="text-xs text-gray-400">
                  Submit details. Login becomes active once approved by an admin.
                </p>
              </div>

              {/* Warning Message inside Widget */}
              <div className="bg-amber-500/10 border border-amber-500/20 rounded-xl p-3 flex items-start gap-2.5">
                <AlertTriangle size={16} className="text-amber-400 mt-0.5 flex-shrink-0" />
                <p className="text-[11px] text-amber-200 leading-normal">
                  Your Google login email must match the registration email requested here.
                </p>
              </div>

              <form onSubmit={handleSubmit} className="space-y-4">
                <div>
                  <label className="block text-xs font-semibold text-gray-400 uppercase tracking-wider mb-1.5">Full Name</label>
                  <input
                    type="text"
                    className="w-full px-4 py-3 bg-[#0d1527]/50 border border-white/5 text-gray-100 placeholder-gray-600 rounded-xl focus:ring-2 focus:ring-primary-500 focus:border-primary-500 outline-none transition-all duration-200 text-sm font-medium"
                    placeholder="John Doe"
                    value={formData.name}
                    onChange={e => setFormData({ ...formData, name: e.target.value })}
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-gray-400 uppercase tracking-wider mb-1.5">Phone Number</label>
                  <input
                    type="tel"
                    className="w-full px-4 py-3 bg-[#0d1527]/50 border border-white/5 text-gray-100 placeholder-gray-600 rounded-xl focus:ring-2 focus:ring-primary-500 focus:border-primary-500 outline-none transition-all duration-200 text-sm font-medium"
                    placeholder="+91 XXXXX XXXXX"
                    value={formData.phone}
                    onChange={e => setFormData({ ...formData, phone: e.target.value })}
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-gray-400 uppercase tracking-wider mb-1.5">Email Address</label>
                  <input
                    type="email"
                    className="w-full px-4 py-3 bg-[#0d1527]/50 border border-white/5 text-gray-100 placeholder-gray-600 rounded-xl focus:ring-2 focus:ring-primary-500 focus:border-primary-500 outline-none transition-all duration-200 text-sm font-medium"
                    placeholder="your-google-email@gmail.com"
                    value={formData.email}
                    onChange={e => setFormData({ ...formData, email: e.target.value })}
                    required
                  />
                </div>
                <button
                  type="submit"
                  disabled={submitting}
                  className="w-full py-3.5 bg-gradient-to-r from-primary-600 to-purple-600 hover:from-primary-500 hover:to-purple-500 text-white rounded-xl text-sm font-semibold transition-all duration-300 transform hover:scale-[1.01] active:scale-[0.99] disabled:opacity-50 disabled:cursor-not-allowed shadow-lg shadow-primary-600/20"
                >
                  {submitting ? 'Submitting Request...' : 'Submit Registration'}
                </button>
              </form>
            </div>
          </div>
        </div>
      </section>

      {/* Feature Highlights Grid */}
      <section id="features" className="relative z-10 py-24 bg-black/20 border-y border-white/5">
        <div className="max-w-6xl mx-auto px-4 sm:px-6">
          <div className="text-center max-w-2xl mx-auto mb-16 space-y-3">
            <h2 className="text-3xl font-extrabold text-white font-['Space_Grotesk']">
              Why use Neo Files?
            </h2>
            <p className="text-sm text-gray-400">
              A comprehensive toolset engineered to simplify storage management and enhance sharing control.
            </p>
          </div>

          <div className="grid md:grid-cols-3 gap-8">
            <div className="bg-white/[0.01] border border-white/5 p-8 rounded-2xl space-y-4 hover:border-primary-500/30 hover:bg-white/[0.02] transition-all duration-300 group hover:-translate-y-1">
              <div className="w-12 h-12 bg-primary-600/10 border border-primary-500/20 rounded-xl flex items-center justify-center group-hover:scale-110 transition-transform">
                <HardDrive size={24} className="text-primary-400" />
              </div>
              <h3 className="font-semibold text-lg text-white font-['Space_Grotesk']">Google Drive Backed</h3>
              <p className="text-gray-400 text-sm leading-relaxed">
                Connect your Drive folder to serve as the backend storage. Benefit from Google's reliable infrastructure with no file limit constraints.
              </p>
            </div>

            <div className="bg-white/[0.01] border border-white/5 p-8 rounded-2xl space-y-4 hover:border-purple-500/30 hover:bg-white/[0.02] transition-all duration-300 group hover:-translate-y-1">
              <div className="w-12 h-12 bg-purple-600/10 border border-purple-500/20 rounded-xl flex items-center justify-center group-hover:scale-110 transition-transform">
                <Share2 size={24} className="text-purple-400" />
              </div>
              <h3 className="font-semibold text-lg text-white font-['Space_Grotesk']">Proxy Share Links</h3>
              <p className="text-gray-400 text-sm leading-relaxed">
                Keep primary download links hidden behind our proxy server. Manage access controls and revoke download permissions at any time.
              </p>
            </div>

            <div className="bg-white/[0.01] border border-white/5 p-8 rounded-2xl space-y-4 hover:border-teal-500/30 hover:bg-white/[0.02] transition-all duration-300 group hover:-translate-y-1">
              <div className="w-12 h-12 bg-teal-600/10 border border-teal-500/20 rounded-xl flex items-center justify-center group-hover:scale-110 transition-transform">
                <Layers size={24} className="text-teal-400" />
              </div>
              <h3 className="font-semibold text-lg text-white font-['Space_Grotesk']">Automatic Versioning</h3>
              <p className="text-gray-400 text-sm leading-relaxed">
                Update files easily without breaking existing shares. The platform tracks previous versions and always displays the latest release to users.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Security Info Panel */}
      <section id="security" className="relative z-10 max-w-6xl mx-auto px-4 sm:px-6 py-24">
        <div className="bg-gradient-to-tr from-primary-600/5 to-purple-600/5 border border-white/5 rounded-3xl p-8 sm:p-12 relative overflow-hidden flex flex-col md:flex-row items-center gap-8 justify-between">
          <div className="absolute top-0 right-0 w-[300px] h-[300px] bg-primary-600/10 rounded-full blur-[80px] pointer-events-none" />
          
          <div className="space-y-4 max-w-xl text-center md:text-left">
            <div className="w-12 h-12 bg-white/5 rounded-2xl flex items-center justify-center mx-auto md:mx-0">
              <Shield size={24} className="text-teal-400 animate-pulse" />
            </div>
            <h3 className="text-2xl sm:text-3xl font-bold text-white font-['Space_Grotesk']">
              Enterprise Grade Privacy Controls
            </h3>
            <p className="text-sm text-gray-400 leading-relaxed">
              We leverage Row Level Security (RLS) on database calls combined with short-lived JWT signatures. 
              Only verified approved users can trigger storage functions, ensuring absolute compliance with cloud security standards.
            </p>
          </div>

          <div className="flex-shrink-0">
            <Link 
              to="/login"
              className="px-8 py-4 bg-white text-gray-900 rounded-xl text-sm font-bold hover:bg-gray-100 transition-colors shadow-lg shadow-white/5 inline-flex items-center gap-2"
            >
              Sign In To Console
              <ArrowRight size={16} />
            </Link>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="relative z-10 border-t border-white/5 py-12 bg-black/40">
        <div className="max-w-6xl mx-auto px-4 sm:px-6">
          <div className="flex flex-col sm:flex-row items-center justify-between gap-6">
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 bg-white/5 rounded-lg flex items-center justify-center">
                <span className="text-white font-bold text-xs">NF</span>
              </div>
              <span className="text-xs text-gray-500">Neo Files Transfer v1.0 • Built with Supabase & Google Drive</span>
            </div>
            <div className="flex gap-6 text-xs text-gray-500">
              <a href="#" className="hover:text-gray-300">Privacy Policy</a>
              <a href="#" className="hover:text-gray-300">Terms of Service</a>
            </div>
          </div>
        </div>
      </footer>
    </div>
  )
}
