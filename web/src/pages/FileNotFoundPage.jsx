import { Link } from 'react-router-dom'
import { FileX, Home } from 'lucide-react'

export default function FileNotFoundPage() {
  return (
    <div className="min-h-screen flex items-center justify-center bg-dark-800 px-4">
      <div className="text-center max-w-md">
        <div className="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-6">
          <FileX size={32} className="text-gray-400" />
        </div>
        <h1 className="text-4xl font-bold text-gray-50 mb-2">404</h1>
        <h2 className="text-xl font-semibold text-gray-100 mb-3">File Not Found</h2>
        <p className="text-gray-400 mb-8">
          The requested file does not exist or has been removed.
        </p>
        <Link to="/" className="btn-primary inline-flex items-center gap-2">
          <Home size={16} /> Go Home
        </Link>
      </div>
    </div>
  )
}
