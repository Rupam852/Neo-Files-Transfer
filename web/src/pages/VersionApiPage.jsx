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

        const cfWorkerUrl = import.meta.env.VITE_CF_WORKER_URL || 'https://neo-files-download.rupambairagya08.workers.dev'
        const cleanWorker = cfWorkerUrl.endsWith('/') ? cfWorkerUrl.slice(0, -1) : cfWorkerUrl
        const downloadUrl = `${cleanWorker}?hash=${file.unique_share_hash}`
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
      <div style={{ padding: '24px', fontFamily: 'monospace', color: '#94a3b8', background: '#090d16', minHeight: '100vh' }}>
        {JSON.stringify({ status: 'loading', message: 'Fetching version API data...' }, null, 2)}
      </div>
    )
  }

  if (error) {
    return (
      <pre style={{ padding: '24px', fontFamily: 'monospace', color: '#f87171', background: '#090d16', margin: 0, minHeight: '100vh', whiteSpace: 'pre-wrap' }}>
        {JSON.stringify({ status: 'error', error }, null, 2)}
      </pre>
    )
  }

  return (
    <div style={{ background: '#090d16', minHeight: '100vh', color: '#34d399', fontFamily: 'monospace', padding: '20px' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px', borderBottom: '1px solid #1e293b', paddingBottom: '10px' }}>
        <div style={{ fontSize: '13px', color: '#94a3b8', display: 'flex', alignItems: 'center', gap: '8px' }}>
          <span style={{ display: 'inline-block', width: '8px', height: '8px', borderRadius: '50%', background: '#10b981' }}></span>
          <span>Version API Response &bull; 200 OK</span>
        </div>
        <div style={{ display: 'flex', gap: '10px' }}>
          <button
            onClick={() => {
              navigator.clipboard.writeText(JSON.stringify(data, null, 2))
              alert('JSON copied to clipboard!')
            }}
            style={{
              padding: '4px 12px',
              fontSize: '12px',
              background: '#1e293b',
              color: '#f8fafc',
              border: '1px solid #334155',
              borderRadius: '6px',
              cursor: 'pointer'
            }}
          >
            Copy JSON
          </button>
          {data?.download_url && (
            <a
              href={data.download_url}
              target="_blank"
              rel="noreferrer"
              style={{
                padding: '4px 12px',
                fontSize: '12px',
                background: '#059669',
                color: '#ffffff',
                border: 'none',
                borderRadius: '6px',
                textDecoration: 'none'
              }}
            >
              Direct Download APK
            </a>
          )}
        </div>
      </div>
      <pre style={{ margin: 0, fontSize: '13px', lineHeight: '1.5', whiteSpace: 'pre-wrap', wordBreak: 'break-word', color: '#34d399' }}>
        {JSON.stringify(data, null, 2)}
      </pre>
    </div>
  )
}
