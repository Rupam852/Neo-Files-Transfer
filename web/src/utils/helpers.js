export function formatFileSize(bytes) {
  if (bytes === 0) return '0 B'
  const k = 1024
  const sizes = ['B', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i]
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

export function getFileIcon(mimeType) {
  if (!mimeType) return 'file'
  if (mimeType.startsWith('image/')) return 'image'
  if (mimeType.startsWith('video/')) return 'video'
  if (mimeType.includes('pdf')) return 'file-text'
  if (mimeType.includes('spreadsheet') || mimeType.includes('excel')) return 'table'
  if (mimeType.includes('document') || mimeType.includes('word')) return 'file-text'
  if (mimeType.includes('presentation') || mimeType.includes('powerpoint')) return 'presentation'
  if (mimeType.includes('zip') || mimeType.includes('compressed')) return 'archive'
  return 'file'
}

export function generateShareUrl(hash) {
  const baseUrl = import.meta.env.VITE_APP_URL || window.location.origin
  return `${baseUrl}/download/${hash}`
}

export function generateDirectDownloadUrl(hash, isFolder, fileSize, skipIncrement = false) {
  console.log("VITE_CF_WORKER_URL value in helper:", import.meta.env.VITE_CF_WORKER_URL)
  const cfWorkerUrl = import.meta.env.VITE_CF_WORKER_URL
  const proxyUrl = import.meta.env.VITE_PROXY_URL
  
  const incrementParam = skipIncrement ? '&skip_increment=true' : ''

  // If it's a folder, zip it via Render Proxy
  if (isFolder && proxyUrl) {
    const cleanProxy = proxyUrl.endsWith('/') ? proxyUrl.slice(0, -1) : proxyUrl
    return `${cleanProxy}/download-file?hash=${hash}${incrementParam}`
  }

  // If it's a single file, route through high-speed Cloudflare Worker
  if (cfWorkerUrl) {
    const cleanWorker = cfWorkerUrl.endsWith('/') ? cfWorkerUrl.slice(0, -1) : cfWorkerUrl
    return `${cleanWorker}?hash=${hash}${incrementParam}`
  }

  // Fallback to Supabase regional Deno Edge Function
  const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
  return `${supabaseUrl}/functions/v1/download-file?hash=${hash}${incrementParam}`
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

