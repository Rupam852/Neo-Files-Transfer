// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Expose-Headers": "content-length, content-disposition",
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  let isStream = false
  let driveFileId: string | null = null

  try {
    // Get hash from query params
    const url = new URL(req.url)
    const hash = url.searchParams.get("hash")
    isStream = url.searchParams.get("stream") === "true"

    if (!hash) {
      if (isStream) {
        return new Response(
          JSON.stringify({ error: "File Hash Required" }),
          {
            status: 400,
            headers: { "Content-Type": "application/json", ...corsHeaders },
          }
        )
      }
      return new Response("File Not Found", { status: 404, headers: corsHeaders })
    }

    // Use service role to query without RLS
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    )

    // Find file by share hash
    const { data: file, error: fileError } = await supabaseAdmin
      .from("shared_files")
      .select("id, file_name, mime_type, sharing_status, current_version_num, google_drive_file_id, is_folder")
      .eq("unique_share_hash", hash)
      .maybeSingle()

    if (fileError || !file) {
      if (isStream) {
        return new Response(
          JSON.stringify({ error: "The requested file does not exist or has been removed." }),
          {
            status: 404,
            headers: { "Content-Type": "application/json", ...corsHeaders },
          }
        )
      }
      return new Response(
        "<html><body style='font-family:sans-serif;text-align:center;padding:50px'><h1>404 - File Not Found</h1><p>The requested file does not exist or has been removed.</p></body></html>",
        {
          status: 404,
          headers: { "Content-Type": "text/html", ...corsHeaders },
        }
      )
    }

    // Check sharing status
    if (file.sharing_status === "private") {
      if (isStream) {
        return new Response(
          JSON.stringify({ error: "This file is private and cannot be downloaded." }),
          {
            status: 403,
            headers: { "Content-Type": "application/json", ...corsHeaders },
          }
        )
      }
      return new Response(
        "<html><body style='font-family:sans-serif;text-align:center;padding:50px'><h1>403 - Access Denied</h1><p>This file is private and cannot be downloaded.</p></body></html>",
        {
          status: 403,
          headers: { "Content-Type": "text/html", ...corsHeaders },
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
      if (isStream) {
        return new Response(
          JSON.stringify({ error: "Downloads are currently disabled by the administrator." }),
          {
            status: 503,
            headers: { "Content-Type": "application/json", ...corsHeaders },
          }
        )
      }
      return new Response(
        "<html><body style='font-family:sans-serif;text-align:center;padding:50px'><h1>Service Temporarily Busy</h1><p>Downloads are currently disabled. Please try again later.</p></body></html>",
        {
          status: 503,
          headers: { "Content-Type": "text/html", ...corsHeaders },
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

    driveFileId = latestVersion?.google_drive_file_id || file.google_drive_file_id

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
    const fetchMediaFromDrive = async (driveId: string, token: string) => {
      return await fetch(
        `https://www.googleapis.com/drive/v3/files/${driveId}?alt=media`,
        {
          headers: {
            Authorization: `Bearer ${token}`,
          },
        }
      )
    }

    // If it's a folder, recursively package it into a ZIP archive and stream it
    if (file.is_folder) {
      const { data: allFiles, error: allFilesError } = await supabaseAdmin
        .from("shared_files")
        .select("id, file_name, is_folder, google_drive_file_id, mime_type, parent_folder_id")
        .eq("user_id", fileOwner.user_id)

      if (allFilesError || !allFiles) {
        throw new Error("Failed to load folder contents metadata")
      }

      const filesToZip: { google_drive_file_id: string; relativePath: string; is_folder: boolean; file_name: string }[] = []
      
      const buildTree = (folderId: string, currentPath: string) => {
        const children = allFiles.filter(f => f.parent_folder_id === folderId)
        for (const child of children) {
          const relativePath = currentPath ? `${currentPath}/${child.file_name}` : child.file_name
          if (child.is_folder) {
            filesToZip.push({
              google_drive_file_id: child.google_drive_file_id,
              relativePath: relativePath,
              is_folder: true,
              file_name: child.file_name
            })
            buildTree(child.id, relativePath)
          } else {
            filesToZip.push({
              google_drive_file_id: child.google_drive_file_id,
              relativePath: relativePath,
              is_folder: false,
              file_name: child.file_name
            })
          }
        }
      }

      buildTree(file.id, file.file_name)

      // Add the root folder itself to filesToZip list so fflate knows about it if empty
      filesToZip.push({
        google_drive_file_id: file.google_drive_file_id,
        relativePath: file.file_name,
        is_folder: true,
        file_name: file.file_name
      })

      // Dynamically import fflate
      const { zipSync } = await import("https://esm.sh/fflate@0.8.0")
      const zipData: Record<string, Uint8Array> = {}

      for (const item of filesToZip) {
        if (item.is_folder) {
          zipData[item.relativePath + "/"] = new Uint8Array(0)
          continue
        }

        const fileResponse = await fetchMediaFromDrive(item.google_drive_file_id, accessToken)
        if (fileResponse.ok) {
          const fileBytes = await fileResponse.arrayBuffer()
          zipData[item.relativePath] = new Uint8Array(fileBytes)
        } else {
          console.error(`Failed to fetch file ${item.file_name} from Drive during folder zip compilation`)
        }
      }

      const zippedBytes = zipSync(zipData)

      const responseHeaders = new Headers()
      responseHeaders.set("Content-Type", "application/zip")
      responseHeaders.set("Content-Disposition", `attachment; filename="${file.file_name.replace(/"/g, '\\"')}.zip"; filename*=UTF-8''${encodeURIComponent(file.file_name)}.zip`)
      responseHeaders.set("Cache-Control", "no-cache, no-store, must-revalidate")
      responseHeaders.set("Pragma", "no-cache")
      responseHeaders.set("Expires", "0")

      for (const [key, value] of Object.entries(corsHeaders)) {
        responseHeaders.set(key, value)
      }

      return new Response(zippedBytes, {
        headers: responseHeaders,
        status: 200,
      })
    }

    const makeFilePublicOnDrive = async (driveId: string, token: string) => {
      return await fetch(
        `https://www.googleapis.com/drive/v3/files/${driveId}/permissions`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json; charset=UTF-8",
          },
          body: JSON.stringify({
            role: "reader",
            type: "anyone",
          }),
        }
      )
    }

    try {
      let permRes = await makeFilePublicOnDrive(driveFileId, accessToken)
      if (permRes.status === 401 && refreshToken) {
        console.log("Token expired during permission update. Refreshing...")
        accessToken = await refreshGoogleToken(fileOwner.user_id, refreshToken, supabaseAdmin)
        permRes = await makeFilePublicOnDrive(driveFileId, accessToken)
      }
      if (!permRes.ok) {
        const errTxt = await permRes.text()
        console.warn(`Failed to change Google Drive permissions for ${driveFileId}:`, errTxt)
      }
    } catch (permErr) {
      console.warn("Failed to ensure Google Drive file is public:", permErr)
    }

    let confirmToken = "t"
    try {
      const gDriveRes = await fetch(`https://drive.google.com/uc?export=download&id=${driveFileId}`)
      const html = await gDriveRes.text()
      const confirmMatch = html.match(/confirm=([a-zA-Z0-9_-]+)/)
      if (confirmMatch) {
        confirmToken = confirmMatch[1]
      }
    } catch (tokenErr) {
      console.warn("Failed to resolve Google Drive bypass token:", tokenErr)
    }

    const downloadUrl = `https://drive.google.com/uc?export=download&id=${driveFileId}&confirm=${confirmToken}`
    
    // Construct CORS-friendly 302 redirect response
    const responseHeaders = new Headers()
    responseHeaders.set("Location", downloadUrl)
    for (const [key, value] of Object.entries(corsHeaders)) {
      responseHeaders.set(key, value)
    }

    return new Response(null, {
      status: 302,
      headers: responseHeaders
    })

  } catch (error) {
    console.error("Download error:", error)
    const downloadUrl = driveFileId ? `https://drive.google.com/uc?export=download&id=${driveFileId}` : null
    if (isStream) {
      return new Response(
        JSON.stringify({
          error: error.message || "An unexpected error occurred during download streaming.",
          fallbackUrl: downloadUrl,
        }),
        {
          status: 500,
          headers: { "Content-Type": "application/json", ...corsHeaders },
        }
      )
    }
    return new Response(
      `<html><body style='font-family:sans-serif;text-align:center;padding:50px'><h1>Download Failed</h1><p>${error.message}</p></body></html>`,
      {
        status: 500,
        headers: { "Content-Type": "text/html", ...corsHeaders },
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
