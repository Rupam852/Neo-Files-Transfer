import { useState } from 'react'
import { Link } from 'react-router-dom'
import { supabase } from '../services/supabase'
import toast from 'react-hot-toast'
import { Cloud, Shield, Link2, ArrowRight, AlertTriangle } from 'lucide-react'

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
    <div className="min-h-screen">
      {/* Header */}
      <header className="bg-dark-700 border-b border-dark-400">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 h-16 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 bg-primary-600 rounded-lg flex items-center justify-center">
              <span className="text-white font-bold text-sm">NF</span>
            </div>
            <span className="font-semibold text-lg text-gray-100">Neo Files Transfer</span>
          </div>
          <div className="flex items-center gap-3">
            <Link to="/login" className="btn-secondary text-sm">
              User Login
            </Link>
            <Link to="/admin" className="btn-primary text-sm">
              Admin Login
            </Link>
          </div>
        </div>
      </header>

      {/* Hero */}
      <section className="py-20 lg:py-28">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 text-center">
          <div className="inline-flex items-center gap-2 px-4 py-1.5 bg-primary-600/15 text-primary-400 rounded-full text-sm font-medium mb-6 border border-primary-600/20">
            <Cloud size={16} />
            Cloud File Management Platform
          </div>
          <h1 className="text-4xl sm:text-5xl lg:text-6xl font-bold text-gray-50 leading-tight mb-6">
            Secure Cloud File Management<br />
            <span className="text-primary-400">Powered By Google Drive</span>
          </h1>
          <p className="text-lg text-gray-400 max-w-2xl mx-auto mb-10">
            Upload, share, and manage files with enterprise-grade security. 
            Version control, custom share links, and download protection — all in one place.
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <Link to="/login" className="btn-primary flex items-center justify-center gap-2 text-base px-8 py-3">
              Get Started <ArrowRight size={18} />
            </Link>
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="py-16 bg-dark-700 border-y border-dark-400">
        <div className="max-w-6xl mx-auto px-4 sm:px-6">
          <div className="grid md:grid-cols-3 gap-8">
            <div className="text-center p-6">
              <div className="w-12 h-12 bg-primary-600/20 border border-primary-600/30 rounded-xl flex items-center justify-center mx-auto mb-4">
                <Shield size={24} className="text-primary-400" />
              </div>
              <h3 className="font-semibold text-gray-100 mb-2">Secure Downloads</h3>
              <p className="text-gray-400 text-sm">
                Hidden Google Drive URLs with download proxy protection and access control.
              </p>
            </div>
            <div className="text-center p-6">
              <div className="w-12 h-12 bg-green-600/20 border border-green-600/30 rounded-xl flex items-center justify-center mx-auto mb-4">
                <Link2 size={24} className="text-green-400" />
              </div>
              <h3 className="font-semibold text-gray-100 mb-2">Custom Share Links</h3>
              <p className="text-gray-400 text-sm">
                Generate clean, branded share URLs. Toggle between public and private access.
              </p>
            </div>
            <div className="text-center p-6">
              <div className="w-12 h-12 bg-orange-600/20 border border-orange-600/30 rounded-xl flex items-center justify-center mx-auto mb-4">
                <Cloud size={24} className="text-orange-400" />
              </div>
              <h3 className="font-semibold text-gray-100 mb-2">Version Control</h3>
              <p className="text-gray-400 text-sm">
                Track file revisions, upload new versions, and always share the latest file.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Warning Banner */}
      <section className="py-8">
        <div className="max-w-3xl mx-auto px-4 sm:px-6">
          <div className="bg-amber-900/30 border border-amber-600/30 rounded-xl p-4 flex items-start gap-3">
            <AlertTriangle size={20} className="text-amber-400 mt-0.5 flex-shrink-0" />
            <div>
              <p className="text-amber-200 font-medium text-sm">
                Do not login directly! First submit the registration form below and wait for admin approval.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Registration Form */}
      <section className="py-12 pb-20">
        <div className="max-w-md mx-auto px-4 sm:px-6">
          <h2 className="text-2xl font-bold text-gray-50 text-center mb-2">Register</h2>
          <p className="text-gray-400 text-center text-sm mb-8">
            Submit your registration to request access to Neo Files Transfer
          </p>

          <form onSubmit={handleSubmit} className="card space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-300 mb-1">Name</label>
              <input
                type="text"
                className="input-field"
                placeholder="Your full name"
                value={formData.name}
                onChange={e => setFormData({ ...formData, name: e.target.value })}
                required
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-300 mb-1">Phone Number</label>
              <input
                type="tel"
                className="input-field"
                placeholder="Your phone number"
                value={formData.phone}
                onChange={e => setFormData({ ...formData, phone: e.target.value })}
                required
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-300 mb-1">Email Address</label>
              <input
                type="email"
                className="input-field"
                placeholder="Must match your Google account"
                value={formData.email}
                onChange={e => setFormData({ ...formData, email: e.target.value })}
                required
              />
              <p className="text-xs text-gray-500 mt-1">
                This must match the Google account you will use to login
              </p>
            </div>
            <button
              type="submit"
              disabled={submitting}
              className="btn-primary w-full py-3"
            >
              {submitting ? 'Submitting...' : 'Submit Registration'}
            </button>
          </form>
        </div>
      </section>

      {/* Footer */}
      <footer className="bg-dark-700 border-t border-dark-400 py-8">
        <div className="max-w-6xl mx-auto px-4 sm:px-6">
          <div className="flex flex-col sm:flex-row items-center justify-between gap-4">
            <div className="flex items-center gap-2">
              <div className="w-6 h-6 bg-primary-600 rounded flex items-center justify-center">
                <span className="text-white font-bold text-xs">NF</span>
              </div>
              <span className="text-sm text-gray-400">Neo Files Transfer v1.0</span>
            </div>
            <div className="flex gap-6 text-sm text-gray-500">
              <a href="#" className="hover:text-gray-300">Privacy Policy</a>
              <a href="#" className="hover:text-gray-300">Terms of Service</a>
              <a href="#" className="hover:text-gray-300">Contact</a>
            </div>
          </div>
        </div>
      </footer>
    </div>
  )
}
