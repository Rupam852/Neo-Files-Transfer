// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    // Get hash from query params
    const url = new URL(req.url)
    const hash = url.searchParams.get("hash")

    if (!hash) {
      return new Response("File Not Found", { status: 404 })
    }

    // Use service role to query without RLS
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    )

    // Find file by share hash
    const { data: file, error: fileError } = await supabaseAdmin
      .from("shared_files")
      .select("id, file_name, mime_type, sharing_status, current_version_num, google_drive_file_id")
      .eq("unique_share_hash", hash)
      .maybeSingle()

    if (fileError || !file) {
      return new Response(
        "<html><body style='font-family:sans-serif;text-align:center;padding:50px'><h1>404 - File Not Found</h1><p>The requested file does not exist or has been removed.</p></body></html>",
        {
          status: 404,
          headers: { "Content-Type": "text/html" },
        }
      )
    }

    // Check sharing status
    if (file.sharing_status === "private") {
      return new Response(
        "<html><body style='font-family:sans-serif;text-align:center;padding:50px'><h1>403 - Access Denied</h1><p>This file is private and cannot be downloaded.</p></body></html>",
        {
          status: 403,
          headers: { "Content-Type": "text/html" },
        }
      )
    }

    // Check system settings
    const { data: downloadSetting } = await supabaseAdmin
      .from("system_settings")
      .select("value")
      .eq("key", "downloads_enabled")
      .maybeSingle()

    if (downloadSetting && downloadSetting.value === false) {
      return new Response(
        "<html><body style='font-family:sans-serif;text-align:center;padding:50px'><h1>Service Temporarily Busy</h1><p>Downloads are currently disabled. Please try again later.</p></body></html>",
        {
          status: 503,
          headers: { "Content-Type": "text/html" },
        }
      )
    }

    // Get latest version's Google Drive file ID
    const { data: latestVersion } = await supabaseAdmin
      .from("file_versions")
      .select("google_drive_file_id")
      .eq("file_id", file.id)
      .order("version_number", { ascending: false })
      .limit(1)
      .maybeSingle()

    const driveFileId = latestVersion?.google_drive_file_id || file.google_drive_file_id

    // Get the download URL from Google Drive API
    // We need the owner's Google access token
    // For this, we use the file owner's session
    const { data: fileOwner } = await supabaseAdmin
      .from("shared_files")
      .select("user_id")
      .eq("id", file.id)
      .single()

    // Use the Google Drive webContentLink for direct download
    // Since we can't easily get the owner's token in a serverless function,
    // we'll use the public sharing approach

    // Option 1: If file has webContentLink (public files)
    const driveResponse = await fetch(
      `https://www.googleapis.com/drive/v3/files/${driveFileId}?fields=webContentLink,webViewLink`,
      {
        headers: {
          // Use API key for public file access
          Authorization: `Bearer ${Deno.env.get("GOOGLE_API_KEY") || ""}`,
        },
      }
    )

    if (driveResponse.ok) {
      const driveData = await driveResponse.json()
      if (driveData.webContentLink) {
        return Response.redirect(driveData.webContentLink, 302)
      }
    }

    // Option 2: Direct download via Drive export URL
    const downloadUrl = `https://drive.google.com/uc?export=download&id=${driveFileId}`
    return Response.redirect(downloadUrl, 302)

  } catch (error) {
    console.error("Download error:", error)
    return new Response(
      "<html><body style='font-family:sans-serif;text-align:center;padding:50px'><h1>Error</h1><p>An error occurred while processing your download.</p></body></html>",
      {
        status: 500,
        headers: { "Content-Type": "text/html" },
      }
    )
  }
})
