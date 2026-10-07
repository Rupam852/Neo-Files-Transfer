import { useState } from 'react'
import { supabase } from '../services/supabase'
import toast from 'react-hot-toast'
import { Copy, Check, RefreshCw, Save, Smartphone, Code2, X, ExternalLink, Sparkles } from 'lucide-react'
import { generateVersionApiUrl, generateDirectDownloadUrl } from '../utils/helpers'
import { useBodyScrollLock } from '../hooks/useBodyScrollLock'

export default function VersionApiModal({ file, onClose, onFileUpdated }) {
  useBodyScrollLock(true)
  const [version, setVersion] = useState(file.apk_version || 'v1.0.1')
  const [description, setDescription] = useState(file.apk_description || '')
  const [apiKey, setApiKey] = useState(file.version_api_key || '')
  const [copied, setCopied] = useState(false)
  const [jsonCopied, setJsonCopied] = useState(false)
  const [saving, setSaving] = useState(false)
  const [regenerating, setRegenerating] = useState(false)

  const apiUrl = generateVersionApiUrl(apiKey)

  const handleCopyLink = () => {
    if (!apiUrl) return
    navigator.clipboard.writeText(apiUrl)
    setCopied(true)
    toast.success('Version API link copied!')
    setTimeout(() => setCopied(false), 2000)
  }

  const handleSaveVersion = async () => {
    if (!version.trim()) {
      toast.error('Please enter a valid version string')
      return
    }

    setSaving(true)
    try {
      const formattedVersion = version.trim().startsWith('v') ? version.trim() : `v${version.trim()}`

      const { error } = await supabase
        .from('shared_files')
        .update({
          apk_version: formattedVersion,
          apk_description: description,
          modified_at: new Date().toISOString()
        })
        .eq('id', file.id)

      if (error) throw error

      setVersion(formattedVersion)
      toast.success(`APK version and release notes saved!`)
      if (onFileUpdated) {
        onFileUpdated({ ...file, apk_version: formattedVersion, apk_description: description })
      }
    } catch (err) {
      console.error('Failed to update version:', err)
      toast.error('Failed to save version: ' + (err.message || 'Error'))
    } finally {
      setSaving(false)
    }
  }

  const handleRegenerateKey = async () => {
    setRegenerating(true)
    try {
      const newKey = `apk_${crypto.randomUUID().replace(/-/g, '').substring(0, 16)}`
      const formattedVersion = version.trim() || 'v1.0.1'

      const { error } = await supabase
        .from('shared_files')
        .update({
          version_api_key: newKey,
          apk_version: formattedVersion,
          apk_description: description,
          modified_at: new Date().toISOString()
        })
        .eq('id', file.id)

      if (error) throw error

      setApiKey(newKey)
      toast.success('New Version API Link generated!')
      if (onFileUpdated) {
        onFileUpdated({ ...file, version_api_key: newKey, apk_version: formattedVersion, apk_description: description })
      }
    } catch (err) {
      console.error('Failed to regenerate key:', err)
      toast.error('Failed to generate key: ' + err.message)
    } finally {
      setRegenerating(false)
    }
  }

  const directDownloadUrl = file.unique_share_hash
    ? generateDirectDownloadUrl(file.unique_share_hash, false, file.file_size)
    : `${(import.meta.env.VITE_CF_WORKER_URL || 'https://neo-files-download.rupambairagya08.workers.dev').replace(/\/$/, '')}?hash=apk_share_link`

  const webDownloadUrl = file.unique_share_hash
    ? `${window.location.origin}/download/${file.unique_share_hash}`
    : `${window.location.origin}/download/apk_share_link`

  const sampleJsonObject = {
    status: "success",
    version: version || "v1.0.1",
    description: description || "",
    file_name: file.file_name,
    file_size: file.file_size || 0,
    download_url: directDownloadUrl,
    web_url: webDownloadUrl,
    sharing_status: file.sharing_status || 'public',
    created_at: file.created_at || new Date().toISOString(),
    updated_at: file.modified_at || file.created_at || new Date().toISOString()
  }

  const sampleJsonResponse = JSON.stringify(sampleJsonObject, null, 2)

  const handleCopyJson = () => {
    navigator.clipboard.writeText(sampleJsonResponse)
    setJsonCopied(true)
    toast.success('JSON response copied!')
    setTimeout(() => setJsonCopied(false), 2000)
  }


  const [previewMode, setPreviewMode] = useState('edit') // 'edit' | 'preview'

  const handleFormatBullets = () => {
    if (!description) return
    const formatted = description
      .replace(/^[\t ]*[\*\-]\s+/gm, '• ')
      .replace(/^[\t ]*(\d+)[\)\.]\s+/gm, '$1. ')
    setDescription(formatted)
    toast.success('Cleaned & formatted bullet points! ✨')
  }

  const handleDescriptionPaste = (e) => {
    const pastedText = e.clipboardData?.getData('text')
    if (pastedText && (pastedText.includes('* ') || pastedText.includes('- '))) {
      // Auto clean bullet points if user pastes markdown with * or -
      e.preventDefault()
      const formatted = pastedText
        .replace(/^[\t ]*[\*\-]\s+/gm, '• ')
        .replace(/^[\t ]*(\d+)[\)\.]\s+/gm, '$1. ')
      
      const textarea = e.target
      const start = textarea.selectionStart
      const end = textarea.selectionEnd
      const currentVal = textarea.value
      const newVal = currentVal.substring(0, start) + formatted + currentVal.substring(end)
      setDescription(newVal)
      toast.success('Pasted & auto-formatted bullets to •')
    }
  }

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4 animate-fade-in" onClick={onClose}>
      <div
        className="bg-dark-600 border border-dark-400 rounded-2xl w-full max-w-lg shadow-2xl overflow-hidden flex flex-col max-h-[90vh] animate-scale-in"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Modal Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-dark-400 bg-dark-700/50">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-emerald-500/10 border border-emerald-500/20 rounded-xl flex items-center justify-center text-emerald-400">
              <Smartphone size={20} />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h3 className="font-bold text-gray-100 font-['Space_Grotesk'] text-lg">
                  Get Version API
                </h3>
                <span className="px-2 py-0.5 text-[10px] font-extrabold uppercase tracking-wider rounded-md bg-emerald-500/20 text-emerald-300 border border-emerald-500/30">
                  APK
                </span>
              </div>
              <p className="text-xs text-gray-400 truncate max-w-xs">{file.file_name}</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-2 text-gray-400 hover:text-gray-200 rounded-lg hover:bg-dark-500 transition-colors"
          >
            <X size={18} />
          </button>
        </div>

        {/* Modal Content */}
        <div className="p-6 space-y-5 overflow-y-auto">
          {/* Editable Version Input Section */}
          <div className="space-y-1.5">
            <label className="block text-xs font-bold text-gray-300 uppercase tracking-wider">
              APK Version (Editable)
            </label>
            <input
              type="text"
              className="input-field w-full font-mono text-sm font-semibold text-emerald-400 bg-dark-700 border-dark-400"
              value={version}
              onChange={(e) => setVersion(e.target.value)}
              placeholder="e.g. v1.0.1"
            />
            <p className="text-[11px] text-gray-400">
              Default for new APKs is <code className="text-emerald-400">v1.0.1</code>.
            </p>
          </div>

          {/* Editable Release Notes / Description Section */}
          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <label className="block text-xs font-bold text-gray-300 uppercase tracking-wider">
                Release Notes / Description
              </label>
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={handleFormatBullets}
                  className="px-2 py-1 bg-indigo-500/10 hover:bg-indigo-500/20 text-indigo-400 border border-indigo-500/30 rounded-md text-[11px] font-semibold flex items-center gap-1 transition-all"
                  title="Convert * or - into clean bullet points"
                >
                  <Sparkles size={12} /> Format Bullets (•)
                </button>
                <div className="flex bg-dark-700 rounded-lg p-0.5 border border-dark-400">
                  <button
                    type="button"
                    onClick={() => setPreviewMode('edit')}
                    className={`px-2 py-0.5 rounded text-[11px] font-semibold transition-all ${
                      previewMode === 'edit' ? 'bg-primary-600 text-white shadow-sm' : 'text-gray-400 hover:text-gray-200'
                    }`}
                  >
                    Edit
                  </button>
                  <button
                    type="button"
                    onClick={() => setPreviewMode('preview')}
                    className={`px-2 py-0.5 rounded text-[11px] font-semibold transition-all ${
                      previewMode === 'preview' ? 'bg-primary-600 text-white shadow-sm' : 'text-gray-400 hover:text-gray-200'
                    }`}
                  >
                    Preview
                  </button>
                </div>
              </div>
            </div>

            {previewMode === 'edit' ? (
              <textarea
                rows={5}
                className="input-field w-full text-xs font-sans text-gray-100 bg-dark-700 border-dark-400 focus:border-emerald-500 p-3 leading-relaxed resize-y font-mono"
                value={description}
                onPaste={handleDescriptionPaste}
                onChange={(e) => setDescription(e.target.value)}
                placeholder={"🚀 What's new in this update:\n• Ultra-fast download engine\n• Real-time notifications\n• Light and dark theme\n• Bug fixes and speed improvements"}
              />
            ) : (
              <div className="w-full min-h-[110px] p-3.5 bg-dark-700/80 border border-dark-400 rounded-xl space-y-1.5 text-xs text-gray-200 leading-relaxed font-sans">
                {description.trim() ? (
                  description.split('\n').map((line, idx) => {
                    const trimmed = line.trim()
                    if (trimmed.startsWith('•') || trimmed.startsWith('*') || trimmed.startsWith('-')) {
                      return (
                        <div key={idx} className="flex items-start gap-2 pl-1 text-gray-200">
                          <span className="text-emerald-400 font-bold">•</span>
                          <span>{trimmed.replace(/^[\t ]*[\*\-•]\s*/, '')}</span>
                        </div>
                      )
                    }
                    if (trimmed.startsWith('#') || (trimmed.startsWith('**') && trimmed.endsWith('**'))) {
                      return (
                        <p key={idx} className="font-bold text-indigo-400 pt-1">
                          {trimmed.replace(/[#\*]/g, '')}
                        </p>
                      )
                    }
                    return <p key={idx} className={trimmed ? 'text-gray-300' : 'h-2'}>{line}</p>
                  })
                ) : (
                  <p className="text-gray-500 italic">No description entered yet.</p>
                )}
              </div>
            )}

            <p className="text-[11px] text-gray-400 flex items-center justify-between">
              <span>Paste formatted notes with <code className="text-indigo-400">*</code> or <code className="text-indigo-400">-</code> to auto-clean into bullet points.</span>
            </p>
          </div>

          {/* Save Button */}
          <button
            onClick={handleSaveVersion}
            disabled={saving}
            className="btn-primary w-full py-2.5 text-xs font-bold flex items-center justify-center gap-1.5"
          >
            {saving ? (
              <RefreshCw size={14} className="animate-spin" />
            ) : (
              <Save size={14} />
            )}
            Save Version & Release Notes
          </button>

          {/* Version API Link Section */}
          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <label className="block text-xs font-bold text-indigo-400 uppercase tracking-wider flex items-center gap-1.5">
                <Code2 size={14} /> Generated Version API Link
              </label>
              <button
                onClick={handleRegenerateKey}
                disabled={regenerating}
                className="text-[11px] font-semibold text-gray-400 hover:text-indigo-400 flex items-center gap-1 transition-colors"
                title="Generate a new API link key"
              >
                <RefreshCw size={12} className={regenerating ? "animate-spin" : ""} />
                Regenerate Link
              </button>
            </div>
            <div className="flex gap-2">
              <input
                type="text"
                readOnly
                className="input-field text-xs font-mono bg-dark-700 border-dark-400 text-gray-200 select-all"
                value={apiUrl || 'Generating link...'}
              />
              <button
                onClick={handleCopyLink}
                disabled={!apiUrl}
                className="btn-secondary px-3 py-2 text-xs font-semibold shrink-0 flex items-center gap-1.5"
                title="Copy API Link"
              >
                {copied ? <Check size={14} className="text-emerald-400" /> : <Copy size={14} />}
                {copied ? 'Copied' : 'Copy API'}
              </button>
              {apiUrl && (
                <a
                  href={apiUrl}
                  target="_blank"
                  rel="noreferrer"
                  className="btn-secondary px-3 py-2 text-xs font-semibold shrink-0 flex items-center gap-1.5 hover:text-emerald-400 transition-colors"
                  title="Test API Endpoint in new tab"
                >
                  <ExternalLink size={14} />
                  Test
                </a>
              )}
            </div>
            <p className="text-[11px] text-gray-400 leading-relaxed">
              Integrate this API link into any app's updater system. When called via GET HTTP request, it returns JSON with the latest version.
            </p>
          </div>

          {/* JSON Response Preview */}
          <div className="space-y-1.5">
            <div className="flex items-center justify-between">
              <label className="block text-[11px] font-bold text-gray-400 uppercase tracking-wider">
                API Response Preview (JSON)
              </label>
              <button
                onClick={handleCopyJson}
                type="button"
                className="text-[11px] font-semibold text-gray-400 hover:text-emerald-400 flex items-center gap-1 transition-colors"
                title="Copy formatted JSON response"
              >
                {jsonCopied ? <Check size={12} className="text-emerald-400" /> : <Copy size={12} />}
                {jsonCopied ? 'Copied JSON' : 'Copy JSON'}
              </button>
            </div>
            <div className="bg-dark-800 border border-dark-400 rounded-xl p-3 font-mono text-[11px] text-emerald-400/90 overflow-x-auto leading-relaxed max-h-56">
              <pre className="whitespace-pre overflow-x-auto select-all">{sampleJsonResponse}</pre>
            </div>
          </div>
        </div>

        {/* Modal Footer */}
        <div className="px-6 py-3 border-t border-dark-400 bg-dark-700/30 flex justify-end">
          <button
            onClick={onClose}
            className="btn-secondary text-xs py-2 px-4 font-semibold"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  )
}
