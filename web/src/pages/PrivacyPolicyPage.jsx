import { Link } from 'react-router-dom'
import { ArrowLeft, Shield } from 'lucide-react'

export default function PrivacyPolicyPage() {
  return (
    <div className="min-h-screen bg-[#030712] text-gray-300 font-['Plus_Jakarta_Sans'] relative overflow-hidden py-16 px-4">
      {/* Import Premium Fonts */}
      <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Space+Grotesk:wght@500;600;700&display=swap" rel="stylesheet" />
      
      {/* Background Gradients */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none z-0">
        <div className="absolute top-[-10%] left-[-10%] w-[50%] h-[50%] rounded-full bg-indigo-500/5 blur-[120px]" />
        <div className="absolute bottom-[-10%] right-[-10%] w-[50%] h-[50%] rounded-full bg-purple-500/5 blur-[120px]" />
      </div>

      <div className="max-w-3xl mx-auto relative z-10 space-y-8">
        {/* Back Link */}
        <Link to="/" className="inline-flex items-center gap-2 text-xs font-semibold text-slate-500 hover:text-indigo-400 transition-colors">
          <ArrowLeft size={14} />
          Back to Home
        </Link>

        {/* Header */}
        <div className="space-y-4 border-b border-white/5 pb-8">
          <div className="w-12 h-12 bg-indigo-500/10 border border-indigo-500/20 rounded-2xl flex items-center justify-center">
            <Shield size={24} className="text-indigo-400" />
          </div>
          <h1 className="text-3xl sm:text-4xl font-extrabold text-white font-['Space_Grotesk'] leading-tight">
            Privacy Policy
          </h1>
          <p className="text-xs text-slate-500">
            Last Updated: June 23, 2026
          </p>
        </div>

        {/* Content */}
        <div className="space-y-6 text-sm leading-relaxed">
          <section className="space-y-3">
            <h2 className="text-lg font-bold text-white font-['Space_Grotesk']">1. Information We Collect</h2>
            <p>
              We only collect information necessary to provide proxy file transfer functionality. This includes:
            </p>
            <ul className="list-disc list-inside pl-4 space-y-1 text-slate-400">
              <li>Google OAuth Identity details (Email, Name, Profile Image) during authentication.</li>
              <li>Registration request details (Name, Phone Number, Email) submitted for access approval.</li>
              <li>Upload metadata (File names, file sizes, folder structures) to manage proxy transfer links.</li>
            </ul>
          </section>

          <section className="space-y-3">
            <h2 className="text-lg font-bold text-white font-['Space_Grotesk']">2. Google API Permissions</h2>
            <p>
              We request access to your Google Drive to execute proxy downloads. We do not store, copy, or read your private personal data beyond the specific files you upload and request through the platform. Your credentials are authenticated directly by Google OAuth and are not accessible by us.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="text-lg font-bold text-white font-['Space_Grotesk']">3. Data Security & Storage</h2>
            <p>
              All database communications are governed by Row Level Security (RLS) policies on Supabase. Uploaded files remain stored inside your designated Google Drive folder, shielded behind our private proxy links. We do not host your files on our database servers.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="text-lg font-bold text-white font-['Space_Grotesk']">4. Access Controls</h2>
            <p>
              We maintain logs of users who sign in. Admins have the authority to revoke user authentication and delete pending/approved registrations. Revoked users lose access instantly to database records and proxy features.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="text-lg font-bold text-white font-['Space_Grotesk']">5. Contact Info</h2>
            <p>
              For privacy concerns or to request data erasure, contact us at: <a href="mailto:rupambairagya08@gmail.com" className="text-indigo-400 hover:underline font-mono">rupambairagya08@gmail.com</a>.
            </p>
          </section>
        </div>
      </div>
    </div>
  )
}
