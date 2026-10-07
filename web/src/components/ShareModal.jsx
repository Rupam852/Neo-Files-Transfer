import { useState, useEffect } from 'react'
import { supabase } from '../services/supabase'
import toast from 'react-hot-toast'
import { QRCodeSVG } from 'qrcode.react'
import {
  Share2, Shield, Lock, Clock, Hash, Zap, Copy, Trash2,
  QrCode, ExternalLink, Download, Check, AlertTriangle, Eye, EyeOff
} from 'lucide-react'
import { generateShareUrl, generateDirectDownloadUrl } from '../utils/helpers'

export default function ShareModal({ file, sharingEnabled, onClose, onFileUpdated }) {
  const [activeTab, setActiveTab] = useState('direct') // 'direct' | 'custom'
  const [showQr, setShowQr] = useState(false)
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

      const { error } = await supabase
        .from('custom_share_links')
        .insert({
          file_id: file.id,
          user_id: file.user_id,
          custom_share_hash: customHash,
          pin_code: pin.trim() || null,
          expires_at: expiresAt,
          max_downloads: maxDownloads ? parseInt(maxDownloads, 10) : null,
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
    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-dark-600 border border-dark-400 rounded-2xl shadow-2xl p-6 w-full max-w-xl max-h-[90vh] flex flex-col animate-scale-in">
        
        {/* Header */}
        <div className="flex items-start justify-between gap-4 pb-3 border-b border-dark-400">
          <div>
            <h3 className="font-semibold text-gray-100 text-lg font-['Space_Grotesk'] flex items-center gap-2">
              <Share2 size={20} className="text-primary-400" />
              {file.is_folder ? 'Share Folder' : 'Share File'}
            </h3>
            <p className="text-xs text-gray-400 truncate max-w-md mt-0.5">{file.file_name}</p>
          </div>
          <button
            onClick={onClose}
            className="p-1 text-gray-400 hover:text-gray-200 hover:bg-dark-500 rounded-lg"
          >
            ✕
          </button>
        </div>

        {/* Tab Navigation */}
        <div className="flex gap-2 p-1 bg-dark-700/80 rounded-xl my-4 border border-dark-500">
          <button
            onClick={() => setActiveTab('direct')}
            className={`flex-1 flex items-center justify-center gap-2 py-2 px-3 rounded-lg text-xs font-semibold transition-all ${
              activeTab === 'direct'
                ? 'bg-primary-500 text-white shadow-lg shadow-primary-500/20'
                : 'text-gray-400 hover:text-gray-200'
            }`}
          >
            <Share2 size={14} /> Permanent Link & QR
          </button>
          <button
            onClick={() => setActiveTab('custom')}
            className={`flex-1 flex items-center justify-center gap-2 py-2 px-3 rounded-lg text-xs font-semibold transition-all ${
              activeTab === 'custom'
                ? 'bg-primary-500 text-white shadow-lg shadow-primary-500/20'
                : 'text-gray-400 hover:text-gray-200'
            }`}
          >
            <Shield size={14} /> PIN & Security Links
          </button>
        </div>

        {/* Tab 1: Direct Permanent Links */}
        <div className="flex-1 overflow-y-auto space-y-4 pr-1">
          {activeTab === 'direct' && (
            <>
              {!file.unique_share_hash ? (
                <div className="bg-dark-500 border border-dark-400 rounded-xl p-5 text-center space-y-3">
                  <div className="w-12 h-12 bg-primary-500/10 border border-primary-500/20 rounded-xl flex items-center justify-center mx-auto text-primary-400">
                    <Share2 size={22} />
                  </div>
                  <div>
                    <p className="text-sm font-semibold text-gray-200">No share link generated yet</p>
                    <p className="text-xs text-gray-400 mt-1">
                      Generate a permanent direct link. This link will never change and is safe for in-app updates.
                    </p>
                  </div>
                  {sharingEnabled ? (
                    <button
                      onClick={handleGenerateMainLink}
                      className="btn-primary py-2.5 px-6 text-xs font-semibold mx-auto"
                    >
                      Generate Share Links
                    </button>
                  ) : (
                    <p className="text-xs text-red-400 font-medium">Sharing disabled by administrator.</p>
                  )}
                </div>
              ) : (
                <div className="space-y-4">
                  {/* Status & Make Public/Private */}
                  <div className="flex items-center justify-between gap-3 p-3 bg-dark-500/60 rounded-xl border border-dark-400/80">
                    <div className="flex items-center gap-2">
                      <span className={`w-2.5 h-2.5 rounded-full ${file.sharing_status === 'public' ? 'bg-emerald-400 animate-pulse' : 'bg-amber-400'}`} />
                      <div>
                        <p className="text-xs font-semibold text-gray-200">
                          {file.sharing_status === 'public' ? 'Public (Active)' : 'Private (Blocked)'}
                        </p>
                        <p className="text-[11px] text-gray-400">
                          {file.sharing_status === 'public' ? 'Anyone with this link can download' : 'Link is paused'}
                        </p>
                      </div>
                    </div>
                    <button
                      onClick={handleToggleStatus}
                      className={`px-3 py-1.5 rounded-lg text-xs font-semibold border transition-all ${
                        file.sharing_status === 'public'
                          ? 'bg-amber-500/10 text-amber-400 border-amber-500/20 hover:bg-amber-500/20'
                          : 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20 hover:bg-emerald-500/20'
                      }`}
                    >
                      {file.sharing_status === 'public' ? '🔒 Make Private' : '🌐 Make Public'}
                    </button>
                  </div>

                  {/* Web Download Page Link */}
                  <div className="space-y-1.5">
                    <div className="flex items-center justify-between">
                      <label className="text-[11px] font-bold text-primary-400 uppercase tracking-wider">
                        Web Download Page
                      </label>
                      <button
                        onClick={() => setShowQr(!showQr)}
                        className="text-xs text-indigo-400 hover:text-indigo-300 flex items-center gap-1 font-medium"
                      >
                        <QrCode size={13} /> {showQr ? 'Hide QR' : 'Show QR Code'}
                      </button>
                    </div>
                    <div className="flex gap-2">
                      <input
                        type="text"
                        readOnly
                        className="input-field text-xs bg-dark-500 py-2 border-dark-400 select-all font-mono"
                        value={webShareUrl}
                      />
                      <button
                        onClick={() => copyToClipboard(webShareUrl, 'web')}
                        className="btn-primary py-2 px-3 text-xs font-semibold shrink-0 flex items-center gap-1"
                      >
                        {copiedLink === 'web' ? <Check size={14} /> : <Copy size={14} />}
                        {copiedLink === 'web' ? 'Copied' : 'Copy'}
                      </button>
                    </div>
                  </div>

                  {/* QR Code view */}
                  {showQr && (
                    <div className="p-4 bg-white rounded-xl flex flex-col items-center justify-center gap-3 animate-fade-in">
                      <QRCodeSVG value={webShareUrl} size={160} level="H" includeMargin={true} />
                      <p className="text-[11px] text-gray-700 font-medium text-center">
                        Scan with your smartphone camera to open download page instantly
                      </p>
                    </div>
                  )}

                  {/* Direct API Download Link */}
                  <div className="space-y-1.5">
                    <label className="block text-[11px] font-bold text-pink-400 uppercase tracking-wider">
                      Direct High-Speed Stream Link (for apps & scripts)
                    </label>
                    <div className="flex gap-2">
                      <input
                        type="text"
                        readOnly
                        className="input-field text-xs bg-dark-500 py-2 border-dark-400 select-all font-mono"
                        value={directDownloadUrl}
                      />
                      <button
                        onClick={() => copyToClipboard(directDownloadUrl, 'direct')}
                        className="btn-primary py-2 px-3 text-xs font-semibold shrink-0 flex items-center gap-1"
                      >
                        {copiedLink === 'direct' ? <Check size={14} /> : <Copy size={14} />}
                        {copiedLink === 'direct' ? 'Copied' : 'Copy'}
                      </button>
                    </div>
                    <p className="text-[11px] text-gray-400">
                      Permanent direct stream. Perfect for Android APK updates or automated download scripts.
                    </p>
                  </div>
                </div>
              )}
            </>
          )}

          {/* Tab 2: Custom Protected Links */}
          {activeTab === 'custom' && (
            <div className="space-y-5">
              {/* Form to create new protected link */}
              <form onSubmit={handleCreateCustomLink} className="p-4 bg-dark-500/70 rounded-xl border border-dark-400/80 space-y-3">
                <h4 className="text-xs font-bold text-indigo-400 uppercase tracking-wider flex items-center gap-1.5">
                  <Shield size={14} /> Create New Protected Link
                </h4>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  {/* Label / Note */}
                  <div>
                    <label className="text-[11px] text-gray-300 font-medium block mb-1">Label / Recipient Name</label>
                    <input
                      type="text"
                      placeholder="e.g. For Client, Office Team"
                      className="input-field text-xs py-1.5"
                      value={label}
                      onChange={e => setLabel(e.target.value)}
                    />
                  </div>

                  {/* PIN Code */}
                  <div>
                    <label className="text-[11px] text-gray-300 font-medium block mb-1">Password / PIN (Optional)</label>
                    <div className="relative">
                      <input
                        type={showPin ? 'text' : 'password'}
                        placeholder="e.g. 1234 or SecretKey"
                        className="input-field text-xs py-1.5 pr-8"
                        value={pin}
                        onChange={e => setPin(e.target.value)}
                      />
                      <button
                        type="button"
                        onClick={() => setShowPin(!showPin)}
                        className="absolute right-2 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-200"
                      >
                        {showPin ? <EyeOff size={13} /> : <Eye size={13} />}
                      </button>
                    </div>
                  </div>

                  {/* Expiration */}
                  <div>
                    <label className="text-[11px] text-gray-300 font-medium block mb-1">Link Expiry Date</label>
                    <select
                      className="input-field text-xs py-1.5"
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
                    <label className="text-[11px] text-gray-300 font-medium block mb-1">Download Limit</label>
                    <input
                      type="number"
                      min="1"
                      placeholder="Unlimited (Leave blank)"
                      className="input-field text-xs py-1.5"
                      value={maxDownloads}
                      onChange={e => setMaxDownloads(e.target.value)}
                    />
                  </div>
                </div>

                {/* One time self destruct toggle */}
                <label className="flex items-center gap-2 cursor-pointer pt-1">
                  <input
                    type="checkbox"
                    checked={isOneTime}
                    onChange={e => setIsOneTime(e.target.checked)}
                    className="rounded bg-dark-600 border-dark-400 text-primary-500 focus:ring-0"
                  />
                  <span className="text-xs text-gray-300 font-medium flex items-center gap-1">
                    <Zap size={13} className="text-amber-400" /> One-Time Download (Self-Destructs after 1st download)
                  </span>
                </label>

                <button
                  type="submit"
                  disabled={creating}
                  className="btn-primary w-full text-xs py-2 font-semibold flex items-center justify-center gap-1.5"
                >
                  <Shield size={14} /> {creating ? 'Generating Link...' : 'Create Secure Link'}
                </button>
              </form>

              {/* List of active custom links */}
              <div className="space-y-2">
                <h4 className="text-xs font-bold text-gray-400 uppercase tracking-wider">
                  Active Protected Links ({customLinks.length})
                </h4>

                {loadingCustomLinks ? (
                  <div className="text-center py-4">
                    <div className="w-5 h-5 border-2 border-primary-500 border-t-transparent rounded-full animate-spin mx-auto" />
                  </div>
                ) : customLinks.length === 0 ? (
                  <p className="text-xs text-gray-500 text-center py-4 bg-dark-500/30 rounded-xl border border-dashed border-dark-400">
                    No custom protected links created yet.
                  </p>
                ) : (
                  <div className="space-y-2 max-h-56 overflow-y-auto pr-1">
                    {customLinks.map(lnk => {
                      const linkUrl = generateShareUrl(lnk.custom_share_hash)
                      const isExpired = lnk.expires_at && new Date(lnk.expires_at) < new Date()
                      const isLimitReached = lnk.max_downloads && lnk.download_count >= lnk.max_downloads

                      return (
                        <div
                          key={lnk.id}
                          className="p-3 bg-dark-500/80 border border-dark-400 rounded-xl space-y-2"
                        >
                          <div className="flex items-center justify-between gap-2">
                            <div className="flex items-center gap-2">
                              <span className="text-xs font-semibold text-gray-200">
                                {lnk.label || 'Custom Share Link'}
                              </span>
                              {lnk.pin_code && (
                                <span className="inline-flex items-center gap-0.5 px-1.5 py-0.5 rounded bg-indigo-500/10 text-indigo-400 text-[10px] font-medium border border-indigo-500/20">
                                  <Lock size={10} /> PIN Protected
                                </span>
                              )}
                              {lnk.is_one_time && (
                                <span className="inline-flex items-center gap-0.5 px-1.5 py-0.5 rounded bg-amber-500/10 text-amber-400 text-[10px] font-medium border border-amber-500/20">
                                  <Zap size={10} /> One-Time
                                </span>
                              )}
                            </div>

                            <button
                              onClick={() => handleDeleteCustomLink(lnk.id)}
                              className="p-1 text-gray-400 hover:text-red-400 hover:bg-red-500/10 rounded"
                              title="Delete Link"
                            >
                              <Trash2 size={13} />
                            </button>
                          </div>

                          <div className="flex items-center justify-between text-[11px] text-gray-400">
                            <span>Downloads: <strong className="text-gray-200">{lnk.download_count || 0}</strong>{lnk.max_downloads ? ` / ${lnk.max_downloads}` : ''}</span>
                            {lnk.expires_at && (
                              <span className={isExpired ? 'text-red-400 font-semibold' : ''}>
                                {isExpired ? 'Expired' : `Expires: ${new Date(lnk.expires_at).toLocaleDateString()}`}
                              </span>
                            )}
                          </div>

                          <div className="flex gap-2 pt-1">
                            <input
                              type="text"
                              readOnly
                              value={linkUrl}
                              className="input-field text-[11px] py-1 bg-dark-600 font-mono select-all flex-1"
                            />
                            <button
                              onClick={() => copyToClipboard(linkUrl, lnk.id)}
                              className="btn-secondary text-xs py-1 px-3 flex items-center gap-1 font-semibold"
                            >
                              {copiedLink === lnk.id ? <Check size={12} /> : <Copy size={12} />}
                              {copiedLink === lnk.id ? 'Copied' : 'Copy'}
                            </button>
                          </div>
                        </div>
                      )
                    })}
                  </div>
                )}
              </div>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="pt-4 border-t border-dark-400 flex justify-end">
          <button className="btn-secondary text-xs py-2 px-4" onClick={onClose}>
            Done
          </button>
        </div>

      </div>
    </div>
  )
}
