import { useState, useEffect } from 'react'
import { supabase } from '../services/supabase'
import { BarChart2, Download, Monitor, Smartphone, Globe, Clock, X, Shield } from 'lucide-react'
import { formatDate } from '../utils/helpers'

export default function FileAnalyticsModal({ file, onClose }) {
  const [logs, setLogs] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (file?.id) {
      loadLogs()
    }
  }, [file?.id])

  async function loadLogs() {
    setLoading(true)
    try {
      const { data, error } = await supabase
        .from('file_download_logs')
        .select('*')
        .eq('file_id', file.id)
        .order('downloaded_at', { ascending: false })
        .limit(50)

      if (error) throw error
      setLogs(data || [])
    } catch (err) {
      console.error('Failed to load logs:', err)
    } finally {
      setLoading(false)
    }
  }

  // Calculate statistics
  const totalDownloads = (file?.download_count || 0) + (logs.length > 0 ? 0 : 0)
  const mobileCount = logs.filter(l => l.device_type === 'Mobile' || l.device_type === 'Tablet').length
  const desktopCount = logs.filter(l => l.device_type === 'Desktop').length

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-dark-600 border border-dark-400 rounded-2xl shadow-2xl p-6 w-full max-w-2xl max-h-[85vh] flex flex-col animate-scale-in">
        {/* Header */}
        <div className="flex items-start justify-between pb-3 border-b border-dark-400">
          <div>
            <h3 className="font-semibold text-gray-100 text-lg font-['Space_Grotesk'] flex items-center gap-2">
              <BarChart2 size={20} className="text-primary-400" />
              Download Analytics & Logs
            </h3>
            <p className="text-xs text-gray-400 truncate max-w-md mt-0.5">{file.file_name}</p>
          </div>
          <button
            onClick={onClose}
            className="p-1 text-gray-400 hover:text-gray-200 hover:bg-dark-500 rounded-lg"
          >
            <X size={18} />
          </button>
        </div>

        {/* Stats Summary Cards */}
        <div className="grid grid-cols-3 gap-3 my-4">
          <div className="bg-dark-500/80 border border-dark-400 p-3 rounded-xl flex items-center gap-3">
            <div className="w-10 h-10 rounded-lg bg-primary-500/10 text-primary-400 flex items-center justify-center">
              <Download size={18} />
            </div>
            <div>
              <p className="text-[11px] text-gray-400 font-medium">Total Downloads</p>
              <p className="text-lg font-bold text-gray-100 font-['Space_Grotesk']">
                {file.download_count || logs.length}
              </p>
            </div>
          </div>

          <div className="bg-dark-500/80 border border-dark-400 p-3 rounded-xl flex items-center gap-3">
            <div className="w-10 h-10 rounded-lg bg-indigo-500/10 text-indigo-400 flex items-center justify-center">
              <Smartphone size={18} />
            </div>
            <div>
              <p className="text-[11px] text-gray-400 font-medium">Mobile Traffic</p>
              <p className="text-lg font-bold text-gray-100 font-['Space_Grotesk']">
                {mobileCount}
              </p>
            </div>
          </div>

          <div className="bg-dark-500/80 border border-dark-400 p-3 rounded-xl flex items-center gap-3">
            <div className="w-10 h-10 rounded-lg bg-emerald-500/10 text-emerald-400 flex items-center justify-center">
              <Monitor size={18} />
            </div>
            <div>
              <p className="text-[11px] text-gray-400 font-medium">Desktop Traffic</p>
              <p className="text-lg font-bold text-gray-100 font-['Space_Grotesk']">
                {desktopCount}
              </p>
            </div>
          </div>
        </div>

        {/* Real-time Activity Logs */}
        <div className="flex-1 overflow-y-auto pr-1 space-y-2">
          <h4 className="text-xs font-bold text-gray-400 uppercase tracking-wider mb-2">
            Recent Download Sessions ({logs.length})
          </h4>

          {loading ? (
            <div className="text-center py-8">
              <div className="w-6 h-6 border-2 border-primary-500 border-t-transparent rounded-full animate-spin mx-auto" />
            </div>
          ) : logs.length === 0 ? (
            <div className="text-center py-8 bg-dark-500/40 rounded-xl border border-dark-400/80">
              <Clock size={32} className="mx-auto text-gray-500 mb-2 opacity-50" />
              <p className="text-xs text-gray-400">No download logs recorded yet.</p>
              <p className="text-[11px] text-gray-500 mt-0.5">Logs will automatically populate when users download this file.</p>
            </div>
          ) : (
            <div className="divide-y divide-dark-400 border border-dark-400 rounded-xl overflow-hidden bg-dark-500/40">
              {logs.map(log => (
                <div key={log.id} className="p-3 flex items-center justify-between text-xs hover:bg-dark-500/80 transition-colors">
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 rounded-lg bg-dark-600 flex items-center justify-center text-gray-400">
                      {log.device_type === 'Mobile' ? <Smartphone size={14} /> : <Monitor size={14} />}
                    </div>
                    <div>
                      <p className="font-semibold text-gray-200 flex items-center gap-1.5">
                        <span>{log.os || 'Unknown OS'}</span>
                        <span className="text-gray-500">•</span>
                        <span className="text-gray-300">{log.browser || 'Browser'}</span>
                      </p>
                      <p className="text-[11px] text-gray-400 flex items-center gap-2">
                        {log.country && <span>📍 {log.country}</span>}
                        {log.ip_address && <span className="font-mono text-[10px] text-gray-500">{log.ip_address}</span>}
                      </p>
                    </div>
                  </div>

                  <div className="text-right">
                    <span className="text-[11px] text-gray-400 font-mono">
                      {formatDate(log.downloaded_at)}
                    </span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="pt-4 border-t border-dark-400 flex justify-end">
          <button className="btn-secondary text-xs py-2 px-4" onClick={onClose}>
            Close
          </button>
        </div>
      </div>
    </div>
  )
}
