import { Link } from 'react-router-dom'
import { ArrowLeft, FileText } from 'lucide-react'

export default function TermsOfServicePage() {
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
            <FileText size={24} className="text-indigo-400" />
          </div>
          <h1 className="text-3xl sm:text-4xl font-extrabold text-white font-['Space_Grotesk'] leading-tight">
            Terms of Service
          </h1>
          <p className="text-xs text-slate-500">
            Last Updated: June 23, 2026
          </p>
        </div>

        {/* Content */}
        <div className="space-y-6 text-sm leading-relaxed">
          <section className="space-y-3">
            <h2 className="text-lg font-bold text-white font-['Space_Grotesk']">1. Usage Policy</h2>
            <p>
              By accessing the Neo Files Transfer portal, you agree to comply with Google Drive's Terms of Service and local data regulations. You are solely responsible for all content uploaded through your console node.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="text-lg font-bold text-white font-['Space_Grotesk']">2. Allowed Use & Moderation</h2>
            <p>
              This portal is meant to serve as a private file storage proxy. You may not use the services to distribute:
            </p>
            <ul className="list-disc list-inside pl-4 space-y-1 text-slate-400">
              <li>Malicious software, viruses, or phishing components.</li>
              <li>Copyrighted material without appropriate permissions or ownership.</li>
              <li>Illegal content violating cyber-security laws.</li>
            </ul>
            <p>
              Admins reserve the right to audit transfer file metadata and terminate access of accounts violating usage rules.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="text-lg font-bold text-white font-['Space_Grotesk']">3. Storage & Proxy Liabilities</h2>
            <p>
              Files uploaded remain stored inside your Google Account. We serve as a proxy router and do not guarantee permanent availability, backup, or persistence of data. Any storage outages from Google's backend APIs are subject to Google Cloud's own service level agreements.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="text-lg font-bold text-white font-['Space_Grotesk']">4. Revocation of Service</h2>
            <p>
              We reserve the right to temporarily freeze or permanently block access requests. Deleted accounts will have their database access removed, preventing any future login capabilities.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="text-lg font-bold text-white font-['Space_Grotesk']">5. Disclaimers</h2>
            <p>
              The application is provided "AS IS" without warranty of any kind. Developers are not liable for data loss, service interruptions, or storage leaks resulting from misconfiguration of Google Drive credentials.
            </p>
          </section>
        </div>
      </div>
    </div>
  )
}
