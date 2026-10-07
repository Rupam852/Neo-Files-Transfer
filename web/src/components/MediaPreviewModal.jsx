import { useState, useEffect } from 'react'
import { generateDirectDownloadUrl, formatFileSize } from '../utils/helpers'
import {
  X, Download, Play, Pause, Volume2, Maximize2, FileText,
  Video, Music, Image as ImageIcon, Code, ExternalLink, RefreshCw
} from 'lucide-react'

export default function MediaPreviewModal({ file, onClose }) {
  const [textContent, setTextContent] = useState('')
  const [loadingText, setLoadingText] = useState(false)
  const [loadError, setLoadError] = useState(null)

  const ext = (file?.file_name || '').split('.').pop().toLowerCase()
  const isVideo = ['mp4', 'webm', 'ogg', 'mov', 'mkv'].includes(ext) || file?.mime_type?.startsWith('video/')
  const isAudio = ['mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac'].includes(ext) || file?.mime_type?.startsWith('audio/')
  const isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'bmp'].includes(ext) || file?.mime_type?.startsWith('image/')
  const isPdf = ext === 'pdf' || file?.mime_type === 'application/pdf'
  const isTextOrCode = ['txt', 'json', 'js', 'jsx', 'ts', 'tsx', 'css', 'html', 'py', 'dart', 'log', 'sql', 'md', 'xml', 'yaml', 'yml', 'env'].includes(ext)

  // Use skip_increment to not pollute download counters while previewing
  const mediaStreamUrl = generateDirectDownloadUrl(file.unique_share_hash, file.is_folder, file.file_size, true)

  useEffect(() => {
    if (isTextOrCode && mediaStreamUrl) {
      fetchTextContent()
    }
  }, [file?.id])

  async function fetchTextContent() {
    setLoadingText(true)
    setLoadError(null)
    try {
      const res = await fetch(mediaStreamUrl)
      if (!res.ok) throw new Error(`HTTP error ${res.status}`)
      const text = await res.text()
      // Limit preview to first 50KB if massive
      if (text.length > 50000) {
        setTextContent(text.substring(0, 50000) + '\n\n...[Content truncated for fast preview]...')
      } else {
        setTextContent(text)
      }
    } catch (err) {
      setLoadError('Failed to load text content: ' + err.message)
    } finally {
      setLoadingText(false)
    }
  }

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-md z-50 flex items-center justify-center p-4 animate-fade-in">
      <div className="bg-dark-600 border border-dark-400 rounded-2xl shadow-2xl w-full max-w-4xl max-h-[90vh] flex flex-col overflow-hidden animate-scale-in">
        
        {/* Modal Top Bar */}
        <div className="flex items-center justify-between px-5 py-3.5 bg-dark-700/80 border-b border-dark-400/80">
          <div className="flex items-center gap-3 min-w-0">
            <div className="w-8 h-8 rounded-lg bg-primary-500/10 text-primary-400 flex items-center justify-center shrink-0">
              {isVideo ? <Video size={16} /> : isAudio ? <Music size={16} /> : isImage ? <ImageIcon size={16} /> : isPdf ? <FileText size={16} /> : <Code size={16} />}
            </div>
            <div className="min-w-0">
              <h3 className="font-semibold text-gray-100 text-sm truncate font-['Space_Grotesk']">
                {file.file_name}
              </h3>
              <p className="text-[11px] text-gray-400">
                {formatFileSize(file.file_size || 0)} • {ext.toUpperCase()}
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <a
              href={generateDirectDownloadUrl(file.unique_share_hash, file.is_folder, file.file_size)}
              download={file.file_name}
              className="btn-secondary py-1.5 px-3 text-xs flex items-center gap-1.5 font-medium"
            >
              <Download size={13} /> Download
            </a>
            <button
              onClick={onClose}
              className="p-1.5 text-gray-400 hover:text-gray-200 hover:bg-dark-500 rounded-lg transition-colors"
            >
              <X size={18} />
            </button>
          </div>
        </div>

        {/* Media Preview Container */}
        <div className="flex-1 bg-dark-800 flex items-center justify-center p-4 overflow-auto min-h-[350px]">
          {/* Video Preview */}
          {isVideo && (
            <video
              src={mediaStreamUrl}
              controls
              autoPlay
              className="max-h-[70vh] max-w-full rounded-xl shadow-2xl bg-black"
            >
              Your browser does not support HTML5 video playback.
            </video>
          )}

          {/* Audio Preview */}
          {isAudio && (
            <div className="w-full max-w-md p-8 bg-dark-600/90 border border-dark-400 rounded-2xl shadow-2xl text-center space-y-6">
              <div className="w-20 h-20 bg-primary-500/10 border border-primary-500/20 text-primary-400 rounded-full flex items-center justify-center mx-auto shadow-inner animate-pulse">
                <Music size={36} />
              </div>
              <div>
                <h4 className="text-base font-semibold text-gray-100 truncate">{file.file_name}</h4>
                <p className="text-xs text-gray-400 mt-1">{formatFileSize(file.file_size || 0)}</p>
              </div>
              <audio
                src={mediaStreamUrl}
                controls
                autoPlay
                className="w-full"
              >
                Your browser does not support audio streaming.
              </audio>
            </div>
          )}

          {/* Image Preview */}
          {isImage && (
            <img
              src={mediaStreamUrl}
              alt={file.file_name}
              className="max-h-[72vh] max-w-full object-contain rounded-xl shadow-2xl"
            />
          )}

          {/* PDF Preview */}
          {isPdf && (
            <iframe
              src={mediaStreamUrl}
              title={file.file_name}
              className="w-full h-[72vh] rounded-xl border border-dark-400 bg-white"
            />
          )}

          {/* Text / Code Preview */}
          {isTextOrCode && (
            <div className="w-full h-full max-h-[72vh] flex flex-col">
              {loadingText ? (
                <div className="text-center py-16 m-auto">
                  <div className="w-8 h-8 border-2 border-primary-500 border-t-transparent rounded-full animate-spin mx-auto mb-3" />
                  <p className="text-xs text-gray-400">Loading code preview...</p>
                </div>
              ) : loadError ? (
                <div className="text-center py-16 m-auto text-red-400 text-xs">
                  {loadError}
                </div>
              ) : (
                <pre className="w-full h-full p-4 bg-dark-900 border border-dark-500 rounded-xl font-mono text-xs text-gray-300 overflow-auto whitespace-pre-wrap select-text leading-relaxed">
                  {textContent}
                </pre>
              )}
            </div>
          )}

          {/* Fallback for unsupported formats */}
          {!isVideo && !isAudio && !isImage && !isPdf && !isTextOrCode && (
            <div className="text-center py-12 space-y-4">
              <div className="w-16 h-16 bg-dark-600 rounded-2xl flex items-center justify-center mx-auto text-gray-400 border border-dark-400">
                <FileText size={32} />
              </div>
              <div>
                <p className="text-sm font-semibold text-gray-200">Preview not available for .{ext} files</p>
                <p className="text-xs text-gray-400 mt-1">You can download the file to view it on your device.</p>
              </div>
              <a
                href={generateDirectDownloadUrl(file.unique_share_hash, file.is_folder, file.file_size)}
                download={file.file_name}
                className="btn-primary py-2 px-6 text-xs font-semibold inline-flex items-center gap-2"
              >
                <Download size={14} /> Download File
              </a>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
