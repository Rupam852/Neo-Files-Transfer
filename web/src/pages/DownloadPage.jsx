import { useEffect, useState, useRef } from 'react'
import { useParams, Link } from 'react-router-dom'
import { supabase } from '../services/supabase'
import {
  Download, FileX, ShieldX, AlertTriangle, FileText, Image as ImageIcon, Video, Archive,
  Table, Presentation, File, CheckCircle2, AlertCircle, Folder,
  ArrowDown, Sparkles, RefreshCw, Lock, KeyRound, Play, Eye, EyeOff, Music, ExternalLink, X, QrCode
} from 'lucide-react'
import { QRCodeCanvas } from 'qrcode.react'
import { formatFileSize, getFileIcon, generateDirectDownloadUrl, formatErrorMessage } from '../utils/helpers'
import { useBodyScrollLock } from '../hooks/useBodyScrollLock'

const ICON_MAP = {
  'file-text': FileText,
  'image': ImageIcon,
  'video': Video,
  'archive': Archive,
  'table': Table,
  'presentation': Presentation,
  'file': File,
}

export default function DownloadPage() {
  const { hash } = useParams()
  const [status, setStatus] = useState('loading') // loading, preview, pin_required, expired, limit_reached, completed, denied, notfound, error, maintenance
  const [fileInfo, setFileInfo] = useState(null)
  const [customLinkInfo, setCustomLinkInfo] = useState(null)
  const [pinInput, setPinInput] = useState('')
  const [pinError, setPinError] = useState('')
  const [isVerifyingPin, setIsVerifyingPin] = useState(false)
  const [totalBytes, setTotalBytes] = useState(0)
  const [errorMsg, setErrorMsg] = useState('')
  const [isInitiating, setIsInitiating] = useState(false)
  const [showInAppPreview, setShowInAppPreview] = useState(false)
  const [showQrModal, setShowQrModal] = useState(false)

  useBodyScrollLock(showQrModal)

  useEffect(() => {
    const preconnectUrls = [
      'https://download.neofilestransfer.site',
      'https://api.neofilestransfer.site'
    ]
    const createdLinks = []
    preconnectUrls.forEach(url => {
      const link = document.createElement('link')
      link.rel = 'preconnect'
      link.href = url
      link.crossOrigin = 'anonymous'
      document.head.appendChild(link)
      createdLinks.push(link)

      const dnsLink = document.createElement('link')
      dnsLink.rel = 'dns-prefetch'
      dnsLink.href = url
      document.head.appendChild(dnsLink)
      createdLinks.push(dnsLink)
    })

    return () => {
      createdLinks.forEach(link => {
        try { document.head.removeChild(link) } catch (_) {}
      })
    }
  }, [])

  useEffect(() => {
    async function loadMetadata() {
      try {
        const isCustom = typeof hash === 'string' && hash.startsWith('sec_')

        if (isCustom) {
          // Parallel fetch: custom_share_links and system_settings
          const [linkRes, settingsRes] = await Promise.all([
            supabase
              .from('custom_share_links')
              .select('*')
              .eq('custom_share_hash', hash)
              .maybeSingle(),
            supabase
              .from('system_settings')
              .select('value')
              .eq('key', 'downloads_enabled')
              .maybeSingle()
          ])

          const customLink = linkRes.data
          if (!customLink) {
            setStatus('notfound')
            return
          }

          if (customLink.expires_at && new Date(customLink.expires_at) < new Date()) {
            setStatus('expired')
            return
          }

          if (customLink.max_downloads && customLink.download_count >= customLink.max_downloads) {
            setStatus('limit_reached')
            return
          }

          // Fetch the corresponding file
          const { data: linkedFile } = await supabase
            .from('shared_files')
            .select('id, user_id, file_name, mime_type, sharing_status, current_version_num, file_size, google_drive_file_id, is_folder')
            .eq('id', customLink.file_id)
            .maybeSingle()

          if (!linkedFile) {
            setStatus('notfound')
            return
          }

          setFileInfo(linkedFile)
          setCustomLinkInfo(customLink)
          setTotalBytes(linkedFile.file_size || 0)

          if (customLink.pin_code) {
            setStatus('pin_required')
            return
          }

          if (settingsRes.data && settingsRes.data.value === false) {
            setStatus('maintenance')
            return
          }

          setStatus('preview')
          return
        }

        // Standard link: Parallel fetch file and system_settings
        const [fileRes, settingsRes] = await Promise.all([
          supabase
            .from('shared_files')
            .select('id, user_id, file_name, mime_type, sharing_status, current_version_num, file_size, google_drive_file_id, is_folder')
            .eq('unique_share_hash', hash)
            .maybeSingle(),
          supabase
            .from('system_settings')
            .select('value')
            .eq('key', 'downloads_enabled')
            .maybeSingle()
        ])

        const file = fileRes.data
        if (!file) {
          setStatus('notfound')
          return
        }

        if (file.sharing_status === 'private') {
          setStatus('denied')
          return
        }

        setFileInfo(file)
        setTotalBytes(file.file_size || 0)

        if (settingsRes.data && settingsRes.data.value === false) {
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

  const handleVerifyPin = (e) => {
    if (e) e.preventDefault()
    if (!pinInput.trim()) {
      setPinError('Please enter the 4-digit PIN')
      return
    }

    if (customLinkInfo && customLinkInfo.pin_code === pinInput.trim()) {
      setPinError('')
      setStatus('preview')
    } else {
      setPinError('Incorrect PIN. Access denied.')
    }
  }

  const handleStartDownload = (e) => {
    if (e) e.preventDefault()
    if (!fileInfo || isInitiating) return

    try {
      setIsInitiating(true)
      let downloadUrl = generateDirectDownloadUrl(hash, fileInfo.is_folder, fileInfo.file_size, false)
      if (customLinkInfo && customLinkInfo.pin_code) {
        downloadUrl += `&pin=${encodeURIComponent(customLinkInfo.pin_code)}`
      }

      const link = document.createElement('a')
      link.href = downloadUrl
      if (fileInfo.file_name) {
        link.setAttribute('download', fileInfo.file_name)
      }
      link.style.display = 'none'
      document.body.appendChild(link)
      link.click()
      setTimeout(() => {
        try { document.body.removeChild(link) } catch (_) {}
      }, 1500)

      // Record device info for real-time notification
      const userAgent = typeof navigator !== 'undefined' ? navigator.userAgent : ''
      const isMobile = /mobile|android|iphone|ipad/i.test(userAgent)
      const deviceType = isMobile ? 'Mobile' : 'Desktop'
      const browser = /chrome/i.test(userAgent) ? 'Chrome' : /firefox/i.test(userAgent) ? 'Firefox' : /safari/i.test(userAgent) ? 'Safari' : /edge/i.test(userAgent) ? 'Edge' : 'Browser'
      const os = /android/i.test(userAgent) ? 'Android' : /windows/i.test(userAgent) ? 'Windows' : /mac/i.test(userAgent) ? 'macOS' : /linux/i.test(userAgent) ? 'Linux' : /ios|iphone|ipad/i.test(userAgent) ? 'iOS' : 'OS'

      setTimeout(() => {
        setIsInitiating(false)
        setStatus('completed')
      }, 900)

    } catch (err) {
      console.error('Download error:', err)
      setIsInitiating(false)
      setErrorMsg(formatErrorMessage(err))
      setStatus('error')
    }
  }

  const isAndroidPhone = typeof navigator !== 'undefined' && /android/i.test(navigator.userAgent)
  const isVideo = fileInfo?.mime_type?.startsWith('video/')
  const isAudio = fileInfo?.mime_type?.startsWith('audio/')
  const isImage = fileInfo?.mime_type?.startsWith('image/')
  const isPdf = fileInfo?.mime_type === 'application/pdf' || fileInfo?.file_name?.toLowerCase().endsWith('.pdf')
  const isMediaStreamable = isVideo || isAudio || isImage

  const iconName = getFileIcon(fileInfo?.mime_type)
  const FileIcon = fileInfo?.is_folder ? Folder : (ICON_MAP[iconName] || File)

  const streamUrl = generateDirectDownloadUrl(hash, fileInfo?.is_folder, fileInfo?.file_size, true) + 
    (customLinkInfo?.pin_code ? `&pin=${encodeURIComponent(customLinkInfo.pin_code)}` : '')

  if (status === 'loading') {
    return (
      <div className="min-h-screen flex items-center justify-center bg-[#030712]">
        <div className="text-center space-y-4">
          <div className="w-10 h-10 border-4 border-indigo-500 border-t-transparent rounded-full animate-spin mx-auto" />
          <p className="text-gray-400 text-sm font-medium font-['Space_Grotesk'] tracking-wide">Resolving secure link...</p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen w-full bg-[#030712] text-gray-100 flex items-center justify-center p-4 sm:p-6 lg:p-8 font-['Plus_Jakarta_Sans'] relative overflow-hidden">
      <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Space+Grotesk:wght@500;600;700&display=swap" rel="stylesheet" />

      <div className="absolute top-[-10%] left-[-10%] w-[50%] h-[50%] rounded-full bg-indigo-500/5 blur-[120px] pointer-events-none" />
      <div className="absolute bottom-[-10%] right-[-10%] w-[50%] h-[50%] rounded-full bg-purple-500/5 blur-[120px] pointer-events-none" />

      <div className="w-full max-w-lg bg-slate-950/80 backdrop-blur-3xl border border-slate-900 rounded-3xl p-6 sm:p-8 shadow-2xl relative z-10">
        
        {/* State: PIN Required */}
        {status === 'pin_required' && (
          <div className="space-y-6 text-center">
            <div className="w-16 h-16 bg-indigo-500/10 border border-indigo-500/20 rounded-2xl flex items-center justify-center mx-auto text-indigo-400">
              <Lock size={32} className="animate-pulse" />
            </div>

            <div className="space-y-2">
              <h2 className="text-2xl font-bold text-white font-['Space_Grotesk']">Password Protected</h2>
              <p className="text-sm text-slate-400">This link is protected. Enter the PIN provided by the owner to download.</p>
            </div>

            <form onSubmit={handleVerifyPin} className="space-y-4">
              <div className="relative">
                <input
                  type="password"
                  maxLength={12}
                  value={pinInput}
                  onChange={(e) => {
                    setPinInput(e.target.value)
                    setPinError('')
                  }}
                  placeholder="Enter PIN / Password"
                  className="w-full bg-slate-900/90 border border-slate-800 rounded-xl px-4 py-3.5 text-center text-lg tracking-widest text-white focus:outline-none focus:border-indigo-500 transition-all"
                  autoFocus
                />
              </div>

              {pinError && (
                <p className="text-xs text-red-400 font-medium">{pinError}</p>
              )}

              <button
                type="submit"
                className="w-full py-3.5 rounded-xl font-bold bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-500 hover:to-purple-500 text-white shadow-lg active:scale-[0.98] transition-all cursor-pointer flex items-center justify-center gap-2"
              >
                <KeyRound size={18} /> Unlock & Access File
              </button>
            </form>
          </div>
        )}

        {/* State: Expired */}
        {status === 'expired' && (
          <div className="space-y-6 text-center">
            <div className="w-16 h-16 bg-amber-500/10 border border-amber-500/20 rounded-2xl flex items-center justify-center mx-auto text-amber-400">
              <AlertTriangle size={36} />
            </div>
            <div className="space-y-2">
              <h2 className="text-2xl font-bold text-white font-['Space_Grotesk']">Link Expired</h2>
              <p className="text-sm text-slate-400 px-4">
                This custom download link has reached its expiration time and is no longer accessible.
              </p>
            </div>
          </div>
        )}

        {/* State: Download Limit Reached */}
        {status === 'limit_reached' && (
          <div className="space-y-6 text-center">
            <div className="w-16 h-16 bg-amber-500/10 border border-amber-500/20 rounded-2xl flex items-center justify-center mx-auto text-amber-400">
              <AlertTriangle size={36} />
            </div>
            <div className="space-y-2">
              <h2 className="text-2xl font-bold text-white font-['Space_Grotesk']">Download Limit Reached</h2>
              <p className="text-sm text-slate-400 px-4">
                This share link has reached its maximum allowed number of downloads.
              </p>
            </div>
          </div>
        )}

        {/* State: preview */}
        {status === 'preview' && (
          <div className="space-y-6">
            <div className="text-center space-y-2">
              <div className="inline-flex items-center gap-1.5 px-3 py-1 bg-indigo-500/10 border border-indigo-500/20 text-indigo-400 rounded-full text-xs font-semibold uppercase tracking-wider mb-2">
                <Download size={12} />
                Secure Link Resolved
              </div>
              <h2 className="text-2xl font-bold text-white font-['Space_Grotesk']">Ready to Download</h2>
              <p className="text-sm text-slate-400 text-center">High-speed encrypted cloud transfer ready.</p>
            </div>

            {/* File Info Block */}
            <div className="bg-slate-900/50 border border-slate-900 rounded-2xl p-5 flex items-center justify-between gap-4">
              <div className="flex items-center gap-4 min-w-0">
                <div className="w-14 h-14 bg-indigo-500/10 border border-indigo-500/20 rounded-xl flex items-center justify-center text-indigo-400 flex-shrink-0">
                  <FileIcon size={28} />
                </div>
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-semibold text-white truncate leading-tight mb-1">{fileInfo?.file_name}</p>
                  <p className="text-xs text-slate-400 font-medium">{fileInfo?.is_folder ? 'Folder • Compressed as ZIP' : formatFileSize(totalBytes)}</p>
                </div>
              </div>

              {/* QR Code Action Button */}
              <button
                type="button"
                onClick={() => setShowQrModal(true)}
                className="p-2.5 bg-slate-900 hover:bg-slate-800 border border-slate-800 rounded-xl text-slate-300 hover:text-indigo-400 transition-all flex-shrink-0 cursor-pointer"
                title="Scan QR on Mobile"
              >
                <QrCode size={20} />
              </button>
            </div>

            {/* In-App Stream / Preview Player */}
            {isMediaStreamable && (
              <div className="space-y-2">
                <button
                  type="button"
                  onClick={() => setShowInAppPreview(!showInAppPreview)}
                  className="w-full py-2.5 bg-slate-900/60 hover:bg-slate-900 border border-slate-800 rounded-xl text-xs font-semibold text-indigo-300 flex items-center justify-center gap-2 transition-all cursor-pointer"
                >
                  {showInAppPreview ? <EyeOff size={14} /> : <Eye size={14} />}
                  {showInAppPreview ? 'Hide In-App Stream Player' : 'Stream / Preview In-App'}
                </button>

                {showInAppPreview && (
                  <div className="bg-slate-950 border border-slate-800 rounded-2xl overflow-hidden p-3 animate-fade-in">
                    {isVideo && (
                      <video
                        src={streamUrl}
                        controls
                        playsInline
                        className="w-full max-h-64 rounded-xl bg-black"
                      />
                    )}
                    {isAudio && (
                      <div className="p-2">
                        <audio src={streamUrl} controls className="w-full" />
                      </div>
                    )}
                    {isImage && (
                      <img
                        src={streamUrl}
                        alt={fileInfo?.file_name}
                        className="w-full max-h-64 object-contain rounded-xl"
                      />
                    )}
                  </div>
                )}
              </div>
            )}

            {/* APK Security Info Banner */}
            {fileInfo?.file_name?.toLowerCase().endsWith('.apk') && isAndroidPhone && (
              <div className="bg-amber-500/10 border border-amber-500/20 rounded-2xl p-4 flex gap-3 text-left">
                <AlertTriangle className="text-amber-500 flex-shrink-0 mt-0.5" size={18} />
                <div className="space-y-1">
                  <p className="text-xs font-semibold text-amber-400">Android APK File</p>
                  <p className="text-[11px] text-slate-400 leading-relaxed">
                    Browser may ask: <strong>"File might be harmful. Download anyway?"</strong>. Tap <strong>"Download anyway"</strong> to proceed.
                  </p>
                </div>
              </div>
            )}

            <button
              type="button"
              disabled={isInitiating}
              onClick={handleStartDownload}
              className={`w-full py-3.5 rounded-xl font-bold flex items-center justify-center gap-2 transition-all duration-300 text-center cursor-pointer ${
                isInitiating
                  ? 'bg-indigo-600/70 text-white/90 cursor-not-allowed shadow-none'
                  : 'bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-500 hover:to-purple-500 text-white hover:shadow-[0_0_20px_rgba(99,102,241,0.4)] active:scale-[0.98]'
              }`}
            >
              {isInitiating ? (
                <div className="flex items-center justify-center gap-2.5">
                  <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                  <span>Connecting to Cloud Node...</span>
                </div>
              ) : (
                <>
                  <Download size={18} /> Download Now
                </>
              )}
            </button>
            
            <p className="text-center text-xs text-slate-500">
              Files are transferred securely with TLS encryption.
            </p>
          </div>
        )}

        {/* State: completed */}
        {status === 'completed' && (
          <div className="space-y-6 text-center">
            <div className="w-16 h-16 bg-emerald-500/10 border border-emerald-500/20 rounded-2xl flex items-center justify-center mx-auto text-emerald-400">
              <CheckCircle2 size={36} className="animate-scale-in" />
            </div>

            <div className="space-y-2">
              <div className="inline-flex items-center gap-1.5 px-3 py-1 bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 rounded-full text-xs font-semibold uppercase tracking-wider mb-1">
                <Sparkles size={12} />
                Download Initiated
              </div>
              <h2 className="text-2xl font-bold text-white font-['Space_Grotesk']">Download Started!</h2>
              <p className="text-sm text-slate-400 truncate max-w-xs mx-auto">{fileInfo?.file_name}</p>
            </div>

            {fileInfo?.file_name?.toLowerCase().endsWith('.apk') && isAndroidPhone ? (
              <div className="space-y-4">
                <div className="bg-amber-500/10 border border-amber-500/30 rounded-2xl p-4 text-left space-y-2 relative overflow-hidden">
                  <div className="flex items-center gap-2 text-amber-400 font-bold text-sm">
                    <AlertTriangle size={18} className="text-amber-400 flex-shrink-0" />
                    <span>Action Required in Browser:</span>
                  </div>
                  <p className="text-xs text-slate-300 leading-relaxed">
                    Look at the bottom of your phone screen. Chrome may ask: <br />
                    <strong className="text-amber-300">"File might be harmful. Download anyway?"</strong>
                  </p>
                  <div className="bg-slate-950/70 border border-amber-500/20 rounded-xl p-2.5 flex items-center justify-between text-xs">
                    <span className="text-slate-400">Tap to confirm:</span>
                    <span className="font-bold text-emerald-400 bg-emerald-500/15 px-2.5 py-1 rounded-md border border-emerald-500/30">
                      Download anyway
                    </span>
                  </div>
                </div>

                <div className="flex items-center justify-center gap-2 text-xs text-slate-400 animate-bounce">
                  <ArrowDown size={16} className="text-indigo-400" />
                  <span>Look at bottom of screen to confirm</span>
                  <ArrowDown size={16} className="text-indigo-400" />
                </div>
              </div>
            ) : (
              <div className="bg-slate-900/40 rounded-xl p-4 text-sm text-slate-300 leading-relaxed border border-slate-900">
                Your file download has started. Check your browser's download manager or Downloads folder.
              </div>
            )}

            <div className="pt-2">
              <button
                type="button"
                disabled={isInitiating}
                onClick={handleStartDownload}
                className={`w-full py-3 rounded-xl font-semibold flex items-center justify-center gap-2 transition-all cursor-pointer ${
                  isInitiating
                    ? 'bg-slate-800/80 text-slate-300 border border-slate-700/60 cursor-not-allowed shadow-inner'
                    : 'bg-slate-900 hover:bg-slate-800 border border-slate-800 hover:border-slate-700 text-slate-200 active:scale-[0.98]'
                }`}
              >
                {isInitiating ? (
                  <div className="flex items-center justify-center gap-2.5">
                    <div className="w-4 h-4 border-2 border-indigo-400/30 border-t-indigo-400 rounded-full animate-spin" />
                    <span className="text-indigo-300 font-medium">Retrying Download...</span>
                  </div>
                ) : (
                  <>
                    <RefreshCw size={16} /> Retry Download / Re-download
                  </>
                )}
              </button>
            </div>
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
                This file sharing configuration is private.
              </p>
            </div>
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
                type="button"
                disabled={isInitiating}
                onClick={handleStartDownload}
                className="w-full py-3 rounded-xl font-semibold btn-primary active:scale-[0.98] cursor-pointer"
              >
                <RefreshCw size={16} /> Retry Download
              </button>
            </div>
          </div>
        )}

      </div>

      {/* QR Code Modal */}
      {showQrModal && (
        <div className="fixed inset-0 bg-black/70 backdrop-blur-sm z-50 flex items-center justify-center p-4 animate-fade-in">
          <div className="bg-slate-950 border border-slate-800 rounded-3xl p-6 max-w-xs w-full text-center space-y-4 shadow-2xl relative">
            <button
              type="button"
              onClick={() => setShowQrModal(false)}
              className="absolute top-4 right-4 text-slate-400 hover:text-white p-1 rounded-lg hover:bg-slate-900 transition-colors cursor-pointer"
            >
              <X size={18} />
            </button>

            <div className="space-y-1 pt-1">
              <h3 className="font-bold text-white text-base font-['Space_Grotesk']">Scan on Phone</h3>
              <p className="text-xs text-slate-400">Open mobile camera to scan</p>
            </div>

            <div className="p-3 bg-white rounded-2xl inline-block mx-auto shadow-inner">
              <QRCodeCanvas
                value={typeof window !== 'undefined' ? window.location.href : ''}
                size={180}
                level="H"
                includeMargin={false}
              />
            </div>

            <button
              type="button"
              onClick={() => setShowQrModal(false)}
              className="w-full py-2.5 bg-slate-900 hover:bg-slate-800 border border-slate-800 text-slate-200 text-xs font-semibold rounded-xl transition-all cursor-pointer"
            >
              Close
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
