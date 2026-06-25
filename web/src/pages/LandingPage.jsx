import { useState } from 'react'
import { Link } from 'react-router-dom'
import { supabase } from '../services/supabase'
import toast from 'react-hot-toast'
import { generateDirectDownloadUrl } from '../utils/helpers'
import { 
  Cloud, Shield, Link2, ArrowRight, AlertTriangle, 
  LogIn, UserCheck, HardDrive, Share2, Layers, CheckCircle2,
  User, Phone, Mail, FileText, Activity, Database, Copy, Plus, Folder,
  Smartphone, Zap, Lock, Globe, Star, TrendingUp
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

      {/* Background Mesh */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none z-0">
        <div className="absolute top-[-15%] left-[-10%] w-[55%] h-[55%] rounded-full bg-indigo-600/8 blur-[140px] animate-float opacity-90" />
        <div className="absolute bottom-[-5%] right-[-5%] w-[50%] h-[500px] rounded-full bg-purple-700/8 blur-[160px] animate-float-delayed opacity-80" />
        <div className="absolute top-[40%] left-[35%] w-[350px] h-[350px] rounded-full bg-cyan-500/4 blur-[110px] animate-float opacity-50" />
        <div className="absolute top-[20%] right-[15%] w-[200px] h-[200px] rounded-full bg-pink-500/5 blur-[80px]" />
        {/* Grid */}
        <div className="absolute inset-0 bg-[linear-gradient(to_right,#ffffff02_1px,transparent_1px),linear-gradient(to_bottom,#ffffff02_1px,transparent_1px)] bg-[size:32px_32px]" />
        {/* Radial vignette */}
        <div className="absolute inset-0 bg-[radial-gradient(ellipse_80%_60%_at_50%_0%,transparent_60%,#030712_100%)]" />
      </div>

      {/* ─── HEADER ──────────────────────────────────────── */}
      <header className="fixed top-0 left-0 right-0 z-50 border-b border-white/[0.06] bg-[#030712]/75 backdrop-blur-xl shadow-2xl shadow-black/30">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 h-16 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="relative">
              <img src="/favicon.png" alt="Neo Files Logo" className="w-9 h-9 object-contain hover:rotate-12 transition-transform duration-500" />
              <div className="absolute -inset-1 bg-indigo-500/20 rounded-full blur-md opacity-0 hover:opacity-100 transition-opacity duration-300" />
            </div>
            <span className="font-bold text-xl tracking-tight text-white font-['Space_Grotesk']">
              Neo<span className="text-indigo-400">Files</span>
            </span>
          </div>

          <nav className="hidden md:flex items-center gap-8 text-sm font-medium text-gray-400">
            {['#features', '#how-it-works', '#security'].map((href, i) => {
              const labels = ['Features', 'How It Works', 'Security']
              return (
                <a key={href} href={href} className="hover:text-white transition-colors duration-200 relative group">
                  {labels[i]}
                  <span className="absolute -bottom-1 left-0 w-0 h-[1.5px] bg-gradient-to-r from-indigo-400 to-purple-400 group-hover:w-full transition-all duration-300 rounded-full" />
                </a>
              )
            })}
            <Link to="/privacy" className="hover:text-white transition-colors duration-200 relative group">
              Privacy
              <span className="absolute -bottom-1 left-0 w-0 h-[1.5px] bg-gradient-to-r from-indigo-400 to-purple-400 group-hover:w-full transition-all duration-300 rounded-full" />
            </Link>
          </nav>

          <div className="flex items-center gap-3">
            <Link
              to="/login"
              className="px-4 py-2 bg-white/5 hover:bg-white/10 text-white border border-white/10 hover:border-white/20 rounded-xl text-sm font-semibold transition-all duration-200 flex items-center gap-2"
            >
              <LogIn size={14} />
              Sign In
            </Link>
          </div>

        </div>
      </header>

      {/* ─── HERO SECTION ────────────────────────────────── */}
      <section className="relative z-10 max-w-6xl mx-auto px-4 sm:px-6 pt-28 pb-20 lg:pt-36 lg:pb-28 w-full">
        <div className="grid lg:grid-cols-12 gap-12 lg:gap-8 items-start">

          {/* Left: Content */}
          <div className="lg:col-span-6 space-y-8 text-center lg:text-left">

            {/* Badge */}
            <div className="inline-flex items-center gap-2 px-3 py-1.5 bg-gradient-to-r from-indigo-500/10 to-purple-500/10 border border-indigo-500/25 text-indigo-300 rounded-full text-[10px] sm:text-xs font-semibold uppercase tracking-wider sm:tracking-widest animate-fade-in-up max-w-full">
              <span className="relative flex h-2 w-2">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-indigo-400 opacity-75" />
                <span className="relative inline-flex rounded-full h-2 w-2 bg-indigo-400" />
              </span>
              Developer File Distribution
            </div>

            {/* Headline */}
            <div className="animate-fade-in-up animation-delay-100">
              <h1 className="text-4xl sm:text-5xl lg:text-[3.4rem] font-extrabold text-white tracking-tight leading-[1.08] font-['Space_Grotesk']">
                Host software builds on{' '}
                <span className="bg-clip-text text-transparent bg-gradient-to-r from-indigo-400 via-purple-400 to-pink-400">
                  Google Drive.
                </span>
                <br />
                Without the speed limits.
              </h1>
              <p className="mt-5 text-base sm:text-lg text-slate-400 max-w-lg mx-auto lg:mx-0 leading-relaxed">
                Google Drive is great, but sharing raw links is a pain. Users get virus warnings, throttled speeds, and annoying login screens. <span className="text-white font-medium">NeoFiles</span> turns your Drive folders into clean, direct download pages. Perfect for APKs, software builds, and assets.
              </p>
            </div>



            {/* Android Download Button */}
            <div className="animate-fade-in-up animation-delay-300 max-w-lg mx-auto lg:mx-0">
              <a
                href="https://neo-files-download.rupambairagya08.workers.dev?hash=137c0037e239"
                target="_blank"
                rel="noopener noreferrer"
                className="relative flex items-center justify-between gap-4 w-full px-5 py-4 bg-gradient-to-r from-emerald-600 to-teal-600 text-white rounded-2xl font-semibold overflow-hidden"
              >
                {/* Pulse rings */}
                <span className="absolute -left-2 -top-2 w-14 h-14 rounded-full bg-emerald-400/20 animate-ping" />
                <span className="absolute -left-1 -top-1 w-10 h-10 rounded-full bg-emerald-400/10" />
                {/* Shield shine sweep */}
                <span className="animate-btn-shine absolute top-0 left-0 w-16 h-full bg-gradient-to-r from-transparent via-white/25 to-transparent pointer-events-none z-20" />

                <div className="flex items-center gap-3 relative z-10">
                  {/* Android Head — Line/Outline Style */}
                  <div className="w-12 h-12 bg-white/10 border border-white/15 rounded-xl flex items-center justify-center flex-shrink-0">
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#3DDC84" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" className="w-8 h-8">
                      {/* Antennas */}
                      <line x1="8.5" y1="4.5" x2="6" y2="2" />
                      <line x1="15.5" y1="4.5" x2="18" y2="2" />
                      {/* Head dome */}
                      <path d="M5 11a7 7 0 0 1 14 0v4a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2z" />
                      {/* Eyes */}
                      <circle cx="9.5" cy="11" r="0.8" fill="#3DDC84" stroke="none" />
                      <circle cx="14.5" cy="11" r="0.8" fill="#3DDC84" stroke="none" />
                    </svg>
                  </div>
                  <div className="text-left">
                    <p className="text-[10px] text-emerald-200 font-medium uppercase tracking-widest leading-none mb-0.5">Download for</p>
                    <p className="text-base font-bold font-['Space_Grotesk'] leading-none">Android App</p>
                  </div>
                </div>

                <div className="relative z-10 flex items-center gap-2">
                  <span className="px-2.5 py-1 bg-white/15 border border-white/20 rounded-lg text-[10px] font-bold text-emerald-100 uppercase tracking-wider">Free Download</span>
                  <ArrowRight size={16} className="text-emerald-200" />
                </div>
              </a>
            </div>

            {/* Stats row */}
            <div className="flex flex-wrap gap-4 sm:gap-6 justify-center lg:justify-start animate-fade-in-up animation-delay-300 pt-1">
              {[
                { val: 'No Limits', label: 'Your Own Drive Storage', color: 'text-emerald-400' },
                { val: 'Direct Stream', label: 'Bypass Warning Screens', color: 'text-indigo-400' },
                { val: 'Instant', label: 'Access Approvals', color: 'text-purple-400' },
              ].map((s, i) => (
                <div key={i} className="text-center lg:text-left">
                  <p className={`text-lg font-black font-['Space_Grotesk'] ${s.color}`}>{s.val}</p>
                  <p className="text-[10px] text-slate-500 font-medium leading-tight">{s.label}</p>
                </div>
              ))}
            </div>
          </div>

          {/* Right: Registration Card */}
          <div id="register" className="lg:col-span-6 relative flex justify-center lg:justify-end animate-fade-in-up animation-delay-300">
            <div className="relative w-full max-w-md">

              {/* Glow */}
              <div className="absolute -inset-4 bg-gradient-to-tr from-indigo-500/15 via-purple-500/10 to-pink-500/5 rounded-3xl filter blur-2xl opacity-90 pointer-events-none" />

              {/* Card */}
              <div className="relative bg-slate-950/90 backdrop-blur-3xl border border-slate-800/80 shadow-2xl shadow-black/50 p-6 sm:p-8 rounded-2xl space-y-6 z-10 w-full">

                {/* Card Header */}
                <div className="space-y-1.5">
                  <div className="flex items-center gap-3">
                    <div className="w-9 h-9 bg-indigo-500/15 border border-indigo-500/25 rounded-xl flex items-center justify-center">
                      <UserCheck size={18} className="text-indigo-400" />
                    </div>
                    <div>
                      <h3 className="text-xl font-bold text-white font-['Space_Grotesk']">Get Console Access</h3>
                      <p className="text-[11px] text-gray-500">Sign up below and admin will approve your account</p>
                    </div>
                  </div>
                  {/* Progress steps */}
                  <div className="flex items-center gap-2 pt-2">
                    <div className={`flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[10px] font-bold ${step === 'form' ? 'bg-indigo-500/20 border border-indigo-500/30 text-indigo-300' : 'bg-emerald-500/10 border border-emerald-500/20 text-emerald-400'}`}>
                      {step === 'form' ? '1' : <CheckCircle2 size={10} />} Details
                    </div>
                    <div className="flex-1 h-px bg-slate-800" />
                    <div className={`flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[10px] font-bold ${step === 'otp' ? 'bg-indigo-500/20 border border-indigo-500/30 text-indigo-300' : 'bg-slate-800/80 border border-slate-700/60 text-slate-600'}`}>
                      2 Verify &amp; Submit
                    </div>
                  </div>

                </div>

                {/* Alert */}
                <div className="bg-amber-500/8 border border-amber-500/20 rounded-xl p-3 flex items-start gap-2.5">
                  <AlertTriangle size={14} className="text-amber-400 mt-0.5 flex-shrink-0" />
                  <p className="text-[11px] text-amber-300/90 leading-normal">
                    Note: Please use the same <strong>Google email address</strong> you plan to use for logging in.
                  </p>
                </div>

                {step === 'form' ? (
                  <form onSubmit={handleSubmit} className="space-y-4">
                    {/* Name */}
                    <div>
                      <label className="block text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-1.5">Full Name</label>
                      <div className="relative">
                        <span className="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-500">
                          <User size={14} />
                        </span>
                        <input
                          type="text"
                          className="w-full pl-10 pr-4 py-3 bg-slate-900/60 border border-slate-700/80 hover:border-slate-600 text-white placeholder-slate-600 rounded-xl focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/10 outline-none transition-all duration-300 text-sm font-medium"
                          placeholder="John Doe"
                          value={formData.name}
                          onChange={e => setFormData({ ...formData, name: e.target.value })}
                          required
                        />
                      </div>
                    </div>

                    {/* Phone */}
                    <div>
                      <label className="block text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-1.5">Phone Number</label>
                      <div className="relative flex bg-slate-900/60 border border-slate-700/80 hover:border-slate-600 rounded-xl focus-within:border-indigo-500 focus-within:ring-2 focus-within:ring-indigo-500/10 transition-all duration-300 overflow-hidden">
                        <div className="flex items-center border-r border-slate-700/80 bg-slate-900/80 px-3 pr-2">
                          <span className="mr-1 text-sm">{selectedCountry.flag}</span>
                          <select
                            value={selectedCountry.code === 'other' ? 'other' : selectedCountry.code}
                            onChange={handleCountryChange}
                            className="bg-transparent text-white text-xs font-semibold focus:outline-none cursor-pointer pr-1 py-3"
                          >
                            {COUNTRIES.map((c) => (
                              <option key={c.code} value={c.code} className="bg-slate-900 text-white">
                                {c.code} ({c.name})
                              </option>
                            ))}
                            <option value="other" className="bg-slate-900 text-white">Other (+)</option>
                          </select>
                        </div>
                        {selectedCountry.code === 'other' && (
                          <input
                            type="text"
                            placeholder="+XX"
                            value={customCode}
                            onChange={e => setCustomCode(e.target.value.replace(/[^0-9+]/g, ''))}
                            className="w-16 px-2 bg-transparent text-white border-r border-slate-700/80 text-xs font-semibold focus:outline-none text-center"
                            required
                          />
                        )}
                        <input
                          type="tel"
                          className="flex-1 w-full min-w-0 bg-transparent px-4 py-3 text-white placeholder-slate-600 outline-none text-sm font-medium"
                          placeholder={selectedCountry.placeholder}
                          value={localPhone}
                          onChange={handlePhoneChange}
                          required
                        />
                      </div>
                    </div>

                    {/* Email */}
                    <div>
                      <label className="block text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-1.5">Email Address</label>
                      <div className="relative">
                        <span className="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-500">
                          <Mail size={14} />
                        </span>
                        <input
                          type="email"
                          className="w-full pl-10 pr-4 py-3 bg-slate-900/60 border border-slate-700/80 hover:border-slate-600 text-white placeholder-slate-600 rounded-xl focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/10 outline-none transition-all duration-300 text-sm font-medium"
                          placeholder="your-google-email@gmail.com"
                          value={formData.email}
                          onChange={e => setFormData({ ...formData, email: e.target.value })}
                          required
                        />
                      </div>
                    </div>

                    {/* Submit */}
                    <button
                      type="submit"
                      disabled={submitting}
                      className="w-full py-3.5 bg-gradient-to-r from-indigo-600 to-indigo-500 hover:from-indigo-500 hover:to-purple-600 text-white rounded-xl text-sm font-bold transition-all duration-300 transform hover:scale-[1.01] active:scale-[0.99] disabled:opacity-50 disabled:cursor-not-allowed tracking-wide flex items-center justify-center gap-2"
                    >
                      {submitting ? (
                        <>
                          <svg className="animate-spin h-4 w-4" viewBox="0 0 24 24" fill="none">
                            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"/>
                            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
                          </svg>
                          Sending Verification...
                        </>
                      ) : (
                        <>
                          Request Console Access
                          <ArrowRight size={15} />
                        </>
                      )}
                    </button>
                  </form>
                ) : (
                  <form onSubmit={handleVerifyOtp} className="space-y-5">
                    <div className="bg-indigo-500/8 border border-indigo-500/20 rounded-xl p-3.5 flex items-start gap-2.5">
                      <Mail size={15} className="text-indigo-400 mt-0.5 flex-shrink-0" />
                      <div className="text-xs text-indigo-300 leading-normal">
                        Code sent to <strong>{formData.email}</strong><br />
                        <span className="text-amber-400 font-semibold">Check spam if not in inbox.</span>
                      </div>
                    </div>

                    <div>
                      <label className="block text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-1.5">6-Digit Verification Code</label>
                      <input
                        type="text"
                        maxLength={6}
                        className="w-full text-center tracking-[0.5em] font-mono text-2xl py-3.5 bg-slate-900/60 border border-slate-700/80 hover:border-slate-600 text-white rounded-xl focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/10 outline-none transition-all duration-300 font-bold"
                        placeholder="000000"
                        value={otp}
                        onChange={e => setOtp(e.target.value.replace(/\D/g, ''))}
                        required
                        disabled={!!blockMessage}
                      />
                    </div>

                    {blockMessage && (
                      <div className="bg-red-500/10 border border-red-500/20 text-red-400 rounded-xl p-3.5 text-xs text-center leading-normal">
                        {blockMessage}
                      </div>
                    )}

                    <div className="space-y-3">
                       <button
                        type="submit"
                        disabled={verifying || !!blockMessage}
                        className="w-full py-3.5 bg-gradient-to-r from-indigo-600 to-indigo-500 hover:from-indigo-500 hover:to-purple-600 text-white rounded-xl text-sm font-bold transition-all duration-300 transform hover:scale-[1.01] active:scale-[0.99] disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
                      >
                        {verifying ? (
                          <>
                            <svg className="animate-spin h-4 w-4" viewBox="0 0 24 24" fill="none">
                              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"/>
                              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
                            </svg>
                            Verifying...
                          </>
                        ) : 'Verify Email & Submit'}
                      </button>

                      <div className="flex justify-between items-center px-1 text-xs">
                        <button
                          type="button"
                          onClick={() => { setStep('form'); setBlockMessage(''); setOtp('') }}
                          className="text-slate-500 hover:text-white transition-colors"
                        >
                          ← Change Details
                        </button>
                        <button
                          type="button"
                          onClick={handleResendOtp}
                          disabled={resending || !!blockMessage}
                          className="text-indigo-400 hover:text-indigo-300 transition-colors font-medium disabled:opacity-40"
                        >
                          {resending ? 'Resending...' : 'Resend Code'}
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

      {/* ─── HOW IT WORKS SECTION ────────────────────────── */}
      <section id="how-it-works" className="relative z-10 py-24 border-b border-white/[0.04]">
        <div className="absolute inset-0 bg-gradient-to-b from-black/20 to-transparent pointer-events-none" />
        <div className="relative max-w-6xl mx-auto px-4 sm:px-6">

          {/* Heading */}
          <div className="text-center max-w-2xl mx-auto mb-16 space-y-3 animate-fade-in-up">
            <div className="inline-flex items-center gap-2 px-3 py-1 bg-indigo-500/10 border border-indigo-500/20 text-indigo-400 rounded-full text-xs font-semibold uppercase tracking-widest mb-2">
              <Zap size={11} className="fill-indigo-400" />
              How it works under the hood
            </div>
            <h2 className="text-3xl sm:text-4xl font-extrabold text-white font-['Space_Grotesk'] leading-tight">
              Simple and Straightforward
            </h2>
            <p className="text-sm text-slate-400 max-w-lg mx-auto leading-relaxed">
              Connect your folder, get clean download links, and manage access in one place.
            </p>
          </div>

          {/* Steps */}
          <div className="grid md:grid-cols-3 gap-6 relative">
            {/* Connector line desktop */}
            <div className="hidden md:block absolute top-12 left-[33%] right-[33%] h-px bg-gradient-to-r from-indigo-500/40 via-purple-500/40 to-pink-500/40 z-0" />

            {[
              {
                step: '01',
                icon: <HardDrive size={28} />,
                title: 'Link Google Drive',
                desc: 'Connect any folder from your own Google Drive. You keep full ownership of your data and pay zero extra storage fees.',
                color: 'from-indigo-500 to-cyan-500',
                iconBg: 'bg-indigo-500/10 border-indigo-500/25 text-indigo-400',
                glow: 'hover:border-indigo-500/30',
              },
              {
                step: '02',
                icon: <Link2 size={28} />,
                title: 'Get Clean Share Links',
                desc: 'Generate a beautiful download page with progress bars, or get a direct streaming URL to embed directly in your website\'s buttons.',
                color: 'from-purple-500 to-pink-500',
                iconBg: 'bg-purple-500/10 border-purple-500/25 text-purple-400',
                glow: 'hover:border-purple-500/30',
              },
              {
                step: '03',
                icon: <Zap size={28} />,
                title: 'Bypass Google Warnings',
                desc: 'Files stream directly from regional servers at full speed. No "can\'t scan for viruses" warning screens or Google login popups.',
                color: 'from-pink-500 to-amber-500',
                iconBg: 'bg-pink-500/10 border-pink-500/25 text-pink-400',
                glow: 'hover:border-pink-500/30',
              },
            ].map((item, i) => (
              <div
                key={i}
                className={`relative z-10 bg-slate-950/60 backdrop-blur-xl border border-slate-800/70 rounded-2xl p-8 space-y-5 hover:bg-slate-900/60 transition-all duration-300 hover:-translate-y-1 group overflow-hidden ${item.glow}`}
              >
                {/* Top gradient bar */}
                <div className={`absolute top-0 left-0 w-full h-[2px] bg-gradient-to-r ${item.color} opacity-0 group-hover:opacity-100 transition-opacity duration-300`} />

                {/* Step number */}
                <div className="flex items-center gap-3">
                  <span className={`text-xs font-black font-mono tracking-widest bg-gradient-to-r ${item.color} bg-clip-text text-transparent`}>{item.step}</span>
                  <div className="flex-1 h-px bg-slate-800" />
                </div>

                {/* Icon */}
                <div className={`w-14 h-14 ${item.iconBg} border rounded-2xl flex items-center justify-center group-hover:scale-110 transition-transform duration-300`}>
                  {item.icon}
                </div>

                {/* Content */}
                <div className="space-y-2">
                  <h3 className="text-lg font-bold text-white font-['Space_Grotesk']">{item.title}</h3>
                  <p className="text-sm text-slate-400 leading-relaxed">{item.desc}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ─── FEATURES SECTION ────────────────────────────── */}
      <section id="features" className="relative z-10 py-28 border-y border-white/[0.04]">
        {/* Background tint */}
        <div className="absolute inset-0 bg-gradient-to-b from-transparent via-slate-950/40 to-transparent pointer-events-none" />

        <div className="relative max-w-6xl mx-auto px-4 sm:px-6">
          <div className="text-center max-w-2xl mx-auto mb-16 space-y-3 animate-fade-in-up">
            <div className="inline-flex items-center gap-2 px-3 py-1 bg-purple-500/10 border border-purple-500/20 text-purple-400 rounded-full text-xs font-semibold uppercase tracking-widest mb-2">
              <Star size={11} className="fill-purple-400" />
              Built to solve real problems
            </div>
            <h2 className="text-3xl sm:text-4xl font-extrabold text-white font-['Space_Grotesk'] leading-tight">
              Why we built NeoFiles
            </h2>
            <p className="text-sm text-slate-400 max-w-lg mx-auto leading-relaxed">
              We got tired of the usual cloud storage headaches. Here is how NeoFiles makes distributing software builds painless.
            </p>
          </div>

          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
            {[
              {
                num: '01',
                icon: <HardDrive size={22} />,
                title: 'Keep files in your Drive',
                desc: 'No need to upload files to a third-party server. Link any Drive folder and keep full ownership of your data.',
                gradient: 'from-indigo-500 to-cyan-400',
                glow: 'group-hover:border-indigo-500/30',
                iconBg: 'bg-indigo-500/10 border-indigo-500/20 text-indigo-400',
              },
              {
                num: '02',
                icon: <Folder size={22} />,
                title: 'ZIP folders on the fly',
                desc: 'Got a directory of assets? NeoFiles bundles and downloads nested folders as compressed ZIP archives on-demand.',
                gradient: 'from-purple-500 to-pink-400',
                glow: 'group-hover:border-purple-500/30',
                iconBg: 'bg-purple-500/10 border-purple-500/20 text-purple-400',
              },
              {
                num: '03',
                icon: <Link2 size={22} />,
                title: 'Portal or Direct Stream API',
                desc: 'Send users to a beautifully styled download page with a progress bar, or stream the bytes directly via a raw API URL in your own code.',
                gradient: 'from-cyan-500 to-indigo-400',
                glow: 'group-hover:border-cyan-500/30',
                iconBg: 'bg-cyan-500/10 border-cyan-500/20 text-cyan-400',
              },
              {
                num: '04',
                icon: <Layers size={22} />,
                title: 'Clean version tracking',
                desc: 'Upload new builds without changing your share links. NeoFiles automatically redirects users to the latest file version while keeping storage tidy.',
                gradient: 'from-emerald-500 to-teal-400',
                glow: 'group-hover:border-emerald-500/30',
                iconBg: 'bg-emerald-500/10 border-emerald-500/20 text-emerald-400',
              },
              {
                num: '05',
                icon: <Shield size={22} />,
                title: 'Instant Access Controls',
                desc: 'Approve, suspend, or block specific users from downloading your files. Changes take effect instantly to protect your builds.',
                gradient: 'from-pink-500 to-purple-400',
                glow: 'group-hover:border-pink-500/30',
                iconBg: 'bg-pink-500/10 border-pink-500/20 text-pink-400',
              },
              {
                num: '06',
                icon: <Activity size={22} />,
                title: 'Bypass rate limits',
                desc: 'Get around Google\'s download rate limits. Our proxy layer streams files directly to your users\' devices at full speed.',
                gradient: 'from-amber-500 to-orange-400',
                glow: 'group-hover:border-amber-500/30',
                iconBg: 'bg-amber-500/10 border-amber-500/20 text-amber-400',
              },
            ].map((card, i) => (
              <div
                key={i}
                className={`relative bg-slate-950/50 backdrop-blur-xl border border-slate-800/60 p-7 rounded-2xl space-y-4 hover:bg-slate-900/50 transition-all duration-300 group hover:-translate-y-1 overflow-hidden animate-fade-in-up ${card.glow}`}
                style={{ animationDelay: `${i * 80}ms` }}
              >
                {/* Top gradient bar */}
                <div className={`absolute top-0 left-0 w-full h-[2px] bg-gradient-to-r ${card.gradient} opacity-0 group-hover:opacity-100 transition-opacity duration-300`} />
                {/* Number watermark */}
                <span className="absolute top-4 right-5 text-5xl font-black text-slate-800/30 font-['Space_Grotesk'] select-none">{card.num}</span>

                <div className={`w-11 h-11 ${card.iconBg} border rounded-xl flex items-center justify-center group-hover:scale-110 transition-transform duration-300`}>
                  {card.icon}
                </div>
                <h3 className="font-bold text-base text-white font-['Space_Grotesk']">{card.title}</h3>
                <p className="text-slate-400 text-sm leading-relaxed">{card.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ─── SECURITY SECTION ────────────────────────────── */}
      <section id="security" className="relative z-10 max-w-6xl mx-auto px-4 sm:px-6 py-28">
        <div className="relative bg-gradient-to-br from-slate-900/80 via-indigo-950/30 to-slate-900/80 border border-slate-800/60 rounded-3xl overflow-hidden animate-fade-in-up animation-delay-500">
          {/* Background glow */}
          <div className="absolute top-0 right-0 w-[500px] h-[400px] bg-indigo-500/8 rounded-full blur-[120px] pointer-events-none" />
          <div className="absolute bottom-0 left-0 w-[300px] h-[300px] bg-purple-500/5 rounded-full blur-[100px] pointer-events-none" />

          <div className="relative z-10 p-8 sm:p-12">
            {/* Top Label */}
            <div className="flex flex-col lg:flex-row gap-12 items-start lg:items-center justify-between">
              <div className="space-y-6 max-w-xl">
                <div className="inline-flex items-center gap-2 px-3 py-1 bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 rounded-full text-xs font-semibold uppercase tracking-widest">
                  <Shield size={11} className="animate-pulse" />
                  Secure by design
                </div>

                <h3 className="text-3xl sm:text-4xl font-bold text-white font-['Space_Grotesk'] leading-tight">
                  Rest easy knowing your{' '}
                  <span className="bg-clip-text text-transparent bg-gradient-to-r from-emerald-400 to-cyan-400">
                    files are protected
                  </span>
                </h3>

                <p className="text-slate-400 text-sm sm:text-base leading-relaxed">
                  NeoFiles is built on security best practices. Using Supabase Row-Level Security and short-lived tokens, we ensure that only authorized users can access your files. No leaks, no backdoors.
                </p>

                {/* Security checks */}
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  {[
                    'Strict Row Level Security (RLS)',
                    'Secure user authentication',
                    'No permanent access keys',
                    'Direct-encrypted streams',
                    'Real-time access logs',
                    'Files stay in your Google Drive',
                  ].map((item, i) => (
                    <div key={i} className="flex items-center gap-2.5 text-sm text-slate-300">
                      <div className="w-5 h-5 bg-emerald-500/10 border border-emerald-500/20 rounded-full flex items-center justify-center flex-shrink-0">
                        <CheckCircle2 size={12} className="text-emerald-400" />
                      </div>
                      {item}
                    </div>
                  ))}
                </div>
              </div>

              {/* Terminal-style code block */}
              <div className="w-full lg:w-auto lg:flex-shrink-0 lg:min-w-[340px] overflow-x-auto">
                <div className="bg-[#0a0f1a] border border-slate-700/50 rounded-2xl overflow-hidden shadow-2xl shadow-black/50">
                  {/* Terminal header */}
                  <div className="flex items-center gap-2 px-4 py-3 border-b border-slate-800 bg-slate-900/50">
                    <div className="w-3 h-3 rounded-full bg-red-500/70" />
                    <div className="w-3 h-3 rounded-full bg-amber-500/70" />
                    <div className="w-3 h-3 rounded-full bg-emerald-500/70" />
                    <span className="ml-2 text-[10px] text-slate-500 font-mono">security_policy.sql</span>
                  </div>
                  {/* Code */}
                  <div className="p-5 font-mono text-[11px] leading-relaxed space-y-1">
                    <p><span className="text-purple-400">CREATE</span> <span className="text-indigo-400">POLICY</span> <span className="text-emerald-300">"verified_users_only"</span></p>
                    <p className="pl-4"><span className="text-purple-400">ON</span> <span className="text-cyan-300">storage.files</span></p>
                    <p className="pl-4"><span className="text-purple-400">FOR ALL TO</span> <span className="text-amber-300">authenticated</span></p>
                    <p className="pl-4"><span className="text-purple-400">USING</span> (</p>
                    <p className="pl-8 text-slate-300">auth.uid() <span className="text-slate-500">IN</span> (</p>
                    <p className="pl-12"><span className="text-purple-400">SELECT</span> user_id <span className="text-purple-400">FROM</span></p>
                    <p className="pl-14 text-cyan-300">approved_users</p>
                    <p className="pl-12"><span className="text-purple-400">WHERE</span> status <span className="text-slate-500">=</span> <span className="text-emerald-300">'active'</span></p>
                    <p className="pl-8 text-slate-300">)</p>
                    <p>);</p>
                    <p className="text-slate-600 pt-2">-- ✓ RLS enforced at database level</p>
                  </div>
                </div>

                {/* CTA under terminal */}
                <div className="mt-5 flex justify-center lg:justify-start">
                  <Link
                    to="/login"
                    className="px-7 py-3.5 bg-white text-slate-950 hover:bg-slate-100 rounded-xl text-sm font-bold transition-all duration-200 inline-flex items-center gap-2 transform hover:scale-[1.02] active:scale-95 w-full sm:w-auto justify-center"
                  >
                    Sign In To Console
                    <ArrowRight size={15} />
                  </Link>
                </div>
              </div>
            </div>

            {/* Stat bar */}
            <div className="mt-10 pt-8 border-t border-slate-800/60 grid grid-cols-3 gap-6 text-center">
              {[
                { val: 'AES-256', label: 'Storage Encryption' },
                { val: '< 50ms', label: 'Response Latency' },
                { val: 'Secure RLS', label: 'Access Enforcement' },
              ].map((s, i) => (
                <div key={i}>
                  <p className="text-xl sm:text-2xl font-black text-white font-['Space_Grotesk']">{s.val}</p>
                  <p className="text-xs text-slate-500 mt-1">{s.label}</p>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* ─── FOOTER ──────────────────────────────────────── */}
      <footer className="relative z-10 border-t border-white/[0.05] py-12 bg-gradient-to-b from-transparent to-black/40">
        <div className="max-w-6xl mx-auto px-4 sm:px-6">
          <div className="flex flex-col sm:flex-row items-center justify-between gap-8 text-center sm:text-left">
            
            {/* Left/Center side: Branding and Info */}
            <div className="flex flex-col items-center sm:items-start gap-3">
              
              {/* Logo + Sub-brand line */}
              <div className="flex flex-col sm:flex-row items-center gap-2 sm:gap-3">
                <div className="flex items-center gap-2.5">
                  <img src="/favicon.png" alt="Neo Files Logo" className="w-7 h-7 object-contain opacity-80" />
                  <span className="text-sm font-semibold text-slate-400 font-['Space_Grotesk']">
                    Neo<span className="text-indigo-400">Files</span>
                  </span>
                </div>
                <span className="hidden sm:inline text-slate-700">•</span>
                <span className="text-xs text-slate-500 font-medium">Built with Supabase &amp; Google Drive</span>
              </div>
              
              {/* Tagline & Support Email */}
              <div className="flex flex-col items-center sm:items-start gap-1">
                <p className="text-[11px] text-slate-500">
                  Made with ❤️ for developers
                </p>
                <p className="text-[11px] text-slate-600">
                  Support:{' '}
                  <a href="mailto:rupambairagya08@gmail.com" className="text-indigo-400/90 hover:text-indigo-300 hover:underline font-mono transition-colors">
                    rupambairagya08@gmail.com
                  </a>
                </p>
              </div>

            </div>

            {/* Right/Bottom side: Privacy & Terms */}
            <div className="flex gap-6 text-xs text-slate-500 font-medium">
              <Link to="/privacy" className="hover:text-slate-300 transition-colors">Privacy Policy</Link>
              <Link to="/terms" className="hover:text-slate-300 transition-colors">Terms of Service</Link>
            </div>

          </div>
        </div>
      </footer>
    </div>
  )
}
