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

    // Get the file owner
    const { data: fileOwner } = await supabaseAdmin
      .from("shared_files")
      .select("user_id")
      .eq("id", file.id)
      .single()

    if (!fileOwner) {
      throw new Error("File owner not found")
    }

    // Fetch the owner's Google tokens from the database
    const { data: ownerProfile, error: ownerError } = await supabaseAdmin
      .from("user_profiles")
      .select("google_access_token, google_refresh_token")
      .eq("id", fileOwner.user_id)
      .single()

    if (ownerError || !ownerProfile) {
      throw new Error("Failed to retrieve file owner's Google tokens")
    }

    let accessToken = ownerProfile.google_access_token
    const refreshToken = ownerProfile.google_refresh_token

    if (!accessToken) {
      if (refreshToken) {
        accessToken = await refreshGoogleToken(fileOwner.user_id, refreshToken, supabaseAdmin)
      } else {
        throw new Error("Owner's Google access token is missing and no refresh token is available")
      }
    }

    // Helper to fetch file media content from Google Drive
    const fetchMediaFromDrive = async (token: string) => {
      return await fetch(
        `https://www.googleapis.com/drive/v3/files/${driveFileId}?alt=media`,
        {
          headers: {
            Authorization: `Bearer ${token}`,
          },
        }
      )
    }

    let driveResponse = await fetchMediaFromDrive(accessToken)

    // Handle token expiration (401)
    if (driveResponse.status === 401 && refreshToken) {
      console.log("Google Drive alt=media returned 401. Refreshing owner token...")
      try {
        accessToken = await refreshGoogleToken(fileOwner.user_id, refreshToken, supabaseAdmin)
        driveResponse = await fetchMediaFromDrive(accessToken)
      } catch (refreshErr) {
        console.error("Token refresh failed during download retry:", refreshErr)
      }
    }

    if (!driveResponse.ok) {
      console.error("Failed to fetch from Drive, status:", driveResponse.status)
      // Fallback: Redirect to public Drive download link if streaming failed
      const downloadUrl = `https://drive.google.com/uc?export=download&id=${driveFileId}`
      return Response.redirect(downloadUrl, 302)
    }

    // Set correct headers for download attachment streaming
    const responseHeaders = new Headers()
    responseHeaders.set("Content-Type", file.mime_type || driveResponse.headers.get("Content-Type") || "application/octet-stream")
    responseHeaders.set("Content-Disposition", `attachment; filename="${file.file_name.replace(/"/g, '\\"')}"; filename*=UTF-8''${encodeURIComponent(file.file_name)}`)
    
    // Prevent browser and CDN caching of downloads to ensure latest version is always served
    responseHeaders.set("Cache-Control", "no-cache, no-store, must-revalidate")
    responseHeaders.set("Pragma", "no-cache")
    responseHeaders.set("Expires", "0")
    
    // Add CORS headers
    for (const [key, value] of Object.entries(corsHeaders)) {
      responseHeaders.set(key, value)
    }

    // Stream the body directly to the client
    return new Response(driveResponse.body, {
      headers: responseHeaders,
      status: 200,
    })

  } catch (error) {
    console.error("Download error:", error)
    return new Response(
      `<html><body style='font-family:sans-serif;text-align:center;padding:50px'><h1>Download Failed</h1><p>${error.message}</p></body></html>`,
      {
        status: 500,
        headers: { "Content-Type": "text/html" },
      }
    )
  }
})

// Helper to refresh Google token and save it to the database
async function refreshGoogleToken(userId: string, refreshToken: string, supabaseAdmin: any): Promise<string> {
  const clientId = Deno.env.get("GOOGLE_CLIENT_ID")
  const clientSecret = Deno.env.get("GOOGLE_CLIENT_SECRET")

  if (!clientId || !clientSecret) {
    throw new Error("Google OAuth credentials are not configured in system environment secrets.")
  }

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      refresh_token: refreshToken,
      grant_type: "refresh_token",
    }),
  })

  if (!res.ok) {
    const errText = await res.text()
    console.error("Failed to refresh Google token:", errText)
    throw new Error("Failed to refresh Google access token. Please sign out and sign in again.")
  }

  const data = await res.json()
  const newAccessToken = data.access_token

  if (!newAccessToken) {
    throw new Error("No access token returned in refresh response")
  }

  // Save the new access token to the database
  const { error: updateError } = await supabaseAdmin
    .from("user_profiles")
    .update({ google_access_token: newAccessToken })
    .eq("id", userId)

  if (updateError) {
    console.error("Failed to update new access token in database:", updateError)
  }

  return newAccessToken
}
