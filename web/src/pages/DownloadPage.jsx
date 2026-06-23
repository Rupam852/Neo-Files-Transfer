import { useEffect, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { supabase } from '../services/supabase'
import { Download, FileX, ShieldX, AlertTriangle } from 'lucide-react'

export default function DownloadPage() {
  const { hash } = useParams()
  const [status, setStatus] = useState('loading') // loading, downloading, denied, notfound, error
  const [fileInfo, setFileInfo] = useState(null)

  useEffect(() => {
    async function resolveDownload() {
      try {
        // Validate share hash
        const { data: file, error } = await supabase
          .from('shared_files')
          .select('id, file_name, mime_type, sharing_status, current_version_num, file_size, google_drive_file_id')
          .eq('unique_share_hash', hash)
          .maybeSingle()

        if (error || !file) {
          setStatus('notfound')
          return
        }

        setFileInfo(file)

        // Check sharing status
        if (file.sharing_status === 'private') {
          setStatus('denied')
          return
        }

        // Check system settings
        const { data: downloadSetting } = await supabase
          .from('system_settings')
          .select('value')
          .eq('key', 'downloads_enabled')
          .maybeSingle()

        if (downloadSetting && downloadSetting.value === false) {
          setStatus('maintenance')
          return
        }

        // Trigger download via edge function
        const { data: { session } } = await supabase.auth.getSession()

        // Use the download edge function as a proxy
        const downloadUrl = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/download-file?hash=${hash}`

        // Open download in a new window/redirect
        window.location.href = downloadUrl
        setStatus('downloading')
      } catch (err) {
        console.error(err)
        setStatus('error')
      }
    }

    resolveDownload()
  }, [hash])

  if (status === 'loading') {
    return (
      <div className="min-h-screen flex items-center justify-center bg-dark-800">
        <div className="text-center">
          <div className="w-10 h-10 border-4 border-primary-600 border-t-transparent rounded-full animate-spin mx-auto mb-4" />
          <p className="text-gray-400">Resolving file...</p>
        </div>
      </div>
    )
  }

  if (status === 'downloading') {
    return (
      <div className="min-h-screen flex items-center justify-center bg-dark-800">
        <div className="text-center">
          <div className="w-16 h-16 bg-green-900/30 rounded-full flex items-center justify-center mx-auto mb-4">
            <Download size={32} className="text-green-400" />
          </div>
          <h2 className="text-xl font-semibold text-gray-100 mb-2">Download Started</h2>
          <p className="text-gray-400 text-sm">{fileInfo?.file_name}</p>
          <Link to="/" className="text-primary-600 hover:underline text-sm mt-4 inline-block">
            Go to Neo Files Home
          </Link>
        </div>
      </div>
    )
  }

  if (status === 'denied') {
    return (
      <div className="min-h-screen flex items-center justify-center bg-dark-800 px-4">
        <div className="text-center max-w-md">
          <div className="w-16 h-16 bg-red-900/30 rounded-full flex items-center justify-center mx-auto mb-6">
            <ShieldX size={32} className="text-red-400" />
          </div>
          <h1 className="text-4xl font-bold text-gray-50 mb-2">403</h1>
          <h2 className="text-xl font-semibold text-gray-100 mb-3">Access Denied</h2>
          <p className="text-gray-400 mb-8">
            This file is private and cannot be downloaded.
          </p>
          <Link to="/" className="btn-primary inline-flex items-center gap-2">
            Go Home
          </Link>
        </div>
      </div>
    )
  }

  if (status === 'maintenance') {
    return (
      <div className="min-h-screen flex items-center justify-center bg-dark-800 px-4">
        <div className="text-center max-w-md">
          <div className="w-16 h-16 bg-amber-900/30 rounded-full flex items-center justify-center mx-auto mb-6">
            <AlertTriangle size={32} className="text-amber-400" />
          </div>
          <h2 className="text-xl font-semibold text-gray-100 mb-3">Service Temporarily Busy</h2>
          <p className="text-gray-400 mb-4">
            Downloads are currently disabled. Please try again later.
          </p>
        </div>
      </div>
    )
  }

  // Not found
  return (
    <div className="min-h-screen flex items-center justify-center bg-dark-800 px-4">
      <div className="text-center max-w-md">
        <div className="w-16 h-16 bg-dark-500 rounded-full flex items-center justify-center mx-auto mb-6">
          <FileX size={32} className="text-gray-400" />
        </div>
        <h1 className="text-4xl font-bold text-gray-50 mb-2">404</h1>
        <h2 className="text-xl font-semibold text-gray-100 mb-3">File Not Found</h2>
        <p className="text-gray-400 mb-8">
          The requested file does not exist or has been removed.
        </p>
        <Link to="/" className="btn-primary inline-flex items-center gap-2">
          Go Home
        </Link>
      </div>
    </div>
  )
}
