import { useState } from 'react'
import { Link } from 'react-router-dom'
import { supabase } from '../services/supabase'
import toast from 'react-hot-toast'
import { 
  Cloud, Shield, Link2, ArrowRight, AlertTriangle, 
  LogIn, UserCheck, HardDrive, Share2, Layers, CheckCircle2,
  User, Phone, Mail, FileText, Activity, Database, Copy, Plus, Folder
} from 'lucide-react'

const COUNTRIES = [
  { code: '+91', name: 'India', length: 10, flag: '🇮🇳', placeholder: '98765 43210' },
  { code: '+1', name: 'USA / Canada', length: 10, flag: '🇺🇸', placeholder: '201 555 0123' },
  { code: '+44', name: 'United Kingdom', length: 10, flag: '🇬🇧', placeholder: '7911 123456' },
  { code: '+61', name: 'Australia', length: 9, flag: '🇦🇺', placeholder: '412 345 678' },
  { code: '+880', name: 'Bangladesh', length: 10, flag: '🇧🇩', placeholder: '1712 345678' },
  { code: '+92', name: 'Pakistan', length: 10, flag: '🇵🇰', placeholder: '300 1234567' },
  { code: '+977', name: 'Nepal', length: 10, flag: '🇳🇵', placeholder: '985 1012345' },
  { code: '+65', name: 'Singapore', length: 8, flag: '🇸🇬', placeholder: '8123 4567' },
  { code: '+971', name: 'UAE', length: 9, flag: '🇦🇪', placeholder: '50 123 4567' },
  { code: '+966', name: 'Saudi Arabia', length: 9, flag: '🇸🇦', placeholder: '50 123 4567' },
  { code: '+60', name: 'Malaysia', length: 9, flag: '🇲🇾', placeholder: '12 345 6789' },
]

export default function LandingPage() {
  const [formData, setFormData] = useState({ name: '', email: '' })
  const [selectedCountry, setSelectedCountry] = useState(COUNTRIES[0])
  const [customCode, setCustomCode] = useState('')
  const [localPhone, setLocalPhone] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [step, setStep] = useState('form') // 'form' or 'otp'
  const [otp, setOtp] = useState('')
  const [verifying, setVerifying] = useState(false)
  const [resending, setResending] = useState(false)
  const [blockMessage, setBlockMessage] = useState('')

  // Compute final full phone number
  const finalPhone = selectedCountry.code === 'other'
    ? `${customCode}${localPhone}`
    : `${selectedCountry.code}${localPhone}`

  function handleCountryChange(e) {
    const code = e.target.value
    if (code === 'other') {
      setSelectedCountry({ code: 'other', name: 'Other', length: 15, flag: '🌐', placeholder: 'Enter number with custom code' })
      setCustomCode('+')
    } else {
      const match = COUNTRIES.find(c => c.code === code)
      if (match) {
        setSelectedCountry(match)
      }
    }
    setLocalPhone('')
  }

  function handlePhoneChange(e) {
    const val = e.target.value.replace(/[^0-9]/g, '')
    const maxLength = selectedCountry.length
    if (val.length <= maxLength) {
      setLocalPhone(val)
    }
  }

  async function handleSubmit(e) {
    e.preventDefault()
    if (!formData.name || !localPhone || !formData.email) {
      toast.error('All fields are required')
      return
    }

    // Validate phone number length based on selected country
    if (selectedCountry.code !== 'other') {
      if (localPhone.length !== selectedCountry.length) {
        toast.error(`Please enter a valid ${selectedCountry.length}-digit phone number for ${selectedCountry.name}.`)
        return
      }
    } else {
      if (!customCode.startsWith('+') || customCode.length < 2) {
        toast.error('Please enter a valid custom country code starting with + (e.g. +33).')
        return
      }
      if (localPhone.length < 7 || localPhone.length > 15) {
        toast.error('Please enter a valid phone number (between 7 and 15 digits).')
        return
      }
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    if (!emailRegex.test(formData.email)) {
      toast.error('Please enter a valid email address')
      return
    }

    setSubmitting(true)
    setBlockMessage('')
    try {


      const response = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/mail-service/send-otp`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            ...formData,
            phone: finalPhone
          })
        }
      )

      const result = await response.json()
      if (!response.ok) {
        if (response.status === 429) {
          setBlockMessage(result.error)
        }
        throw new Error(result.error || 'Failed to send verification code')
      }

      toast.success('Verification code sent to your email!')
      setStep('otp')
    } catch (err) {
      console.error(err)
      toast.error(err.message || 'Registration failed. Please try again.')
    } finally {
      setSubmitting(false)
    }
  }

  async function handleVerifyOtp(e) {
    e.preventDefault()
    if (!otp || otp.length !== 6) {
      toast.error('Please enter a valid 6-digit code')
      return
    }

    setVerifying(true)
    try {
      const response = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/mail-service/verify-otp`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            ...formData,
            phone: finalPhone,
            otp: otp
          })
        }
      )

      const result = await response.json()
      if (!response.ok) {
        throw new Error(result.error || 'Verification failed')
      }

      toast.success('Email verified and request submitted successfully!')
      setFormData({ name: '', email: '' })
      setLocalPhone('')
      setCustomCode('')
      setSelectedCountry(COUNTRIES[0])
      setOtp('')
      setStep('form')
    } catch (err) {
      console.error(err)
      toast.error(err.message || 'OTP verification failed')
    } finally {
      setVerifying(false)
    }
  }

  async function handleResendOtp() {
    setResending(true)
    setBlockMessage('')
    try {
      const response = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/mail-service/send-otp`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            ...formData,
            phone: finalPhone
          })
        }
      )

      const result = await response.json()
      if (!response.ok) {
        if (response.status === 429) {
          setBlockMessage(result.error)
        }
        throw new Error(result.error || 'Failed to resend verification code')
      }

      toast.success('New verification code sent!')
      setOtp('')
    } catch (err) {
      console.error(err)
      toast.error(err.message || 'Failed to resend OTP')
    } finally {
      setResending(false)
    }
  }

  return (
    <div className="min-h-screen w-full bg-[#030712] text-gray-100 font-['Plus_Jakarta_Sans'] relative overflow-hidden selection:bg-indigo-500/30 selection:text-white">
      {/* Import Premium Fonts */}
      <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Space+Grotesk:wght@500;600;700&display=swap" rel="stylesheet" />

      {/* Futuristic Background Mesh Gradients & Grid */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none z-0">
        <div className="absolute top-[-10%] left-[-10%] w-[50%] h-[50%] rounded-full bg-indigo-500/10 blur-[130px] md:animate-float opacity-80" />
        <div className="absolute bottom-0 right-0 translate-x-1/4 w-[50%] h-[400px] rounded-full bg-purple-600/10 blur-[150px] md:animate-float-delayed opacity-75" />
        <div className="absolute top-[30%] left-[40%] w-[300px] h-[300px] rounded-full bg-cyan-500/5 blur-[100px] md:animate-float opacity-50" />
        <div className="absolute inset-0 bg-[linear-gradient(to_right,#ffffff02_1px,transparent_1px),linear-gradient(to_bottom,#ffffff02_1px,transparent_1px)] bg-[size:30px_30px]" />
      </div>

      {/* Header */}
      <header className="fixed top-0 left-0 right-0 z-50 border-b border-white/10 bg-[#030712]/70 backdrop-blur-md shadow-lg shadow-black/20">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 h-16 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <img 
              src="/favicon.png" 
              alt="Neo Files Logo" 
              className="w-10 h-10 object-contain hover:rotate-6 transition-transform duration-300"
            />
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
      <section className="relative z-10 max-w-6xl mx-auto px-4 sm:px-6 pt-28 pb-24 lg:pt-36 lg:pb-32 w-full">
        <div className="grid lg:grid-cols-12 gap-16 lg:gap-8 items-center">
          
          {/* Left Side: Headline & Copy */}
          <div className="lg:col-span-6 space-y-8 text-center lg:text-left">
            <div className="inline-flex items-center gap-2 px-3 py-1 bg-indigo-500/10 border border-indigo-500/20 text-indigo-400 rounded-full text-xs font-semibold uppercase tracking-wider animate-fade-in-up">
              <span className="w-1.5 h-1.5 rounded-full bg-indigo-400 animate-ping" />
              Live Proxy Storage
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
              <div className="relative bg-slate-950/85 backdrop-blur-3xl border border-slate-800 shadow-2xl p-6 sm:p-8 rounded-2xl space-y-6 z-10 w-full">
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

                {step === 'form' ? (
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
                      <div className="relative flex bg-[#080d1a]/80 border border-slate-700 hover:border-slate-600 rounded-xl focus-within:border-indigo-500 focus-within:ring-2 focus-within:ring-indigo-500/10 transition-all duration-300 overflow-hidden">
                        {/* Country Selector Dropdown */}
                        <div className="flex items-center border-r border-slate-700 bg-[#0c1222] px-3 pr-2">
                          <span className="mr-1 text-sm">{selectedCountry.flag}</span>
                          <select
                            value={selectedCountry.code === 'other' ? 'other' : selectedCountry.code}
                            onChange={handleCountryChange}
                            className="bg-transparent text-white text-xs font-semibold focus:outline-none cursor-pointer pr-1 py-3"
                          >
                            {COUNTRIES.map((c) => (
                              <option key={c.code} value={c.code} className="bg-[#0b1329] text-white">
                                {c.code} ({c.name})
                              </option>
                            ))}
                            <option value="other" className="bg-[#0b1329] text-white">Other (+)</option>
                          </select>
                        </div>
                        
                        {/* Custom Code Input if Other is selected */}
                        {selectedCountry.code === 'other' && (
                          <input
                            type="text"
                            placeholder="+XX"
                            value={customCode}
                            onChange={e => setCustomCode(e.target.value.replace(/[^0-9+]/g, ''))}
                            className="w-16 px-2 bg-transparent text-white border-r border-slate-700 text-xs font-semibold focus:outline-none text-center"
                            required
                          />
                        )}

                        <input
                          type="tel"
                          className="flex-1 w-full min-w-0 bg-transparent px-4 py-3 text-white placeholder-slate-500 outline-none text-sm font-medium"
                          placeholder={selectedCountry.placeholder}
                          value={localPhone}
                          onChange={handlePhoneChange}
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
                      className="w-full py-3.5 bg-indigo-600 hover:bg-pink-600 text-white rounded-xl text-sm font-bold transition-colors duration-300 transform hover:scale-[1.01] active:scale-[0.99] disabled:opacity-50 disabled:cursor-not-allowed shadow-lg shadow-indigo-600/25 tracking-wide uppercase text-xs"
                    >
                      {submitting ? 'Requesting Provisioning...' : 'Request Console Access'}
                    </button>
                  </form>
                ) : (
                  <form onSubmit={handleVerifyOtp} className="space-y-5">
                    {/* OTP Warning / Spam Check banner */}
                    <div className="bg-indigo-500/10 border border-indigo-500/20 rounded-xl p-3.5 flex items-start gap-2.5">
                      <Mail size={16} className="text-indigo-400 mt-0.5 flex-shrink-0" />
                      <div className="text-xs text-indigo-300 leading-normal text-left">
                        Verification code sent to <strong>{formData.email}</strong>. <br />
                        <span className="text-amber-400 font-semibold">Please check spam folder if not found in inbox.</span>
                      </div>
                    </div>

                    {/* OTP Input */}
                    <div className="relative">
                      <label className="block text-[10px] font-semibold text-slate-400 uppercase tracking-widest mb-1.5 text-left">Verification Code</label>
                      <input
                        type="text"
                        maxLength={6}
                        className="w-full text-center tracking-[0.5em] font-mono text-2xl py-3 bg-[#080d1a]/80 border border-slate-700 hover:border-slate-600 text-white rounded-xl focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/10 outline-none transition-all duration-300 font-bold"
                        placeholder="000000"
                        value={otp}
                        onChange={e => setOtp(e.target.value.replace(/\D/g, ''))}
                        required
                        disabled={!!blockMessage}
                      />
                    </div>

                    {/* Block Message display */}
                    {blockMessage && (
                      <div className="bg-red-500/15 border border-red-500/20 text-red-400 rounded-xl p-3.5 text-xs text-center leading-normal">
                        {blockMessage}
                      </div>
                    )}

                    {/* Action Buttons */}
                    <div className="space-y-3">
                      <button
                        type="submit"
                        disabled={verifying || !!blockMessage}
                        className="w-full py-3.5 bg-indigo-600 hover:bg-pink-600 text-white rounded-xl text-sm font-bold transition-colors duration-300 transform hover:scale-[1.01] active:scale-[0.99] disabled:opacity-50 disabled:cursor-not-allowed shadow-lg shadow-indigo-600/25 tracking-wide uppercase text-xs"
                      >
                        {verifying ? 'Verifying Code...' : 'Verify Email & Submit'}
                      </button>

                      <div className="flex justify-between items-center px-1 text-xs">
                        <button
                          type="button"
                          onClick={() => {
                            setStep('form')
                            setBlockMessage('')
                            setOtp('')
                          }}
                          className="text-slate-400 hover:text-white transition-colors"
                        >
                          Change Details
                        </button>

                        <button
                          type="button"
                          onClick={handleResendOtp}
                          disabled={resending || !!blockMessage}
                          className="text-indigo-400 hover:text-indigo-300 transition-colors font-medium disabled:opacity-40"
                        >
                          {resending ? 'Resending...' : 'Resend OTP'}
                        </button>
                      </div>
                    </div>
                  </form>
                )}
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

          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
            {/* Card 1 */}
            <div className="relative bg-slate-950/40 backdrop-blur-xl border border-slate-900 p-8 rounded-2xl space-y-4 hover:border-indigo-500/30 hover:bg-slate-900/40 transition-all duration-300 group hover:-translate-y-1 overflow-hidden animate-fade-in-up animation-delay-100">
              <div className="absolute top-0 left-0 w-full h-[2px] bg-gradient-to-r from-indigo-500 to-cyan-500 opacity-0 group-hover:opacity-100 transition-opacity duration-300" />
              <div className="w-12 h-12 bg-indigo-500/10 border border-indigo-500/20 rounded-xl flex items-center justify-center group-hover:scale-110 transition-transform duration-300">
                <HardDrive size={24} className="text-indigo-400" />
              </div>
              <h3 className="font-semibold text-lg text-white font-['Space_Grotesk']">Google Drive Storage</h3>
              <p className="text-gray-400 text-sm leading-relaxed">
                Connect your Drive folder to serve as the backend storage. Benefit from Google's reliable infrastructure with no file limit constraints.
              </p>
            </div>

            {/* Card 2 */}
            <div className="relative bg-slate-950/40 backdrop-blur-xl border border-slate-900 p-8 rounded-2xl space-y-4 hover:border-purple-500/30 hover:bg-slate-900/40 transition-all duration-300 group hover:-translate-y-1 overflow-hidden animate-fade-in-up animation-delay-200">
              <div className="absolute top-0 left-0 w-full h-[2px] bg-gradient-to-r from-purple-500 to-pink-500 opacity-0 group-hover:opacity-100 transition-opacity duration-300" />
              <div className="w-12 h-12 bg-purple-600/10 border border-purple-500/20 rounded-xl flex items-center justify-center group-hover:scale-110 transition-transform duration-300">
                <Folder size={24} className="text-purple-400" />
              </div>
              <h3 className="font-semibold text-lg text-white font-['Space_Grotesk']">Folder ZIP Generation</h3>
              <p className="text-gray-400 text-sm leading-relaxed">
                Create and upload nested directories recursively. Download full folders on-the-fly dynamically compressed as standard ZIP archives.
              </p>
            </div>

            {/* Card 3 */}
            <div className="relative bg-slate-950/40 backdrop-blur-xl border border-slate-900 p-8 rounded-2xl space-y-4 hover:border-cyan-500/30 hover:bg-slate-900/40 transition-all duration-300 group hover:-translate-y-1 overflow-hidden animate-fade-in-up animation-delay-300">
              <div className="absolute top-0 left-0 w-full h-[2px] bg-gradient-to-r from-cyan-500 to-indigo-500 opacity-0 group-hover:opacity-100 transition-opacity duration-300" />
              <div className="w-12 h-12 bg-cyan-500/10 border border-cyan-500/20 rounded-xl flex items-center justify-center group-hover:scale-110 transition-transform duration-300">
                <Link2 size={24} className="text-cyan-400" />
              </div>
              <h3 className="font-semibold text-lg text-white font-['Space_Grotesk']">Dual-Link Sharing</h3>
              <p className="text-gray-400 text-sm leading-relaxed">
                Distribute links as either a premium Web Download Page (with real-time progress indicators) or a Direct API stream link for background downloading.
              </p>
            </div>

            {/* Card 4 */}
            <div className="relative bg-slate-950/40 backdrop-blur-xl border border-slate-900 p-8 rounded-2xl space-y-4 hover:border-emerald-500/30 hover:bg-slate-900/40 transition-all duration-300 group hover:-translate-y-1 overflow-hidden animate-fade-in-up animation-delay-100">
              <div className="absolute top-0 left-0 w-full h-[2px] bg-gradient-to-r from-emerald-500 to-indigo-500 opacity-0 group-hover:opacity-100 transition-opacity duration-300" />
              <div className="w-12 h-12 bg-emerald-500/10 border border-emerald-500/20 rounded-xl flex items-center justify-center group-hover:scale-110 transition-transform duration-300">
                <Layers size={24} className="text-emerald-400" />
              </div>
              <h3 className="font-semibold text-lg text-white font-['Space_Grotesk']">Version Automation</h3>
              <p className="text-gray-400 text-sm leading-relaxed">
                Update files easily without breaking existing shares. The platform purges old files from Google Drive automatically to prevent disk storage bloat.
              </p>
            </div>

            {/* Card 5 */}
            <div className="relative bg-slate-950/40 backdrop-blur-xl border border-slate-900 p-8 rounded-2xl space-y-4 hover:border-pink-500/30 hover:bg-slate-900/40 transition-all duration-300 group hover:-translate-y-1 overflow-hidden animate-fade-in-up animation-delay-200">
              <div className="absolute top-0 left-0 w-full h-[2px] bg-gradient-to-r from-pink-500 to-purple-500 opacity-0 group-hover:opacity-100 transition-opacity duration-300" />
              <div className="w-12 h-12 bg-pink-500/10 border border-pink-500/20 rounded-xl flex items-center justify-center group-hover:scale-110 transition-transform duration-300">
                <Shield size={24} className="text-pink-400" />
              </div>
              <h3 className="font-semibold text-lg text-white font-['Space_Grotesk']">Real-time Permissions</h3>
              <p className="text-gray-400 text-sm leading-relaxed">
                Administrators can approve registrations, monitor audit logs, toggle download states, and suspend accounts instantly in real-time.
              </p>
            </div>

            {/* Card 6 */}
            <div className="relative bg-slate-950/40 backdrop-blur-xl border border-slate-900 p-8 rounded-2xl space-y-4 hover:border-amber-500/30 hover:bg-slate-900/40 transition-all duration-300 group hover:-translate-y-1 overflow-hidden animate-fade-in-up animation-delay-300">
              <div className="absolute top-0 left-0 w-full h-[2px] bg-gradient-to-r from-amber-500 to-pink-500 opacity-0 group-hover:opacity-100 transition-opacity duration-300" />
              <div className="w-12 h-12 bg-amber-500/10 border border-amber-500/20 rounded-xl flex items-center justify-center group-hover:scale-110 transition-transform duration-300">
                <Activity size={24} className="text-amber-400" />
              </div>
              <h3 className="font-semibold text-lg text-white font-['Space_Grotesk']">High-Speed Streaming</h3>
              <p className="text-gray-400 text-sm leading-relaxed">
                Secure streaming directly from regional Edge servers bypasses Google warning screens and account pickers to saturate the user's connection.
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
                <img 
                  src="/favicon.png" 
                  alt="Neo Files Logo" 
                  className="w-8 h-8 object-contain"
                />
                <span className="text-xs text-gray-500">Neo Files Transfer • Built with Supabase & Google Drive</span>
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
