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
            Last Updated: October 1, 2026
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
            <h2 className="text-lg font-bold text-white font-['Space_Grotesk']">2. Google API Permissions & Limited Use</h2>
            <p>
              We request access to your Google Drive via the <code className="text-indigo-400 bg-white/5 px-1.5 py-0.5 rounded text-xs">drive.file</code> scope solely to upload files, manage file versions, create destination folders, and facilitate proxy downloads for files created or managed by Neo Files Transfer. We do not inspect, copy, or read your private files outside of what you directly transfer through the application.
            </p>
            <p className="text-slate-400 bg-white/5 p-4 rounded-xl border border-white/10 text-xs">
              <strong>Google API Services User Data Policy:</strong> Neo Files Transfer's use and transfer to any other app of information received from Google APIs will adhere to the <a href="https://developers.google.com/terms/api-services-user-data-policy" target="_blank" rel="noreferrer" className="text-indigo-400 underline">Google API Services User Data Policy</a>, including the Limited Use requirements.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="text-lg font-bold text-white font-['Space_Grotesk']">3. Google User Data Sharing, Transfer, and Disclosure</h2>
            <p>
              We value your privacy above all else. With respect to Google user data:
            </p>
            <ul className="list-disc list-inside pl-4 space-y-1.5 text-slate-400">
              <li><strong className="text-slate-200">No Third-Party Sharing:</strong> We do <strong className="text-slate-200">not</strong> sell, rent, trade, lease, or share Google user data with any third parties, advertisers, or data brokers.</li>
              <li><strong className="text-slate-200">Functional Data Transfers:</strong> Google user data and OAuth tokens are only transmitted directly to official Google APIs to execute requested operations (uploading, streaming, or deleting files) on your behalf.</li>
              <li><strong className="text-slate-200">No AI/ML Model Training:</strong> Google user data is <strong className="text-slate-200">never</strong> used or transferred to develop, train, fine-tune, or improve generalized Artificial Intelligence (AI) or Machine Learning (ML) models.</li>
              <li><strong className="text-slate-200">No Advertising:</strong> Google user data is strictly prohibited from being used for personalized or targeted advertising.</li>
            </ul>
          </section>

          <section className="space-y-3">
            <h2 className="text-lg font-bold text-white font-['Space_Grotesk']">4. Data Security, Storage & Retention</h2>
            <p>
              All database communications are governed by Row Level Security (RLS) policies on Supabase. Uploaded files remain safely stored inside your Google Drive, shielded behind our private proxy links. We do not host your files on our database servers.
            </p>
            <p>
              OAuth tokens are securely stored in your private database record to facilitate automated transfers. We retain this data only for as long as your account remains active.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="text-lg font-bold text-white font-['Space_Grotesk']">5. User Control & Data Deletion</h2>
            <p>
              You maintain total control over your Google data at all times:
            </p>
            <ul className="list-disc list-inside pl-4 space-y-1.5 text-slate-400">
              <li>You can revoke Neo Files Transfer's access to your Google account at any moment through <a href="https://myaccount.google.com/permissions" target="_blank" rel="noreferrer" className="text-indigo-400 underline">Google Account Security Settings</a>.</li>
              <li>You can request complete deletion of your account metadata and stored credentials by contacting us at the email below. Upon request, your profile records and associated access keys will be permanently deleted immediately.</li>
            </ul>
          </section>

          <section className="space-y-3">
            <h2 className="text-lg font-bold text-white font-['Space_Grotesk']">6. Access Controls & Administration</h2>
            <p>
              We maintain logs of users who sign in. Administrators have the authority to revoke user authentication and delete pending/approved registrations. Revoked users lose access instantly to database records and proxy features.
            </p>
          </section>

          <section className="space-y-3">
            <h2 className="text-lg font-bold text-white font-['Space_Grotesk']">7. Contact Info</h2>
            <p>
              For privacy concerns, data deletion requests, or questions regarding our practices, contact us at: <a href="mailto:rupambairagya08@gmail.com" className="text-indigo-400 hover:underline font-mono">rupambairagya08@gmail.com</a>.
            </p>
          </section>
        </div>
      </div>
    </div>
  )
}
