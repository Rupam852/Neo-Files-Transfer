export function formatFileSize(bytes) {
  if (bytes === 0) return '0 B'
  const k = 1024
  const sizes = ['B', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i]
}

export function formatUploadSpeed(bytesPerSec) {
  if (!bytesPerSec || bytesPerSec <= 0) return '0 KB/s'
  if (bytesPerSec >= 1024 * 1024) {
    return `${(bytesPerSec / (1024 * 1024)).toFixed(1)} MB/s`
  }
  return `${Math.round(bytesPerSec / 1024)} KB/s`
}

export function formatDate(dateString) {
  return new Date(dateString).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

export function getFileIcon(mimeType, fileName = '') {
  const ext = (fileName || '').split('.').pop().toLowerCase()
  if (['mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac', 'wma', 'opus'].includes(ext) || mimeType?.startsWith('audio/')) return 'music'
  if (['mp4', 'mkv', 'mov', 'avi', 'webm'].includes(ext) || mimeType?.startsWith('video/')) return 'video'
  if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'bmp', 'ico'].includes(ext) || mimeType?.startsWith('image/')) return 'image'
  if (ext === 'pdf' || mimeType?.includes('pdf')) return 'file-text'
  if (['zip', 'rar', '7z', 'tar', 'gz'].includes(ext) || mimeType?.includes('zip') || mimeType?.includes('compressed')) return 'archive'
  if (['xls', 'xlsx', 'csv'].includes(ext) || mimeType?.includes('spreadsheet') || mimeType?.includes('excel')) return 'table'
  if (['doc', 'docx'].includes(ext) || mimeType?.includes('document') || mimeType?.includes('word')) return 'file-text'
  if (['ppt', 'pptx'].includes(ext) || mimeType?.includes('presentation') || mimeType?.includes('powerpoint')) return 'presentation'
  return 'file'
}

export function generateShareUrl(hash) {
  const baseUrl = import.meta.env.VITE_APP_URL || window.location.origin
  return `${baseUrl}/download/${hash}`
}

export function generateDirectDownloadUrl(hash, isFolder, fileSize, skipIncrement = false) {
  const proxyUrl = import.meta.env.VITE_PROXY_URL
  const cfWorkerUrl = import.meta.env.VITE_CF_WORKER_URL
  
  const incrementParam = skipIncrement ? '&skip_increment=true' : ''

  // 1. Primary: Route via Render Proxy (handles file streams, ZIP folders, PIN, Limits & instant Owner Notifications)
  if (proxyUrl) {
    const cleanProxy = proxyUrl.endsWith('/') ? proxyUrl.slice(0, -1) : proxyUrl
    return `${cleanProxy}/download-file?hash=${hash}${incrementParam}`
  }

  // 2. Secondary: Route through Cloudflare Worker
  if (cfWorkerUrl) {
    const cleanWorker = cfWorkerUrl.endsWith('/') ? cfWorkerUrl.slice(0, -1) : cfWorkerUrl
    return `${cleanWorker}?hash=${hash}${incrementParam}`
  }

  // 3. Fallback: Supabase regional Deno Edge Function
  const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
  return `${supabaseUrl}/functions/v1/download-file?hash=${hash}${incrementParam}`
}

export function generateMediaPreviewUrl(file) {
  if (!file) return ''
  const proxyUrl = import.meta.env.VITE_PROXY_URL
  const cleanProxy = proxyUrl ? (proxyUrl.endsWith('/') ? proxyUrl.slice(0, -1) : proxyUrl) : ''
  if (cleanProxy && file.id) {
    return `${cleanProxy}/download-file?file_id=${file.id}&preview=true&inline=true&skip_increment=true`
  }
  if (file.unique_share_hash) {
    if (cleanProxy) {
      return `${cleanProxy}/download-file?hash=${file.unique_share_hash}&preview=true&inline=true&skip_increment=true`
    }
    return generateDirectDownloadUrl(file.unique_share_hash, file.is_folder, file.file_size, true)
  }
  const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
  return `${supabaseUrl}/functions/v1/download-file?file_id=${file.id}&preview=true&inline=true&skip_increment=true`
}

export function generateVersionApiUrl(apiKey) {
  if (!apiKey) return ''
  const proxyUrl = import.meta.env.VITE_PROXY_URL
  if (proxyUrl) {
    const cleanProxy = proxyUrl.endsWith('/') ? proxyUrl.slice(0, -1) : proxyUrl
    return `${cleanProxy}/api/version/${apiKey}`
  }
  const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
  if (supabaseUrl) {
    return `${supabaseUrl}/functions/v1/get-version?key=${apiKey}`
  }
  return `${window.location.origin}/api/version/${apiKey}`
}


export function extractFolderId(url) {
  if (url && !url.includes('/') && !url.includes('.') && url.length > 10) {
    return url
  }
  const patterns = [
    /\/folders\/([a-zA-Z0-9_-]+)/,
    /id=([a-zA-Z0-9_-]+)/,
  ]
  for (const pattern of patterns) {
    const match = url.match(pattern)
    if (match) return match[1]
  }
  return null
}

export function getExtension(filename) {
  const parts = filename.split('.')
  return parts.length > 1 ? parts.pop().toUpperCase() : ''
}

export function formatErrorMessage(error) {
  if (!error) return 'An unexpected error occurred'
  const msg = typeof error === 'string' ? error : (error.message || 'An unexpected error occurred')
  
  if (msg.includes('Insufficient permissions for the specified parent') || msg.includes('insufficientFilePermissions') || msg.includes('403')) {
    return 'Google Drive Permission Error: The connected Google account does not have "Editor" permissions for the specified folder.'
  }
  if (msg.includes('File not found') || msg.includes('Folder not found') || msg.includes('404')) {
    return 'Google Drive Resource Not Found: Please verify that the folder URL/ID in Settings exists and is valid.'
  }
  if (msg.includes('invalid_grant') || msg.includes('invalid credentials') || msg.includes('token expired') || msg.includes('401')) {
    return 'Authentication Session Expired: Please sign out and sign in again to refresh your Google Drive connection.'
  }
  if (msg.includes('storage') || msg.includes('quota') || msg.includes('limit')) {
    return 'Google Drive Storage Full: The target Google Drive has run out of storage space. Please free up space and try again.'
  }
  if (msg.includes('network') || msg.includes('fetch') || msg.includes('Failed to fetch')) {
    return 'Network Error: Please check your internet connection and try again.'
  }
  return msg
}

