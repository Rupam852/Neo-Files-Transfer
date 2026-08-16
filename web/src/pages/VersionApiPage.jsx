import { useEffect, useState } from 'react'
import { useParams, useSearchParams } from 'react-router-dom'
import { supabase } from '../services/supabase'

export default function VersionApiPage() {
  const { key: paramKey } = useParams()
  const [searchParams] = useSearchParams()
  const apiKey = paramKey || searchParams.get('key') || searchParams.get('version_api_key')

  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    async function fetchVersion() {
      if (!apiKey) {
        setError('Version API Key Required')
        setLoading(false)
        return
      }

      try {
        const { data: file, error: dbError } = await supabase
          .from('shared_files')
          .select('id, file_name, mime_type, apk_version, version_api_key, unique_share_hash, sharing_status, file_size, created_at, modified_at')
          .eq('version_api_key', apiKey)
          .maybeSingle()

        if (dbError || !file) {
          setError('APK Version API key not found or file removed.')
          setLoading(false)
          return
        }

        const proxyUrl = import.meta.env.VITE_PROXY_URL
        const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
        const downloadUrl = proxyUrl
          ? `${proxyUrl.endsWith('/') ? proxyUrl.slice(0, -1) : proxyUrl}/download-file?hash=${file.unique_share_hash}`
          : `${supabaseUrl}/functions/v1/download-file?hash=${file.unique_share_hash}`

        const webUrl = `${window.location.origin}/download/${file.unique_share_hash}`

        setData({
          status: 'success',
          version: file.apk_version || 'v1.0.1',
          file_name: file.file_name,
          file_size: file.file_size || 0,
          download_url: downloadUrl,
          web_url: webUrl,
          sharing_status: file.sharing_status,
          created_at: file.created_at,
          updated_at: file.modified_at || file.created_at
        })
      } catch (err) {
        setError(err.message || 'Error fetching version API')
      } finally {
        setLoading(false)
      }
    }

    fetchVersion()
  }, [apiKey])

  if (loading) {
    return (
      <div style={{ padding: '20px', fontFamily: 'monospace', color: '#888' }}>
        Loading version API...
      </div>
    )
  }

  if (error) {
    return (
      <pre style={{ padding: '20px', fontFamily: 'monospace', color: '#ff5555', background: '#0d1117' }}>
        {JSON.stringify({ status: 'error', error }, null, 2)}
      </pre>
    )
  }

  return (
    <pre style={{ padding: '20px', fontFamily: 'monospace', color: '#50fa7b', background: '#0d1117', margin: 0, minHeight: '100vh', wordBreak: 'break-all' }}>
      {JSON.stringify(data, null, 2)}
    </pre>
  )
}
