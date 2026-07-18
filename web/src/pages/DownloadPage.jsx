import { useEffect, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { supabase } from '../services/supabase'
import {
  Download, FileX, ShieldX, AlertTriangle, FileText, Image, Video, Archive,
  Table, Presentation, File, CheckCircle2, AlertCircle, Folder
} from 'lucide-react'
import { formatFileSize, getFileIcon, generateDirectDownloadUrl, formatErrorMessage } from '../utils/helpers'

const ICON_MAP = {
  'file-text': FileText,
  'image': Image,
  'video': Video,
  'archive': Archive,
  'table': Table,
  'presentation': Presentation,
  'file': File,
}

export default function DownloadPage() {
  const { hash } = useParams()
  const [status, setStatus] = useState('loading') // loading, downloading, completed, denied, notfound, error, maintenance
  const [fileInfo, setFileInfo] = useState(null)
  const [progress, setProgress] = useState(0)
  const [downloadedBytes, setDownloadedBytes] = useState(0)
  const [totalBytes, setTotalBytes] = useState(0)
  const [errorMsg, setErrorMsg] = useState('')
  const [downloadBlobUrl, setDownloadBlobUrl] = useState('')
  const [downloadStage, setDownloadStage] = useState('')

  useEffect(() => {
    // Cleanup blob URL on unmount
    return () => {
      if (downloadBlobUrl) {
        URL.revokeObjectURL(downloadBlobUrl)
      }
    }
  }, [downloadBlobUrl])

  useEffect(() => {
    async function loadMetadata() {
      try {
        // Validate share hash
        const { data: file, error } = await supabase
          .from('shared_files')
          .select('id, file_name, mime_type, sharing_status, current_version_num, file_size, google_drive_file_id, is_folder')
          .eq('unique_share_hash', hash)
          .maybeSingle()

        if (error || !file) {
          setStatus('notfound')
          return
        }

        setFileInfo(file)
        setTotalBytes(file.file_size || 0)

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

        setStatus('preview')

      } catch (err) {
        console.error('Metadata resolve error:', err)
        setErrorMsg('Failed to resolve sharing details.')
        setStatus('error')
      }
    }

    loadMetadata()
  }, [hash])

  const handleStartDownload = async () => {
    if (!fileInfo) return

    try {
      console.log('Using native browser download manager for maximum speed.')
      setStatus('downloading')

      // Short delay with loading spinner before transitioning to completed screen
      setTimeout(() => {
        setStatus('completed')
      }, 1200)

    } catch (err) {
      console.error('Download error:', err)
      setErrorMsg(formatErrorMessage(err))
      setStatus('error')
    }
  }

  // Get file icon based on mime type
  const iconName = getFileIcon(fileInfo?.mime_type)
  const FileIcon = fileInfo?.is_folder ? Folder : (ICON_MAP[iconName] || File)

  if (status === 'loading') {
    return (
      <div className="min-h-screen flex items-center justify-center bg-[#030712]">
        <div className="text-center space-y-4">
          <div className="w-10 h-10 border-4 border-indigo-500 border-t-transparent rounded-full animate-spin mx-auto" />
          <p className="text-gray-400 text-sm font-medium font-['Space_Grotesk'] tracking-wide">Resolving secure share link...</p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen w-full bg-[#030712] text-gray-100 flex items-center justify-center p-4 sm:p-6 lg:p-8 font-['Plus_Jakarta_Sans'] relative overflow-hidden">
      {/* Import Premium Fonts */}
      <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Space+Grotesk:wght@500;600;700&display=swap" rel="stylesheet" />

      {/* Futuristic Background Light Glows */}
      <div className="absolute top-[-10%] left-[-10%] w-[50%] h-[50%] rounded-full bg-indigo-500/5 blur-[120px] pointer-events-none" />
      <div className="absolute bottom-[-10%] right-[-10%] w-[50%] h-[50%] rounded-full bg-purple-500/5 blur-[120px] pointer-events-none" />

      {/* Main Card Container */}
      <div className="w-full max-w-lg bg-slate-950/80 backdrop-blur-3xl border border-slate-900 rounded-3xl p-6 sm:p-8 shadow-2xl relative z-10">
        
        {/* State: preview */}
        {status === 'preview' && (
          <div className="space-y-6">
            <div className="text-center space-y-2">
              <div className="inline-flex items-center gap-1.5 px-3 py-1 bg-indigo-500/10 border border-indigo-500/20 text-indigo-400 rounded-full text-xs font-semibold uppercase tracking-wider mb-2">
                <Download size={12} />
                Secure Link Resolved
              </div>
              <h2 className="text-2xl font-bold text-white font-['Space_Grotesk']">Ready to Download</h2>
              <p className="text-sm text-slate-400 text-center">Click below to start retrieving files from the Shield node.</p>
            </div>

            {/* File Info Block */}
            <div className="bg-slate-900/50 border border-slate-900 rounded-2xl p-5 flex items-center gap-4">
              <div className="w-14 h-14 bg-indigo-500/10 border border-indigo-500/20 rounded-xl flex items-center justify-center text-indigo-400 flex-shrink-0">
                <FileIcon size={28} />
              </div>
              <div className="min-w-0 flex-1">
                <p className="text-sm font-semibold text-white truncate leading-tight mb-1">{fileInfo?.file_name}</p>
                <p className="text-xs text-slate-400 font-medium">{fileInfo?.is_folder ? 'Folder • Compressed as ZIP' : formatFileSize(totalBytes)}</p>
              </div>
            </div>

            {/* APK Security Warning Banner */}
            {fileInfo?.file_name?.toLowerCase().endsWith('.apk') && (
              <div className="bg-amber-500/10 border border-amber-500/20 rounded-2xl p-4 flex gap-3 text-left">
                <AlertTriangle className="text-amber-500 flex-shrink-0 mt-0.5" size={18} />
                <div className="space-y-1">
                  <p className="text-xs font-semibold text-amber-400">Android APK Warning</p>
                  <p className="text-[11px] text-slate-400 leading-relaxed">
                    Some browsers may show a safety warning during download. This is a standard prompt for all Android apps. You can safely click <strong>"Keep"</strong> or <strong>"Download anyway"</strong>.
                  </p>
                </div>
              </div>
            )}

            <a
              href={generateDirectDownloadUrl(hash, fileInfo?.is_folder, fileInfo?.file_size)}
              onClick={handleStartDownload}
              rel="noopener noreferrer"
              className="w-full bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-500 hover:to-purple-500 text-white py-3.5 rounded-xl font-bold flex items-center justify-center gap-2 transition-all duration-300 hover:shadow-[0_0_20px_rgba(99,102,241,0.4)] active:scale-[0.98] text-center"
            >
              <Download size={18} /> Download Now
            </a>
            
            <p className="text-center text-xs text-slate-500">
              Files are transferred securely with TLS encryption.
            </p>
          </div>
        )}

        {/* State: downloading or saving */}
        {(status === 'downloading' || status === 'saving') && (
          <div className="space-y-6 text-center py-6">
            <div className="w-12 h-12 border-4 border-indigo-500 border-t-transparent rounded-full animate-spin mx-auto" />
            <div className="space-y-2">
              <h2 className="text-2xl font-bold text-white font-['Space_Grotesk']">Preparing Download</h2>
              <p className="text-sm text-slate-400">Initiating secure stream from Shield node. Please wait...</p>
            </div>
          </div>
        )}

        {/* State: completed */}
        {status === 'completed' && (
          <div className="space-y-6 text-center">
            <div className="w-16 h-16 bg-emerald-500/10 border border-emerald-500/20 rounded-2xl flex items-center justify-center mx-auto text-emerald-400">
              <CheckCircle2 size={36} className="animate-scale-in" />
            </div>
            <div className="space-y-2">
              <h2 className="text-2xl font-bold text-white font-['Space_Grotesk']">Download Started</h2>
              <p className="text-sm text-slate-400">{fileInfo?.file_name}</p>
            </div>
            <div className="bg-slate-900/40 rounded-xl p-4 text-sm text-slate-300 leading-relaxed border border-slate-900">
              The file download has started. If it did not save automatically, click the button below to retry.
            </div>
            <a
              href={generateDirectDownloadUrl(hash, fileInfo?.is_folder, fileInfo?.file_size)}
              rel="noopener noreferrer"
              className="w-full btn-primary py-3 rounded-xl font-semibold flex items-center justify-center gap-2 text-center"
            >
              <Download size={16} /> Save File Again
            </a>
            <p className="text-xs text-slate-500">
              Powered by Neo Files Transfer
            </p>
          </div>
        )}

        {/* State: denied */}
        {status === 'denied' && (
          <div className="space-y-6 text-center">
            <div className="w-16 h-16 bg-red-500/10 border border-red-500/20 rounded-2xl flex items-center justify-center mx-auto text-red-400">
              <ShieldX size={36} />
            </div>
            <div className="space-y-2">
              <h1 className="text-3xl font-extrabold text-white font-['Space_Grotesk']">403</h1>
              <h2 className="text-xl font-bold text-slate-200">Access Denied</h2>
              <p className="text-sm text-slate-400 px-4">
                This file sharing configuration is private. The link holder is restricted from downloads.
              </p>
            </div>
            <Link to="/" className="w-full btn-secondary py-3 rounded-xl font-semibold flex items-center justify-center gap-2">
              Back to Console
            </Link>
          </div>
        )}

        {/* State: maintenance */}
        {status === 'maintenance' && (
          <div className="space-y-6 text-center">
            <div className="w-16 h-16 bg-amber-500/10 border border-amber-500/20 rounded-2xl flex items-center justify-center mx-auto text-amber-400">
              <AlertTriangle size={36} />
            </div>
            <div className="space-y-2">
              <h2 className="text-xl font-bold text-slate-200">Service Temporarily Busy</h2>
              <p className="text-sm text-slate-400 px-4">
                The platform downloads are temporarily disabled by the administrator. Please retry later.
              </p>
            </div>
            <Link to="/" className="w-full btn-secondary py-3 rounded-xl font-semibold flex items-center justify-center gap-2">
              Back to Console
            </Link>
          </div>
        )}

        {/* State: notfound */}
        {status === 'notfound' && (
          <div className="space-y-6 text-center">
            <div className="w-16 h-16 bg-slate-900 border border-slate-800 rounded-2xl flex items-center justify-center mx-auto text-slate-400">
              <FileX size={36} />
            </div>
            <div className="space-y-2">
              <h1 className="text-3xl font-extrabold text-white font-['Space_Grotesk']">404</h1>
              <h2 className="text-xl font-bold text-slate-200">File Not Found</h2>
              <p className="text-sm text-slate-400 px-4">
                The requested file hash does not resolve to an active storage link or has been removed.
              </p>
            </div>
            {/* Button removed as requested */}
          </div>
        )}

        {/* State: error */}
        {status === 'error' && (
          <div className="space-y-6 text-center">
            <div className="w-16 h-16 bg-red-500/10 border border-red-500/20 rounded-2xl flex items-center justify-center mx-auto text-red-400">
              <AlertCircle size={36} />
            </div>
            <div className="space-y-2">
              <h2 className="text-xl font-bold text-slate-200 font-['Space_Grotesk']">Download Failed</h2>
              <p className="text-xs text-red-400/90 font-medium bg-red-500/5 border border-red-500/10 rounded-xl p-3 mt-2 leading-relaxed">
                {errorMsg}
              </p>
            </div>
            
            <div className="flex flex-col gap-3">
              <button
                onClick={() => {
                  setStatus('loading')
                  window.location.reload()
                }}
                className="w-full btn-primary py-3 rounded-xl font-semibold flex items-center justify-center gap-2"
              >
                <Download size={16} /> Retry Streaming
              </button>
              <a
                href={generateDirectDownloadUrl(hash, fileInfo?.is_folder, fileInfo?.file_size)}
                rel="noopener noreferrer"
                className="w-full bg-slate-900 hover:bg-slate-800 border border-slate-800 hover:border-slate-700 text-slate-200 py-3 rounded-xl font-semibold flex items-center justify-center gap-2 transition-all duration-200 text-center"
              >
                <Download size={16} /> Download Directly (No Stream)
              </a>
            </div>

            <p className="text-xs text-slate-500">
              If the error persists, please contact the link owner.
            </p>
          </div>
        )}

      </div>
    </div>
  )
}
