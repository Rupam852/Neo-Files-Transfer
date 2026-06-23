import { useEffect, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { supabase } from '../services/supabase'
import {
  Download, FileX, ShieldX, AlertTriangle, FileText, Image, Video, Archive,
  Table, Presentation, File, CheckCircle2, AlertCircle
} from 'lucide-react'
import { formatFileSize, getFileIcon } from '../utils/helpers'

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

  useEffect(() => {
    // Cleanup blob URL on unmount
    return () => {
      if (downloadBlobUrl) {
        URL.revokeObjectURL(downloadBlobUrl)
      }
    }
  }, [downloadBlobUrl])

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

        setStatus('downloading')

        // Start streaming download via proxy
        const downloadUrl = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/download-file?hash=${hash}`
        
        const response = await fetch(downloadUrl)
        if (!response.ok) {
          throw new Error(`Google Drive Proxy returned HTTP ${response.status}`)
        }

        if (!response.body) {
          throw new Error('ReadableStream not supported by proxy response.')
        }

        const reader = response.body.getReader()
        const chunks = []
        let receivedLength = 0
        const totalLength = file.file_size || parseInt(response.headers.get('Content-Length') || '0', 10)

        while (true) {
          const { done, value } = await reader.read()
          if (done) break
          
          chunks.push(value)
          receivedLength += value.length
          setDownloadedBytes(receivedLength)
          
          if (totalLength) {
            const pct = Math.min(Math.round((receivedLength / totalLength) * 100), 100)
            setProgress(pct)
          }
        }

        // Trigger client-side save
        const blob = new Blob(chunks, { type: file.mime_type || 'application/octet-stream' })
        const blobUrl = URL.createObjectURL(blob)
        setDownloadBlobUrl(blobUrl)

        setStatus('completed')

        const a = document.createElement('a')
        a.href = blobUrl
        a.download = file.file_name
        document.body.appendChild(a)
        a.click()
        document.body.removeChild(a)

      } catch (err) {
        console.error('Download stream error:', err)
        setErrorMsg(err.message || 'Unable to stream download file.')
        setStatus('error')
      }
    }

    resolveDownload()
  }, [hash])

  // Get file icon based on mime type
  const iconName = getFileIcon(fileInfo?.mime_type)
  const FileIcon = ICON_MAP[iconName] || File

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
        
        {/* State: downloading */}
        {status === 'downloading' && (
          <div className="space-y-6">
            <div className="text-center space-y-2">
              <div className="inline-flex items-center gap-1.5 px-3 py-1 bg-indigo-500/10 border border-indigo-500/20 text-indigo-400 rounded-full text-xs font-semibold uppercase tracking-wider mb-2">
                <Download size={12} className="animate-bounce" />
                Secure Stream Active
              </div>
              <h2 className="text-2xl font-bold text-white font-['Space_Grotesk']">Downloading File</h2>
              <p className="text-sm text-slate-400">Streaming secure blocks directly from Shield node.</p>
            </div>

            {/* File Info Block */}
            <div className="bg-slate-900/50 border border-slate-900 rounded-2xl p-4 flex items-center gap-4">
              <div className="w-12 h-12 bg-indigo-500/10 border border-indigo-500/20 rounded-xl flex items-center justify-center text-indigo-400 flex-shrink-0">
                <FileIcon size={24} />
              </div>
              <div className="min-w-0 flex-1">
                <p className="text-sm font-semibold text-white truncate leading-tight mb-1">{fileInfo?.file_name}</p>
                <p className="text-xs text-slate-400 font-medium">{formatFileSize(totalBytes)}</p>
              </div>
            </div>

            {/* Realtime Progress Track */}
            <div className="space-y-2">
              <div className="flex items-center justify-between text-xs font-medium">
                <span className="text-slate-400">Progress: {progress}%</span>
                <span className="text-indigo-400 font-semibold">
                  {formatFileSize(downloadedBytes)} / {formatFileSize(totalBytes)}
                </span>
              </div>
              <div className="h-2.5 bg-slate-900 border border-slate-800/80 rounded-full overflow-hidden relative">
                <div 
                  className="bg-gradient-to-r from-indigo-500 via-purple-500 to-pink-500 h-full rounded-full transition-all duration-150 ease-out shadow-[0_0_12px_rgba(99,102,241,0.5)]" 
                  style={{ width: `${progress}%` }}
                />
              </div>
            </div>

            <div className="text-center text-xs text-slate-500">
              Please do not close this window. Your download is preparing in local browser memory.
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
              <h2 className="text-2xl font-bold text-white font-['Space_Grotesk']">Download Complete</h2>
              <p className="text-sm text-slate-400">{fileInfo?.file_name}</p>
            </div>
            <div className="bg-slate-900/40 rounded-xl p-4 text-sm text-slate-300 leading-relaxed border border-slate-900">
              The file download has started. If it did not save automatically, click the button below to retry.
            </div>
            <button
              onClick={() => {
                if (downloadBlobUrl) {
                  const a = document.createElement('a')
                  a.href = downloadBlobUrl
                  a.download = fileInfo?.file_name || 'download'
                  a.click()
                } else {
                  window.location.reload()
                }
              }}
              className="w-full btn-primary py-3 rounded-xl font-semibold flex items-center justify-center gap-2"
            >
              <Download size={16} /> Save File Again
            </button>
            <p className="text-xs text-slate-500">
              <Link to="/" className="text-indigo-400 hover:text-indigo-300 hover:underline">
                Go back to Neo Files Transfer
              </Link>
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
            <Link to="/" className="w-full btn-primary py-3 rounded-xl font-semibold flex items-center justify-center gap-2">
              Request Console Access
            </Link>
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
            <button
              onClick={() => window.location.reload()}
              className="w-full btn-primary py-3 rounded-xl font-semibold flex items-center justify-center gap-2"
            >
              Retry Download
            </button>
            <p className="text-xs text-slate-500">
              If the error persists, please contact the link owner.
            </p>
          </div>
        )}

      </div>
    </div>
  )
}
