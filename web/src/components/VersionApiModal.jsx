import { useState } from 'react'
import { supabase } from '../services/supabase'
import toast from 'react-hot-toast'
import { Copy, Check, RefreshCw, Save, Smartphone, Code2, X } from 'lucide-react'
import { generateVersionApiUrl } from '../utils/helpers'

export default function VersionApiModal({ file, onClose, onFileUpdated }) {
  const [version, setVersion] = useState(file.apk_version || 'v1.0.1')
  const [apiKey, setApiKey] = useState(file.version_api_key || '')
  const [copied, setCopied] = useState(false)
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
          modified_at: new Date().toISOString()
        })
        .eq('id', file.id)

      if (error) throw error

      setVersion(formattedVersion)
      toast.success(`APK version updated to ${formattedVersion}`)
      if (onFileUpdated) {
        onFileUpdated({ ...file, apk_version: formattedVersion })
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
          modified_at: new Date().toISOString()
        })
        .eq('id', file.id)

      if (error) throw error

      setApiKey(newKey)
      toast.success('New Version API Link generated!')
      if (onFileUpdated) {
        onFileUpdated({ ...file, version_api_key: newKey, apk_version: formattedVersion })
      }
    } catch (err) {
      console.error('Failed to regenerate key:', err)
      toast.error('Failed to generate key: ' + err.message)
    } finally {
      setRegenerating(false)
    }
  }

  const sampleJsonResponse = JSON.stringify(
    {
      status: "success",
      version: version || "v1.0.1",
      file_name: file.file_name,
      file_size: file.file_size || 0,
      download_url: apiUrl ? `${apiUrl.split('/api')[0]}/download-file?hash=${file.unique_share_hash || 'HASH'}` : "...",
      updated_at: new Date().toISOString()
    },
    null,
    2
  )

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
        <div className="p-6 space-y-6 overflow-y-auto">
          {/* Editable Version Input Section */}
          <div className="space-y-2">
            <label className="block text-xs font-bold text-gray-300 uppercase tracking-wider">
              APK Version (Editable)
            </label>
            <div className="flex gap-2">
              <input
                type="text"
                className="input-field flex-1 font-mono text-sm font-semibold text-emerald-400 bg-dark-700 border-dark-400"
                value={version}
                onChange={(e) => setVersion(e.target.value)}
                placeholder="e.g. v1.0.1"
              />
              <button
                onClick={handleSaveVersion}
                disabled={saving}
                className="btn-primary px-4 py-2 text-xs font-bold flex items-center gap-1.5 shrink-0"
              >
                {saving ? (
                  <RefreshCw size={14} className="animate-spin" />
                ) : (
                  <Save size={14} />
                )}
                Save Version
              </button>
            </div>
            <p className="text-[11px] text-gray-400">
              This version will be returned when your app calls the API endpoint below. Default for new APKs is <code className="text-emerald-400">v1.0.1</code>.
            </p>
          </div>

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
                className="btn-secondary px-4 py-2 text-xs font-semibold shrink-0 flex items-center gap-1.5"
              >
                {copied ? <Check size={14} className="text-emerald-400" /> : <Copy size={14} />}
                {copied ? 'Copied' : 'Copy API'}
              </button>
            </div>
            <p className="text-[11px] text-gray-400 leading-relaxed">
              Integrate this API link into any app's updater system. When called via GET HTTP request, it returns JSON with the latest version.
            </p>
          </div>

          {/* JSON Response Preview */}
          <div className="space-y-1.5">
            <label className="block text-[11px] font-bold text-gray-400 uppercase tracking-wider">
              API Response Preview (JSON)
            </label>
            <div className="bg-dark-800 border border-dark-400 rounded-xl p-3 font-mono text-[11px] text-emerald-400/90 overflow-x-auto leading-relaxed">
              <pre>{sampleJsonResponse}</pre>
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
