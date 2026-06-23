import { useState } from 'react'
import { Link } from 'react-router-dom'
import { supabase } from '../services/supabase'
import toast from 'react-hot-toast'
import { 
  Cloud, Shield, Link2, ArrowRight, AlertTriangle, 
  LogIn, UserCheck, HardDrive, Share2, Layers, CheckCircle2,
  User, Phone, Mail, FileText, Activity, Database, Copy, Plus
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
    <div className="min-h-screen bg-[#030712] text-gray-100 font-['Plus_Jakarta_Sans'] relative overflow-hidden selection:bg-indigo-500/30 selection:text-white">
      {/* Import Premium Fonts */}
      <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Space+Grotesk:wght@500;600;700&display=swap" rel="stylesheet" />

      {/* Futuristic Background Mesh Gradients */}
      <div className="absolute top-[-10%] left-[-10%] w-[50%] h-[50%] rounded-full bg-indigo-500/10 blur-[130px] pointer-events-none animate-float opacity-80" />
      <div className="absolute bottom-0 right-0 translate-x-1/4 translate-y-1/4 w-[50%] h-[50%] rounded-full bg-purple-600/10 blur-[150px] pointer-events-none animate-float-delayed opacity-75" />
      <div className="absolute top-[30%] left-[40%] w-[300px] h-[300px] rounded-full bg-cyan-500/5 blur-[100px] pointer-events-none animate-float opacity-50" />

      {/* Subtle Grid Overlay */}
      <div className="absolute inset-0 bg-[linear-gradient(to_right,#ffffff02_1px,transparent_1px),linear-gradient(to_bottom,#ffffff02_1px,transparent_1px)] bg-[size:30px_30px] pointer-events-none" />

      {/* Header */}
      <header className="relative z-20 border-b border-white/5 bg-[#030712]/60 backdrop-blur-xl sticky top-0">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 h-20 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-gradient-to-tr from-indigo-500 to-purple-600 rounded-xl flex items-center justify-center shadow-lg shadow-indigo-500/20 hover:rotate-6 transition-transform duration-300">
              <span className="text-white font-extrabold text-base tracking-wider font-['Space_Grotesk']">NF</span>
            </div>
            <span className="font-bold text-xl tracking-tight text-white font-['Space_Grotesk']">
              Neo<span className="text-indigo-400">Files</span>
            </span>
          </div>

          <nav className="hidden md:flex items-center gap-8 text-sm font-medium text-gray-400">
            <a href="#features" className="hover:text-white transition-colors relative after:absolute after:bottom-[-4px] after:left-0 after:w-0 after:h-[2px] after:bg-indigo-500 hover:after:w-full after:transition-all after:duration-300">Features</a>
            <a href="#security" className="hover:text-white transition-colors relative after:absolute after:bottom-[-4px] after:left-0 after:w-0 after:h-[2px] after:bg-indigo-500 hover:after:w-full after:transition-all after:duration-300">Security</a>
            <Link to="/privacy" className="hover:text-white transition-colors relative after:absolute after:bottom-[-4px] after:left-0 after:w-0 after:h-[2px] after:bg-indigo-500 hover:after:w-full after:transition-all after:duration-300">Privacy Policy</Link>
          </nav>

          <div className="flex items-center gap-3">
            <Link 
              to="/login" 
              className="px-5 py-2.5 bg-white/5 hover:bg-white/10 text-white border border-white/10 rounded-xl text-sm font-semibold transition-all duration-200 flex items-center gap-2 hover:shadow-[0_0_15px_rgba(255,255,255,0.05)] hover:scale-[1.02]"
            >
              <LogIn size={15} />
              Login
            </Link>
          </div>
        </div>
      </header>

      {/* Hero & Registration Section */}
      <section className="relative z-10 max-w-6xl mx-auto px-4 sm:px-6 pt-12 pb-24 lg:pt-20 lg:pb-32">
        <div className="grid lg:grid-cols-12 gap-16 lg:gap-8 items-center">
          
          {/* Left Side: Headline & Copy */}
          <div className="lg:col-span-6 space-y-8 text-center lg:text-left">
            <div className="inline-flex items-center gap-2 px-3 py-1 bg-indigo-500/10 border border-indigo-500/20 text-indigo-400 rounded-full text-xs font-semibold uppercase tracking-wider animate-fade-in-up">
              <span className="w-1.5 h-1.5 rounded-full bg-indigo-400 animate-ping" />
              v1.0 Live Proxy Storage
            </div>
            
            <h1 className="text-4xl sm:text-5xl lg:text-6xl font-extrabold text-white tracking-tight leading-[1.1] font-['Space_Grotesk'] animate-fade-in-up animation-delay-100">
              Secure Cloud <br />
              <span className="bg-clip-text text-transparent bg-gradient-to-r from-indigo-400 via-purple-400 to-pink-400">
                File Distribution
              </span>
            </h1>

            <p className="text-base sm:text-lg text-gray-400 max-w-xl mx-auto lg:mx-0 leading-relaxed animate-fade-in-up animation-delay-200">
              Upload files directly to private Google Drive backends and distribute secure proxy download links. 
              Track logs, control access, and scale storage with zero limits.
            </p>

            {/* Premium Micro Feature Pills */}
            <div className="flex flex-wrap gap-3 justify-center lg:justify-start pt-4 animate-fade-in-up animation-delay-300">
              <div className="flex items-center gap-2 px-3.5 py-1.5 bg-emerald-500/5 border border-emerald-500/10 rounded-full text-xs font-semibold text-emerald-400">
                <Database size={13} />
                <span>Unlimited Drive Storage</span>
              </div>
              <div className="flex items-center gap-2 px-3.5 py-1.5 bg-indigo-500/5 border border-indigo-500/10 rounded-full text-xs font-semibold text-indigo-400">
                <Shield size={13} />
                <span>Proxy Encrypted API</span>
              </div>
              <div className="flex items-center gap-2 px-3.5 py-1.5 bg-purple-500/5 border border-purple-500/10 rounded-full text-xs font-semibold text-purple-400">
                <Activity size={13} />
                <span>Live Share Auditing</span>
              </div>
            </div>
          </div>

          {/* Right Side: Overlapping Mock Console & Registration Card */}
          <div id="register" className="lg:col-span-6 relative flex justify-center lg:justify-end animate-fade-in-up animation-delay-300">
            <div className="relative w-full max-w-md">
              
              {/* Glow Backdrop */}
              <div className="absolute inset-0 bg-gradient-to-tr from-indigo-500/20 to-purple-500/20 rounded-2xl filter blur-2xl opacity-80 pointer-events-none animate-pulse-glow" />

              {/* Center Main Card: Sleek Developer Portal Form */}
              <div className="relative bg-slate-950/85 backdrop-blur-3xl border border-slate-800 shadow-2xl p-8 rounded-2xl space-y-6 z-10">
                <div className="space-y-2 text-center lg:text-left">
                  <h3 className="text-2xl font-bold text-white font-['Space_Grotesk'] flex items-center justify-center lg:justify-start gap-2">
                    <UserCheck size={22} className="text-indigo-400 animate-pulse" />
                    Request Access
                  </h3>
                  <p className="text-xs text-gray-400">
                    Register your details. Login becomes active once approved by an admin.
                  </p>
                </div>

                {/* Cyber Warning Alert */}
                <div className="bg-amber-500/10 border border-amber-500/20 rounded-xl p-3 flex items-start gap-2.5">
                  <AlertTriangle size={15} className="text-amber-400 mt-0.5 flex-shrink-0" />
                  <p className="text-[11px] text-amber-300/90 leading-normal">
                    Your Google login email must match the registration email requested here.
                  </p>
                </div>

                <form onSubmit={handleSubmit} className="space-y-4">
                  {/* Name Input */}
                  <div className="relative">
                    <label className="block text-[10px] font-semibold text-slate-400 uppercase tracking-widest mb-1.5">Full Name</label>
                    <div className="relative">
                      <span className="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-400">
                        <User size={15} />
                      </span>
                      <input
                        type="text"
                        className="w-full pl-10 pr-4 py-3 bg-[#080d1a]/80 border border-slate-700 hover:border-slate-600 text-white placeholder-slate-400 rounded-xl focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/10 outline-none transition-all duration-300 text-sm font-medium"
                        placeholder="John Doe"
                        value={formData.name}
                        onChange={e => setFormData({ ...formData, name: e.target.value })}
                        required
                      />
                    </div>
                  </div>

                  {/* Phone Input */}
                  <div className="relative">
                    <label className="block text-[10px] font-semibold text-slate-400 uppercase tracking-widest mb-1.5">Phone Number</label>
                    <div className="relative">
                      <span className="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-400">
                        <Phone size={15} />
                      </span>
                      <input
                        type="tel"
                        className="w-full pl-10 pr-4 py-3 bg-[#080d1a]/80 border border-slate-700 hover:border-slate-600 text-white placeholder-slate-400 rounded-xl focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/10 outline-none transition-all duration-300 text-sm font-medium"
                        placeholder="+91 XXXXX XXXXX"
                        value={formData.phone}
                        onChange={e => setFormData({ ...formData, phone: e.target.value })}
                        required
                      />
                    </div>
                  </div>

                  {/* Email Input */}
                  <div className="relative">
                    <label className="block text-[10px] font-semibold text-slate-400 uppercase tracking-widest mb-1.5">Email Address</label>
                    <div className="relative">
                      <span className="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-400">
                        <Mail size={15} />
                      </span>
                      <input
                        type="email"
                        className="w-full pl-10 pr-4 py-3 bg-[#080d1a]/80 border border-slate-700 hover:border-slate-600 text-white placeholder-slate-400 rounded-xl focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/10 outline-none transition-all duration-300 text-sm font-medium"
                        placeholder="your-google-email@gmail.com"
                        value={formData.email}
                        onChange={e => setFormData({ ...formData, email: e.target.value })}
                        required
                      />
                    </div>
                  </div>

                  {/* Action Button */}
                  <button
                    type="submit"
                    disabled={submitting}
                    className="w-full py-3.5 bg-gradient-to-r from-indigo-500 via-purple-500 to-pink-500 hover:from-indigo-600 hover:via-purple-600 hover:to-pink-600 text-white rounded-xl text-sm font-bold transition-all duration-300 transform hover:scale-[1.01] active:scale-[0.99] disabled:opacity-50 disabled:cursor-not-allowed shadow-lg shadow-indigo-500/25 tracking-wide uppercase text-xs"
                  >
                    {submitting ? 'Requesting Provisioning...' : 'Request Console Access'}
                  </button>
                </form>
              </div>

            </div>
          </div>

        </div>
      </section>

      {/* Feature Highlights Grid */}
      <section id="features" className="relative z-10 py-24 bg-black/30 border-y border-white/5">
        <div className="max-w-6xl mx-auto px-4 sm:px-6">
          <div className="text-center max-w-2xl mx-auto mb-16 space-y-3 animate-fade-in-up">
            <h2 className="text-3xl font-extrabold text-white font-['Space_Grotesk']">
              Why use Neo Files?
            </h2>
            <p className="text-sm text-gray-400">
              A comprehensive toolset engineered to simplify storage management and enhance sharing control.
            </p>
          </div>

          <div className="grid md:grid-cols-3 gap-8">
            {/* Card 1 */}
            <div className="relative bg-slate-950/40 backdrop-blur-xl border border-slate-900 p-8 rounded-2xl space-y-4 hover:border-indigo-500/30 hover:bg-slate-900/40 transition-all duration-300 group hover:-translate-y-1 overflow-hidden animate-fade-in-up animation-delay-100">
              <div className="absolute top-0 left-0 w-full h-[2px] bg-gradient-to-r from-indigo-500 to-cyan-500 opacity-0 group-hover:opacity-100 transition-opacity duration-300" />
              <div className="w-12 h-12 bg-indigo-500/10 border border-indigo-500/20 rounded-xl flex items-center justify-center group-hover:scale-110 transition-transform duration-300">
                <HardDrive size={24} className="text-indigo-400" />
              </div>
              <h3 className="font-semibold text-lg text-white font-['Space_Grotesk']">Google Drive Backed</h3>
              <p className="text-gray-400 text-sm leading-relaxed">
                Connect your Drive folder to serve as the backend storage. Benefit from Google's reliable infrastructure with no file limit constraints.
              </p>
            </div>

            {/* Card 2 */}
            <div className="relative bg-slate-950/40 backdrop-blur-xl border border-slate-900 p-8 rounded-2xl space-y-4 hover:border-purple-500/30 hover:bg-slate-900/40 transition-all duration-300 group hover:-translate-y-1 overflow-hidden animate-fade-in-up animation-delay-200">
              <div className="absolute top-0 left-0 w-full h-[2px] bg-gradient-to-r from-purple-500 to-pink-500 opacity-0 group-hover:opacity-100 transition-opacity duration-300" />
              <div className="w-12 h-12 bg-purple-600/10 border border-purple-500/20 rounded-xl flex items-center justify-center group-hover:scale-110 transition-transform duration-300">
                <Share2 size={24} className="text-purple-400" />
              </div>
              <h3 className="font-semibold text-lg text-white font-['Space_Grotesk']">Proxy Share Links</h3>
              <p className="text-gray-400 text-sm leading-relaxed">
                Keep primary download links hidden behind our proxy server. Manage access controls and revoke download permissions at any time.
              </p>
            </div>

            {/* Card 3 */}
            <div className="relative bg-slate-950/40 backdrop-blur-xl border border-slate-900 p-8 rounded-2xl space-y-4 hover:border-cyan-500/30 hover:bg-slate-900/40 transition-all duration-300 group hover:-translate-y-1 overflow-hidden animate-fade-in-up animation-delay-300">
              <div className="absolute top-0 left-0 w-full h-[2px] bg-gradient-to-r from-cyan-500 to-indigo-500 opacity-0 group-hover:opacity-100 transition-opacity duration-300" />
              <div className="w-12 h-12 bg-cyan-500/10 border border-cyan-500/20 rounded-xl flex items-center justify-center group-hover:scale-110 transition-transform duration-300">
                <Layers size={24} className="text-cyan-400" />
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
        <div className="bg-gradient-to-tr from-indigo-500/10 via-purple-500/5 to-transparent border border-slate-800 rounded-3xl p-8 sm:p-12 relative overflow-hidden flex flex-col lg:flex-row items-center gap-8 justify-between animate-fade-in-up animation-delay-500">
          <div className="absolute top-0 right-0 w-[400px] h-[400px] bg-indigo-500/10 rounded-full blur-[100px] pointer-events-none animate-pulse-glow" />
          
          <div className="space-y-6 max-w-xl text-center lg:text-left">
            <div className="inline-flex items-center gap-2 px-3 py-1 bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 rounded-full text-xs font-semibold uppercase tracking-wider">
              <Shield size={12} className="animate-pulse" />
              Enterprise Grade
            </div>
            <h3 className="text-3xl sm:text-4xl font-bold text-white font-['Space_Grotesk'] leading-tight">
              Privacy and Security <br />
              <span className="bg-clip-text text-transparent bg-gradient-to-r from-emerald-400 to-cyan-400">
                Without Compromise
              </span>
            </h3>
            <p className="text-sm sm:text-base text-slate-400 leading-relaxed font-normal">
              We leverage Row Level Security (RLS) on database calls combined with short-lived JWT signatures. 
              Only verified approved users can trigger storage functions, ensuring absolute compliance with cloud security standards.
            </p>
            
            <div className="flex flex-wrap justify-center lg:justify-start gap-6 pt-2">
              <div className="flex items-center gap-2 text-xs text-slate-300">
                <CheckCircle2 size={14} className="text-emerald-400" />
                <span>Row Level Security (RLS)</span>
              </div>
              <div className="flex items-center gap-2 text-xs text-slate-300">
                <CheckCircle2 size={14} className="text-emerald-400" />
                <span>Short-lived JWT Tokens</span>
              </div>
              <div className="flex items-center gap-2 text-xs text-slate-300">
                <CheckCircle2 size={14} className="text-emerald-400" />
                <span>Google API Isolation</span>
              </div>
            </div>
          </div>

          <div className="flex-shrink-0 z-10 w-full lg:w-auto flex justify-center">
            <Link 
              to="/login"
              className="px-8 py-4 bg-white text-slate-950 hover:bg-slate-100 rounded-xl text-sm font-bold transition-all duration-200 shadow-xl shadow-white/5 hover:shadow-indigo-500/10 inline-flex items-center gap-2 transform hover:scale-[1.03] active:scale-95 duration-200 w-full sm:w-auto justify-center"
            >
              Sign In To Console
              <ArrowRight size={16} />
            </Link>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer id="footer" className="relative z-10 border-t border-white/5 py-12 bg-black/40">
        <div className="max-w-6xl mx-auto px-4 sm:px-6">
          <div className="flex flex-col sm:flex-row items-center justify-between gap-6">
            <div className="flex flex-col items-center sm:items-start gap-2">
              <div className="flex items-center gap-2">
                <div className="w-8 h-8 bg-white/5 rounded-lg flex items-center justify-center">
                  <span className="text-white font-bold text-xs">NF</span>
                </div>
                <span className="text-xs text-gray-500">Neo Files Transfer v1.0 • Built with Supabase & Google Drive</span>
              </div>
              <span className="text-[11px] text-gray-600 font-medium sm:pl-10">
                Support & Developer: <a href="mailto:rupambairagya08@gmail.com" className="text-indigo-400 hover:text-indigo-300 hover:underline font-mono">rupambairagya08@gmail.com</a>
              </span>
            </div>
            <div className="flex gap-6 text-xs text-gray-500">
              <Link to="/privacy" className="hover:text-gray-300">Privacy Policy</Link>
              <Link to="/terms" className="hover:text-gray-300">Terms of Service</Link>
            </div>
          </div>
        </div>
      </footer>
    </div>
  )
}
