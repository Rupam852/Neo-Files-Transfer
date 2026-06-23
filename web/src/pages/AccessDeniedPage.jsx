import { Link } from 'react-router-dom'
import { ShieldX, Home } from 'lucide-react'

export default function AccessDeniedPage() {
  return (
    <div className="min-h-screen flex items-center justify-center bg-dark-800 px-4">
      <div className="text-center max-w-md">
        <div className="w-16 h-16 bg-red-500/10 border border-red-500/20 rounded-full flex items-center justify-center mx-auto mb-6">
          <ShieldX size={32} className="text-red-500" />
        </div>
        <h1 className="text-4xl font-bold text-gray-50 mb-2">403</h1>
        <h2 className="text-xl font-semibold text-gray-100 mb-3">Access Denied</h2>
        <p className="text-gray-400 mb-8">
          You do not have permission to access this file.
        </p>
        <Link to="/" className="btn-primary inline-flex items-center gap-2">
          <Home size={16} /> Go Home
        </Link>
      </div>
    </div>
  )
}
