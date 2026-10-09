import { useState, useEffect } from 'react'
import { supabase } from '../services/supabase'
import toast from 'react-hot-toast'
import { QRCodeCanvas } from 'qrcode.react'
import {
  Share2, Shield, Lock, Clock, Hash, Zap, Copy, Trash2,
  QrCode, ExternalLink, Download, Check, AlertTriangle, Eye, EyeOff, Sparkles,
  Folder, FileText, Globe, Radio, CheckCircle2, ChevronRight
} from 'lucide-react'
import { generateShareUrl, generateDirectDownloadUrl, formatFileSize } from '../utils/helpers'
import { useBodyScrollLock } from '../hooks/useBodyScrollLock'

function downloadQrImage(canvasId, baseFileName) {
  const canvas = document.getElementById(canvasId)
  if (!canvas) {
    toast.error('Could not export QR Code image')
    return
  }
  const url = canvas.toDataURL('image/png')
  const a = document.createElement('a')
  a.href = url
  a.download = `${(baseFileName || 'share_file').replace(/[^a-zA-Z0-9_-]/g, '_')}_qrcode.png`
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  toast.success('QR Code image downloaded!')
}

export default function ShareModal({ file, sharingEnabled, onClose, onFileUpdated }) {
  useBodyScrollLock(true)
  const [activeTab, setActiveTab] = useState('direct') // 'direct' | 'custom'
  const [showQr, setShowQr] = useState(false)
  const [activeCustomQrId, setActiveCustomQrId] = useState(null)
  const [copiedLink, setCopiedLink] = useState('')

  // Custom link creation form state
  const [pin, setPin] = useState('')
  const [showPin, setShowPin] = useState(false)
  const [expiryDays, setExpiryDays] = useState('none') // '1h' | '1d' | '7d' | '30d' | 'none'
  const [maxDownloads, setMaxDownloads] = useState('')
  const [isOneTime, setIsOneTime] = useState(false)
  const [label, setLabel] = useState('')
  const [creating, setCreating] = useState(false)

  // Custom links list state
  const [customLinks, setCustomLinks] = useState([])
  const [loadingCustomLinks, setLoadingCustomLinks] = useState(false)

  useEffect(() => {
    if (file?.id && activeTab === 'custom') {
      loadCustomLinks()

      // Realtime subscription to live update download count and statuses
      const channel = supabase
        .channel(`custom_links_sync_${file.id}`)
        .on(
          'postgres_changes',
          {
            event: '*',
            schema: 'public',
            table: 'custom_share_links',
            filter: `file_id=eq.${file.id}`
          },
          () => {
            loadCustomLinks()
          }
        )
        .subscribe()

      return () => {
        supabase.removeChannel(channel)
      }
    }
  }, [file?.id, activeTab])

  async function loadCustomLinks() {
    setLoadingCustomLinks(true)
    try {
      const { data, error } = await supabase
        .from('custom_share_links')
        .select('*')
        .eq('file_id', file.id)
        .order('created_at', { ascending: false })

      if (error) throw error
      setCustomLinks(data || [])
    } catch (err) {
      console.error('Failed to load custom links:', err)
    } finally {
      setLoadingCustomLinks(false)
    }
  }

  function copyToClipboard(text, id) {
    navigator.clipboard.writeText(text)
    setCopiedLink(id)
    toast.success('Link copied to clipboard!')
    setTimeout(() => setCopiedLink(''), 2000)
  }

  async function handleCreateCustomLink(e) {
    e.preventDefault()
    if (!sharingEnabled) {
      toast.error('Sharing has been disabled by administrator.')
      return
    }

    setCreating(true)
    try {
      const customHash = 'sec_' + crypto.randomUUID().replace(/-/g, '').substring(0, 14)
      let expiresAt = null
      if (expiryDays === '1h') {
        expiresAt = new Date(Date.now() + 60 * 60 * 1000).toISOString()
      } else if (expiryDays === '1d') {
        expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
      } else if (expiryDays === '7d') {
        expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString()
      } else if (expiryDays === '30d') {
        expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString()
      }

      const calculatedMaxDownloads = isOneTime ? 1 : (maxDownloads ? parseInt(maxDownloads, 10) : null)

      const { error } = await supabase
        .from('custom_share_links')
        .insert({
          file_id: file.id,
          user_id: file.user_id,
          custom_share_hash: customHash,
          pin_code: pin.trim() || null,
          expires_at: expiresAt,
          max_downloads: calculatedMaxDownloads,
          is_one_time: isOneTime,
          label: label.trim() || null,
          is_active: true
        })

      if (error) throw error
      toast.success('Protected link created successfully!')
      setPin('')
      setExpiryDays('none')
      setMaxDownloads('')
      setIsOneTime(false)
      setLabel('')
      loadCustomLinks()
    } catch (err) {
      toast.error('Failed to create protected link: ' + err.message)
    } finally {
      setCreating(false)
    }
  }

  async function handleDeleteCustomLink(linkId) {
    try {
      const { error } = await supabase
        .from('custom_share_links')
        .delete()
        .eq('id', linkId)

      if (error) throw error
      toast.success('Link deleted')
      setCustomLinks(prev => prev.filter(l => l.id !== linkId))
    } catch (err) {
      toast.error('Failed to delete: ' + err.message)
    }
  }

  async function handleToggleStatus() {
    if (!sharingEnabled && file.sharing_status === 'private') {
      toast.error('Sharing has been disabled by the administrator.')
      return
    }
    const newStatus = file.sharing_status === 'public' ? 'private' : 'public'
    try {
      const { error } = await supabase
        .from('shared_files')
        .update({ sharing_status: newStatus })
        .eq('id', file.id)

      if (error) throw error
      const updated = { ...file, sharing_status: newStatus }
      onFileUpdated?.(updated)
      toast.success(`Main link is now ${newStatus}`)
    } catch (err) {
      toast.error('Failed to update: ' + err.message)
    }
  }

  async function handleGenerateMainLink() {
    try {
      const newHash = crypto.randomUUID().replace(/-/g, '').substring(0, 12)
      const { error } = await supabase
        .from('shared_files')
        .update({ unique_share_hash: newHash, sharing_status: 'public' })
        .eq('id', file.id)

      if (error) throw error
      const updated = { ...file, unique_share_hash: newHash, sharing_status: 'public' }
      onFileUpdated?.(updated)
      toast.success('Share link generated!')
    } catch (err) {
      toast.error('Failed to generate link: ' + err.message)
    }
  }

  const webShareUrl = file?.unique_share_hash ? generateShareUrl(file.unique_share_hash) : ''
  const directDownloadUrl = file?.unique_share_hash ? generateDirectDownloadUrl(file.unique_share_hash, file.is_folder, file.file_size) : ''

  return (
    <div className="fixed inset-0 bg-black/70 backdrop-blur-md z-50 flex items-center justify-center p-3 sm:p-4 animate-fade-in">
      <div className="bg-dark-700/95 border border-dark-400/80 rounded-3xl shadow-[0_25px_60px_-15px_rgba(0,0,0,0.7)] w-full max-w-xl max-h-[92vh] flex flex-col overflow-hidden backdrop-blur-xl transition-all">
        
        {/* Modern Header */}
        <div className="relative px-6 pt-5 pb-4 border-b border-dark-400/60 bg-gradient-to-b from-dark-600/50 to-transparent">
          <div className="flex items-center justify-between gap-3">
            <div className="flex items-center gap-3 min-w-0">
              <div className="w-11 h-11 rounded-2xl bg-gradient-to-tr from-primary-600/30 via-primary-500/20 to-indigo-500/10 border border-primary-500/30 flex items-center justify-center text-primary-400 shrink-0 shadow-inner">
                {file.is_folder ? <Folder size={22} className="text-amber-400" /> : <Share2 size={22} className="text-primary-400" />}
              </div>
              <div className="min-w-0">
                <div className="flex items-center gap-2">
                  <h3 className="font-semibold text-gray-100 text-base sm:text-lg font-['Space_Grotesk'] tracking-tight truncate">
                    {file.is_folder ? 'Share Folder' : 'Share File'}
                  </h3>
                  {file.file_size ? (
                    <span className="text-[11px] font-medium px-2 py-0.5 rounded-full bg-dark-500 text-gray-400 border border-dark-400/50 shrink-0">
                      {formatFileSize(file.file_size)}
                    </span>
                  ) : null}
                </div>
                <p className="text-xs text-gray-400 truncate mt-0.5" title={file.file_name}>
                  {file.file_name}
                </p>
              </div>
            </div>

            <button
              onClick={onClose}
              className="w-8 h-8 rounded-full bg-dark-500/60 hover:bg-dark-500 text-gray-400 hover:text-gray-100 flex items-center justify-center transition-all border border-dark-400/40 hover:scale-105 active:scale-95"
            >
              ✕
            </button>
          </div>

          {/* Segmented Tab Pill Bar */}
          <div className="flex p-1 bg-dark-800/80 rounded-2xl mt-4 border border-dark-500/80 shadow-inner">
            <button
              onClick={() => setActiveTab('direct')}
              className={`flex-1 flex items-center justify-center gap-2 py-2 px-3 rounded-xl text-xs font-semibold transition-all duration-200 ${
                activeTab === 'direct'
                  ? 'bg-gradient-to-r from-primary-600 to-indigo-600 text-white shadow-md shadow-primary-500/25'
                  : 'text-gray-400 hover:text-gray-200 hover:bg-white/5'
              }`}
            >
              <Globe size={14} /> Permanent & CDN Links
            </button>
            <button
              onClick={() => setActiveTab('custom')}
              className={`flex-1 flex items-center justify-center gap-2 py-2 px-3 rounded-xl text-xs font-semibold transition-all duration-200 ${
                activeTab === 'custom'
                  ? 'bg-gradient-to-r from-primary-600 to-indigo-600 text-white shadow-md shadow-primary-500/25'
                  : 'text-gray-400 hover:text-gray-200 hover:bg-white/5'
              }`}
            >
              <Shield size={14} /> PIN & Security Links
            </button>
          </div>
        </div>

        {/* Scrollable Modal Body */}
        <div className="flex-1 overflow-y-auto p-5 space-y-4 custom-scrollbar">
          {activeTab === 'direct' && (
            <>
              {!file.unique_share_hash ? (
                <div className="bg-gradient-to-b from-dark-600/80 to-dark-600/40 border border-dark-400/70 rounded-2xl p-6 text-center space-y-4">
                  <div className="w-14 h-14 bg-primary-500/10 border border-primary-500/20 rounded-2xl flex items-center justify-center mx-auto text-primary-400 shadow-lg shadow-primary-500/10">
                    <Sparkles size={26} className="animate-pulse" />
                  </div>
                  <div>
                    <h4 className="text-sm font-semibold text-gray-100">No Share Link Active Yet</h4>
                    <p className="text-xs text-gray-400 mt-1 max-w-sm mx-auto leading-relaxed">
                      Generate permanent public links for browser preview and direct high-speed streaming.
                    </p>
                  </div>
                  {sharingEnabled ? (
                    <button
                      onClick={handleGenerateMainLink}
                      className="btn-primary py-2.5 px-6 text-xs font-semibold mx-auto flex items-center gap-2 shadow-lg shadow-primary-500/25"
                    >
                      <Share2 size={15} /> Generate Permanent Links
                    </button>
                  ) : (
                    <div className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-xs font-medium">
                      <AlertTriangle size={13} /> Sharing disabled by administrator.
                    </div>
                  )}
                </div>
              ) : (
                <div className="space-y-4">
                  {/* Status & Privacy Banner */}
                  <div className="flex items-center justify-between gap-3 p-3.5 bg-dark-600/70 rounded-2xl border border-dark-400/60 shadow-sm">
                    <div className="flex items-center gap-3">
                      <div className="relative flex items-center justify-center">
                        <span className={`w-3 h-3 rounded-full ${file.sharing_status === 'public' ? 'bg-emerald-400' : 'bg-amber-400'}`} />
                        {file.sharing_status === 'public' && (
                          <span className="absolute w-3 h-3 rounded-full bg-emerald-400/75 animate-ping" />
                        )}
                      </div>
                      <div>
                        <div className="flex items-center gap-1.5">
                          <p className="text-xs font-bold text-gray-200">
                            {file.sharing_status === 'public' ? 'Public (Active)' : 'Private (Paused)'}
                          </p>
                          <span className={`text-[10px] px-1.5 py-0.2 rounded font-semibold ${file.sharing_status === 'public' ? 'bg-emerald-500/15 text-emerald-400' : 'bg-amber-500/15 text-amber-400'}`}>
                            {file.sharing_status === 'public' ? 'LIVE' : 'LOCKED'}
                          </span>
                        </div>
                        <p className="text-[11px] text-gray-400">
                          {file.sharing_status === 'public' ? 'Anyone with this link can view & download' : 'Link access is currently blocked'}
                        </p>
                      </div>
                    </div>
                    
                    <button
                      onClick={handleToggleStatus}
                      className={`px-3.5 py-1.5 rounded-xl text-xs font-semibold border transition-all duration-200 active:scale-95 flex items-center gap-1.5 shadow-sm ${
                        file.sharing_status === 'public'
                          ? 'bg-amber-500/10 text-amber-300 border-amber-500/30 hover:bg-amber-500/20'
                          : 'bg-emerald-500/10 text-emerald-300 border-emerald-500/30 hover:bg-emerald-500/20'
                      }`}
                    >
                      {file.sharing_status === 'public' ? <Lock size={12} /> : <Globe size={12} />}
                      {file.sharing_status === 'public' ? 'Make Private' : 'Make Public'}
                    </button>
                  </div>

                  {/* 1. Web Download Page Card */}
                  <div className="p-4 bg-dark-600/50 hover:bg-dark-600/70 border border-dark-400/70 rounded-2xl space-y-2.5 transition-all">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <div className="w-6 h-6 rounded-lg bg-indigo-500/15 text-indigo-400 flex items-center justify-center">
                          <Globe size={13} />
                        </div>
                        <div>
                          <span className="text-xs font-bold text-indigo-300 tracking-wide">
                            Web Download Page
                          </span>
                          <span className="text-[10px] text-gray-400 ml-2 hidden sm:inline">
                            (Preview & portal for all browsers)
                          </span>
                        </div>
                      </div>

                      <button
                        onClick={() => setShowQr(!showQr)}
                        className="text-[11px] text-indigo-400 hover:text-indigo-300 flex items-center gap-1 font-semibold px-2 py-0.5 rounded-lg hover:bg-indigo-500/10 transition-colors"
                      >
                        <QrCode size={13} /> {showQr ? 'Hide QR' : 'Show QR'}
                      </button>
                    </div>

                    {/* Integrated URL bar with action icons */}
                    <div className="flex items-center bg-dark-800/90 border border-dark-400/80 rounded-xl p-1.5 pl-3 focus-within:border-primary-500/80 transition-all">
                      <input
                        type="text"
                        readOnly
                        className="bg-transparent text-xs text-gray-200 select-all font-mono outline-none flex-1 truncate pr-2"
                        value={webShareUrl}
                      />
                      <div className="flex items-center gap-1 shrink-0">
                        <button
                          onClick={() => window.open(webShareUrl, '_blank')}
                          className="p-1.5 text-gray-400 hover:text-indigo-300 hover:bg-dark-500/80 rounded-lg transition-colors"
                          title="Open in new tab"
                        >
                          <ExternalLink size={14} />
                        </button>
                        <button
                          onClick={() => copyToClipboard(webShareUrl, 'web')}
                          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                            copiedLink === 'web'
                              ? 'bg-emerald-600 text-white shadow-sm'
                              : 'bg-primary-600 hover:bg-primary-500 text-white shadow-sm shadow-primary-500/20'
                          }`}
                        >
                          {copiedLink === 'web' ? <Check size={13} /> : <Copy size={13} />}
                          {copiedLink === 'web' ? 'Copied' : 'Copy'}
                        </button>
                      </div>
                    </div>
                  </div>

                  {/* QR Code Canvas Dropdown */}
                  {showQr && (
                    <div className="p-4 bg-white/95 rounded-2xl flex flex-col items-center justify-center gap-3 animate-fade-in shadow-xl border border-gray-200">
                      <div className="p-2 bg-white rounded-xl shadow-sm border border-gray-100">
                        <QRCodeCanvas
                          id="qr-canvas-direct"
                          value={webShareUrl}
                          size={170}
                          level="H"
                          includeMargin={true}
                        />
                      </div>
                      <div className="text-center space-y-2">
                        <p className="text-xs text-gray-700 font-medium">
                          Scan with any phone camera to open download page directly
                        </p>
                        <button
                          type="button"
                          onClick={() => downloadQrImage('qr-canvas-direct', file.file_name)}
                          className="px-4 py-2 bg-slate-900 hover:bg-slate-800 text-white rounded-xl text-xs font-semibold flex items-center justify-center gap-2 mx-auto shadow-md hover:shadow-lg transition-all active:scale-95"
                        >
                          <Download size={13} /> Download QR Code (PNG)
                        </button>
                      </div>
                    </div>
                  )}

                  {/* 2. Direct Stream CDN Link Card */}
                  <div className="p-4 bg-dark-600/50 hover:bg-dark-600/70 border border-dark-400/70 rounded-2xl space-y-2.5 transition-all">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <div className="w-6 h-6 rounded-lg bg-pink-500/15 text-pink-400 flex items-center justify-center">
                          <Zap size={13} />
                        </div>
                        <div>
                          <span className="text-xs font-bold text-pink-300 tracking-wide">
                            Direct High-Speed Stream Link
                          </span>
                          <span className="text-[10px] text-gray-400 ml-2 hidden sm:inline">
                            (For Android updates, scripts & CDN)
                          </span>
                        </div>
                      </div>
                    </div>

                    {/* Integrated URL bar with action icons */}
                    <div className="flex items-center bg-dark-800/90 border border-dark-400/80 rounded-xl p-1.5 pl-3 focus-within:border-pink-500/80 transition-all">
                      <input
                        type="text"
                        readOnly
                        className="bg-transparent text-xs text-gray-200 select-all font-mono outline-none flex-1 truncate pr-2"
                        value={directDownloadUrl}
                      />
                      <div className="flex items-center gap-1 shrink-0">
                        <button
                          onClick={() => copyToClipboard(directDownloadUrl, 'direct')}
                          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                            copiedLink === 'direct'
                              ? 'bg-emerald-600 text-white shadow-sm'
                              : 'bg-pink-600 hover:bg-pink-500 text-white shadow-sm shadow-pink-500/20'
                          }`}
                        >
                          {copiedLink === 'direct' ? <Check size={13} /> : <Copy size={13} />}
                          {copiedLink === 'direct' ? 'Copied' : 'Copy'}
                        </button>
                      </div>
                    </div>
                    <p className="text-[11px] text-gray-400 pl-1">
                      Permanent direct byte stream with instant resume support.
                    </p>
                  </div>
                </div>
              )}
            </>
          )}

          {/* Tab 2: Custom Protected Links */}
          {activeTab === 'custom' && (
            <div className="space-y-4">
              {/* Creator Form Card */}
              <form onSubmit={handleCreateCustomLink} className="p-4.5 bg-dark-600/60 rounded-2xl border border-dark-400/70 space-y-3.5 shadow-sm">
                <div className="flex items-center justify-between pb-2 border-b border-dark-400/40">
                  <h4 className="text-xs font-bold text-indigo-300 uppercase tracking-wider flex items-center gap-1.5">
                    <Shield size={14} className="text-indigo-400" /> Create Protected Link
                  </h4>
                  <span className="text-[10px] text-gray-400">PIN, Expiration & 1-Time options</span>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  {/* Label / Note */}
                  <div>
                    <label className="text-[11px] text-gray-300 font-semibold block mb-1">Recipient / Label</label>
                    <input
                      type="text"
                      placeholder="e.g. Client, Marketing Team"
                      className="input-field text-xs py-2 bg-dark-800/80 border-dark-400/80 rounded-xl"
                      value={label}
                      onChange={e => setLabel(e.target.value)}
                    />
                  </div>

                  {/* PIN Code */}
                  <div>
                    <label className="text-[11px] text-gray-300 font-semibold block mb-1">Password / PIN (Optional)</label>
                    <div className="relative">
                      <input
                        type={showPin ? 'text' : 'password'}
                        placeholder="e.g. 1234 or SecurePass"
                        className="input-field text-xs py-2 pr-9 bg-dark-800/80 border-dark-400/80 rounded-xl font-mono"
                        value={pin}
                        onChange={e => setPin(e.target.value)}
                      />
                      <button
                        type="button"
                        onClick={() => setShowPin(!showPin)}
                        className="absolute right-2.5 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-200 p-0.5"
                      >
                        {showPin ? <EyeOff size={14} /> : <Eye size={14} />}
                      </button>
                    </div>
                  </div>

                  {/* Expiration */}
                  <div>
                    <label className="text-[11px] text-gray-300 font-semibold block mb-1">Link Expiry</label>
                    <select
                      className="input-field text-xs py-2 bg-dark-800/80 border-dark-400/80 rounded-xl"
                      value={expiryDays}
                      onChange={e => setExpiryDays(e.target.value)}
                    >
                      <option value="none">Never Expire</option>
                      <option value="1h">Expire after 1 Hour</option>
                      <option value="1d">Expire after 24 Hours</option>
                      <option value="7d">Expire after 7 Days</option>
                      <option value="30d">Expire after 30 Days</option>
                    </select>
                  </div>

                  {/* Max Downloads */}
                  <div>
                    <label className="text-[11px] text-gray-300 font-semibold block mb-1">
                      Download Limit {isOneTime && <span className="text-amber-400 font-normal">(Locked to 1)</span>}
                    </label>
                    <input
                      type="number"
                      min="1"
                      disabled={isOneTime}
                      placeholder={isOneTime ? '1 (One-Time Only)' : 'Unlimited'}
                      className={`input-field text-xs py-2 bg-dark-800/80 border-dark-400/80 rounded-xl ${isOneTime ? 'opacity-50 cursor-not-allowed' : ''}`}
                      value={isOneTime ? '1' : maxDownloads}
                      onChange={e => setMaxDownloads(e.target.value)}
                    />
                  </div>
                </div>

                {/* One time self destruct toggle */}
                <div className="p-2.5 bg-dark-800/60 rounded-xl border border-dark-400/50 flex items-center justify-between">
                  <label className="flex items-center gap-2.5 cursor-pointer select-none">
                    <input
                      type="checkbox"
                      checked={isOneTime}
                      onChange={e => {
                        const checked = e.target.checked
                        setIsOneTime(checked)
                        if (checked) {
                          setMaxDownloads('1')
                        } else {
                          setMaxDownloads('')
                        }
                      }}
                      className="w-4 h-4 rounded bg-dark-700 border-dark-400 text-primary-500 focus:ring-0 focus:ring-offset-0 cursor-pointer"
                    />
                    <div>
                      <span className="text-xs text-gray-200 font-semibold flex items-center gap-1.5">
                        <Zap size={13} className="text-amber-400" /> One-Time Self-Destruct
                      </span>
                      <p className="text-[10px] text-gray-400">
                        Link permanently deletes right after 1st successful download
                      </p>
                    </div>
                  </label>
                </div>

                <button
                  type="submit"
                  disabled={creating}
                  className="w-full text-xs py-2.5 rounded-xl font-semibold flex items-center justify-center gap-2 bg-gradient-to-r from-primary-600 via-primary-500 to-indigo-600 hover:from-primary-500 hover:to-indigo-500 text-white shadow-md shadow-primary-500/20 active:scale-[0.99] transition-all disabled:opacity-50"
                >
                  <Shield size={14} /> {creating ? 'Generating Link...' : 'Create Secure Link'}
                </button>
              </form>

              {/* Active Protected Links List */}
              <div className="space-y-2.5 pt-1">
                <div className="flex items-center justify-between">
                  <h4 className="text-xs font-bold text-gray-300 uppercase tracking-wider flex items-center gap-1.5">
                    Active Protected Links
                    <span className="px-1.5 py-0.2 rounded-full bg-primary-500/20 text-primary-300 text-[10px] font-bold">
                      {customLinks.length}
                    </span>
                  </h4>
                </div>

                {loadingCustomLinks ? (
                  <div className="text-center py-6">
                    <div className="w-5 h-5 border-2 border-primary-500 border-t-transparent rounded-full animate-spin mx-auto" />
                  </div>
                ) : customLinks.length === 0 ? (
                  <div className="text-center py-6 bg-dark-600/30 rounded-2xl border border-dashed border-dark-400/60 p-4">
                    <Shield size={20} className="text-gray-500 mx-auto mb-1.5" />
                    <p className="text-xs text-gray-400 font-medium">No protected links created yet.</p>
                    <p className="text-[11px] text-gray-500 mt-0.5">Create one above to send PIN-protected or self-destructing links.</p>
                  </div>
                ) : (
                  <div className="space-y-2.5 max-h-60 overflow-y-auto pr-1 custom-scrollbar">
                    {customLinks.map(lnk => {
                      const linkUrl = generateShareUrl(lnk.custom_share_hash)
                      const isExpired = lnk.expires_at && new Date(lnk.expires_at) < new Date()

                      return (
                        <div
                          key={lnk.id}
                          className="p-3.5 bg-dark-600/70 hover:bg-dark-600/90 border border-dark-400/70 rounded-2xl space-y-2.5 transition-all shadow-sm"
                        >
                          <div className="flex items-center justify-between gap-2">
                            <div className="flex items-center gap-1.5 flex-wrap">
                              <span className="text-xs font-bold text-gray-200">
                                {lnk.label || 'Protected Link'}
                              </span>
                              {lnk.pin_code && (
                                <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-indigo-500/15 text-indigo-300 text-[10px] font-semibold border border-indigo-500/25">
                                  <Lock size={10} /> PIN
                                </span>
                              )}
                              {lnk.is_one_time && (
                                <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-amber-500/15 text-amber-300 text-[10px] font-semibold border border-amber-500/25">
                                  <Zap size={10} /> 1-Time
                                </span>
                              )}
                            </div>

                            <button
                              onClick={() => handleDeleteCustomLink(lnk.id)}
                              className="p-1.5 text-gray-400 hover:text-red-400 hover:bg-red-500/15 rounded-lg transition-colors"
                              title="Delete Link"
                            >
                              <Trash2 size={13} />
                            </button>
                          </div>

                          <div className="flex items-center justify-between text-[11px] text-gray-400">
                            <span>Downloads: <strong className="text-gray-200 font-semibold">{lnk.download_count || 0}</strong>{lnk.max_downloads ? ` / ${lnk.max_downloads}` : ' (Unlimited)'}</span>
                            {lnk.expires_at && (
                              <span className={isExpired ? 'text-red-400 font-semibold' : 'text-gray-400'}>
                                {isExpired ? 'Expired' : `Expires: ${new Date(lnk.expires_at).toLocaleDateString()}`}
                              </span>
                            )}
                          </div>

                          {/* Link URL Bar */}
                          <div className="flex items-center bg-dark-800/90 border border-dark-400/70 rounded-xl p-1 pl-2.5">
                            <input
                              type="text"
                              readOnly
                              value={linkUrl}
                              className="bg-transparent text-[11px] text-gray-300 font-mono select-all outline-none flex-1 truncate pr-2"
                            />
                            <div className="flex items-center gap-1 shrink-0">
                              <button
                                type="button"
                                onClick={() => setActiveCustomQrId(activeCustomQrId === lnk.id ? null : lnk.id)}
                                className="p-1 text-indigo-400 hover:text-indigo-300 hover:bg-indigo-500/10 rounded-md transition-colors"
                                title="Show QR Code"
                              >
                                <QrCode size={13} />
                              </button>
                              <button
                                onClick={() => copyToClipboard(linkUrl, lnk.id)}
                                className={`flex items-center gap-1 px-2.5 py-1 rounded-lg text-xs font-semibold transition-all ${
                                  copiedLink === lnk.id
                                    ? 'bg-emerald-600 text-white'
                                    : 'bg-dark-500 hover:bg-dark-400 text-gray-200 border border-dark-300/60'
                                }`}
                              >
                                {copiedLink === lnk.id ? <Check size={12} /> : <Copy size={12} />}
                                {copiedLink === lnk.id ? 'Copied' : 'Copy'}
                              </button>
                            </div>
                          </div>

                          {/* Expandable QR for Custom Link */}
                          {activeCustomQrId === lnk.id && (
                            <div className="p-3.5 bg-white/95 rounded-xl flex flex-col items-center justify-center gap-2 animate-fade-in shadow-inner border border-gray-200 mt-2">
                              <QRCodeCanvas
                                id={`qr-canvas-custom-${lnk.id}`}
                                value={linkUrl}
                                size={140}
                                level="H"
                                includeMargin={true}
                              />
                              <button
                                type="button"
                                onClick={() => downloadQrImage(`qr-canvas-custom-${lnk.id}`, `${file.file_name}_${lnk.label || 'link'}`)}
                                className="px-3 py-1.5 bg-slate-900 hover:bg-slate-800 text-white rounded-lg text-[11px] font-semibold flex items-center gap-1.5 shadow"
                              >
                                <Download size={12} /> Download QR (PNG)
                              </button>
                            </div>
                          )}
                        </div>
                      )
                    })}
                  </div>
                )}
              </div>
            </div>
          )}
        </div>

        {/* Modal Footer */}
        <div className="px-6 py-3.5 border-t border-dark-400/60 bg-dark-800/40 flex justify-end">
          <button
            className="px-5 py-2 rounded-xl text-xs font-semibold bg-dark-500 hover:bg-dark-400 text-gray-200 border border-dark-300/60 transition-all active:scale-95 shadow-sm"
            onClick={onClose}
          >
            Done
          </button>
        </div>

      </div>
    </div>
  )
}
