import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Content-Type': 'application/json; charset=utf-8',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const url = new URL(req.url)
    const versionApiKey = url.searchParams.get('key') || url.pathname.split('/').pop()

    if (!versionApiKey || versionApiKey === 'get-version') {
      return new Response(
        JSON.stringify({ status: 'error', error: 'Version API Key Required' }),
        { status: 400, headers: corsHeaders }
      )
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)

    const { data: file, error: fileError } = await supabaseAdmin
      .from('shared_files')
      .select('id, file_name, mime_type, apk_version, version_api_key, unique_share_hash, sharing_status, file_size, created_at, modified_at')
      .eq('version_api_key', versionApiKey)
      .maybeSingle()

    if (fileError || !file) {
      return new Response(
        JSON.stringify({ status: 'error', error: 'APK Version API key not found or file removed.' }),
        { status: 404, headers: corsHeaders }
      )
    }
    let shareHash = file.unique_share_hash
    if (!shareHash) {
      shareHash = Date.now().toString(36) + Math.random().toString(36).substring(2, 8) + file.id.substring(0, 6)
      await supabaseAdmin
        .from('shared_files')
        .update({ unique_share_hash: shareHash, sharing_status: 'public' })
        .eq('id', file.id)
    }

    const cfWorkerUrl = Deno.env.get('CF_WORKER_URL') || 'https://download.neofilestransfer.site'
    const cleanWorker = cfWorkerUrl.endsWith('/') ? cfWorkerUrl.slice(0, -1) : cfWorkerUrl
    const downloadUrl = `${cleanWorker}?hash=${shareHash}`
    const appUrl = (Deno.env.get('APP_URL') || 'https://neofilestransfer.site').replace(/\/$/, '')
    const webUrl = `${appUrl}/download/${shareHash}`

    return new Response(
      JSON.stringify({
        status: 'success',
        version: file.apk_version || 'v1.0.1',
        file_name: file.file_name,
        file_size: file.file_size || 0,
        download_url: downloadUrl,
        web_url: webUrl,
        sharing_status: file.sharing_status,
        created_at: file.created_at,
        updated_at: file.modified_at || file.created_at
      }, null, 2),
      { status: 200, headers: corsHeaders }
    )
  } catch (err: any) {
    return new Response(
      JSON.stringify({ status: 'error', error: err.message || 'Server Error' }),
      { status: 500, headers: corsHeaders }
    )
  }
})
