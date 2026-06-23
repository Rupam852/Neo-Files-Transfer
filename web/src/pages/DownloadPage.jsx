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
      const directUrl = generateDirectDownloadUrl(hash)
      const fileLimit = 50 * 1024 * 1024 // 50MB
      const isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent)

      // If file is very large or we are on mobile and file is moderately large, bypass streaming to avoid browser memory crashes
      if (fileInfo.file_size && (fileInfo.file_size > fileLimit || (isMobile && fileInfo.file_size > 15 * 1024 * 1024))) {
        console.log('Bypassing JS streaming due to size/mobile constraints. Initiating direct browser download.')
        setStatus('downloading')
        setProgress(15)
        
        setTimeout(() => setProgress(50), 250)
        setTimeout(() => setProgress(85), 550)
        setTimeout(() => {
          setProgress(100)
          setStatus('saving')
        }, 850)
        
        setTimeout(() => {
          window.location.href = directUrl
        }, 1500)

        setTimeout(() => {
          setStatus('completed')
        }, 7500) // 1.5 seconds setup + 6 seconds saving hold
        return
      }

      setStatus('downloading')
      setProgress(0)
      setDownloadedBytes(0)

      // Start streaming download via proxy
      const downloadUrl = `${directUrl}&stream=true`
      
      let response
      try {
        response = await fetch(downloadUrl)
      } catch (fetchErr) {
        console.warn('Initial fetch stream failed, falling back to direct browser download:', fetchErr)
        setStatus('completed')
        window.location.href = directUrl
        return
      }

      if (!response.ok) {
        // Attempt to parse JSON error details
        try {
          const errData = await response.json()
          if (errData?.fallbackUrl) {
            console.log('Stream request failed, falling back to direct download URL:', errData.fallbackUrl)
            window.location.href = errData.fallbackUrl
            setStatus('completed')
            return
          }
          throw new Error(errData?.error || `Server returned HTTP ${response.status}`)
        } catch (jsonErr) {
          if (jsonErr instanceof SyntaxError) {
            throw new Error(`Google Drive Proxy returned HTTP ${response.status}`)
          }
          throw jsonErr
        }
      }

      if (!response.body) {
        throw new Error('ReadableStream not supported by proxy response.')
      }

      const reader = response.body.getReader()
      const chunks = []
      let receivedLength = 0
      const totalLength = fileInfo.file_size || parseInt(response.headers.get('Content-Length') || '0', 10)

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
      setStatus('saving')
      setProgress(100)
      
      // Allow UI thread to update to the saving state before CPU intensive Blob parsing
      await new Promise(resolve => setTimeout(resolve, 300))

      const blob = new Blob(chunks, { type: fileInfo.mime_type || 'application/octet-stream' })
      const blobUrl = URL.createObjectURL(blob)
      setDownloadBlobUrl(blobUrl)

      const a = document.createElement('a')
      a.href = blobUrl
      a.download = fileInfo.file_name
      document.body.appendChild(a)
      a.click()
      document.body.removeChild(a)

      // Wait 6 seconds for Chrome's native download UI to trigger before changing status to completed
      await new Promise(resolve => setTimeout(resolve, 6000))
      setStatus('completed')

    } catch (err) {
      console.error('Download stream error:', err)
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
                <p className="text-xs text-slate-400 font-medium">{fileInfo?.is_folder ? 'Folder Archive' : formatFileSize(totalBytes)}</p>
              </div>
            </div>

            <button
              onClick={handleStartDownload}
              className="w-full bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-500 hover:to-purple-500 text-white py-3.5 rounded-xl font-bold flex items-center justify-center gap-2 transition-all duration-300 hover:shadow-[0_0_20px_rgba(99,102,241,0.4)] active:scale-[0.98]"
            >
              <Download size={18} /> Download Now
            </button>
            
            <p className="text-center text-xs text-slate-500">
              Files are transferred securely with TLS encryption.
            </p>
          </div>
        )}

        {/* State: downloading or saving */}
        {(status === 'downloading' || status === 'saving') && (
          <div className="space-y-6">
            <div className="text-center space-y-2">
              <div className="inline-flex items-center gap-1.5 px-3 py-1 bg-indigo-500/10 border border-indigo-500/20 text-indigo-400 rounded-full text-xs font-semibold uppercase tracking-wider mb-2">
                <Download size={12} className="animate-bounce" />
                {status === 'saving' ? 'Saving File...' : 'Secure Stream Active'}
              </div>
              <h2 className="text-2xl font-bold text-white font-['Space_Grotesk']">
                {status === 'saving' ? 'Finalizing Download' : 'Downloading File'}
              </h2>
              <p className="text-sm text-slate-400">
                {status === 'saving' ? 'Writing file stream directly to your device storage...' : 'Streaming secure blocks directly from Shield node.'}
              </p>
            </div>

            {/* File Info Block */}
            <div className="bg-slate-900/50 border border-slate-900 rounded-2xl p-4 flex items-center gap-4">
              <div className="w-12 h-12 bg-indigo-500/10 border border-indigo-500/20 rounded-xl flex items-center justify-center text-indigo-400 flex-shrink-0">
                <FileIcon size={24} />
              </div>
              <div className="min-w-0 flex-1">
                <p className="text-sm font-semibold text-white truncate leading-tight mb-1">{fileInfo?.file_name}</p>
                <p className="text-xs text-slate-400 font-medium">{fileInfo?.is_folder ? 'Folder Archive' : formatFileSize(totalBytes)}</p>
              </div>
            </div>

            {/* Realtime Progress Track */}
            <div className="space-y-2">
              <div className="flex items-center justify-between text-xs font-medium">
                <span className="text-slate-400">
                  {status === 'saving' ? 'Progress: 100%' : `Progress: ${progress}%`}
                </span>
                <span className="text-indigo-400 font-semibold">
                  {status === 'saving' ? 'Saving...' : (fileInfo?.is_folder ? `${formatFileSize(downloadedBytes)} downloaded` : `${formatFileSize(downloadedBytes)} / ${formatFileSize(totalBytes)}`)}
                </span>
              </div>
              <div className="h-2.5 bg-slate-900 border border-slate-800/80 rounded-full overflow-hidden relative">
                <div 
                  className="bg-gradient-to-r from-indigo-500 via-purple-500 to-pink-500 h-full rounded-full transition-all duration-300 ease-out shadow-[0_0_12px_rgba(99,102,241,0.5)]" 
                  style={{ width: `${progress}%` }}
                />
              </div>
            </div>

            <div className="text-center text-xs text-slate-500">
              {status === 'saving' ? 'Writing cached blocks. Do not close this window.' : 'Please do not close this window. Your download is preparing in local browser memory.'}
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
              <button
                onClick={() => {
                  const directUrl = generateDirectDownloadUrl(hash)
                  window.location.href = directUrl
                }}
                className="w-full bg-slate-900 hover:bg-slate-800 border border-slate-800 hover:border-slate-700 text-slate-200 py-3 rounded-xl font-semibold flex items-center justify-center gap-2 transition-all duration-200"
              >
                <Download size={16} /> Download Directly (No Stream)
              </button>
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
