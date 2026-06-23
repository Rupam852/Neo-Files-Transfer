// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { encode } from "https://deno.land/std@0.168.0/encoding/base64.ts"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

const MAX_FILE_SIZE = 100 * 1024 * 1024 // 100MB

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) {
      throw new Error("Missing authorization header")
    }

    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    )

    // Verify JWT token on Supabase server using getUser
    const { data: { user }, error: authError } = await supabaseClient.auth.getUser()
    if (authError || !user) {
      throw new Error("Not authenticated")
    }

    const formData = await req.formData()
    const file = formData.get("file") as File
    const folderId = formData.get("folder_id") as string
    const clientProviderToken = formData.get("provider_token") as string
    const oldFileId = formData.get("old_file_id") as string

    if (!file) {
      throw new Error("No file provided")
    }

    if (!folderId) {
      throw new Error("No folder_id provided")
    }

    // Validate file size
    if (file.size > MAX_FILE_SIZE) {
      throw new Error("File size exceeds 100MB limit")
    }

    // Fetch Google access token from database (user_profiles table)
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    )

    const { data: profile, error: profileError } = await supabaseAdmin
      .from("user_profiles")
      .select("google_access_token, google_refresh_token")
      .eq("id", user.id)
      .single()

    if (profileError || !profile) {
      throw new Error("Failed to load user profile or Google Drive connection tokens.")
    }

    let accessToken = clientProviderToken || profile.google_access_token
    if (!accessToken) {
      if (profile.google_refresh_token) {
        accessToken = await refreshGoogleToken(user.id, profile.google_refresh_token, supabaseAdmin)
      } else {
        throw new Error("Google Drive access token not found. Please sign out and sign in again.")
      }
    }

    // Upload new version to Google Drive
    const metadata = {
      name: file.name,
      parents: [folderId],
    }

    const boundary = "-------" + Math.random().toString(36).substring(2)
    const delimiter = `\r\n--${boundary}\r\n`
    const closeDelimiter = `\r\n--${boundary}--`

    const metadataPart = delimiter +
      "Content-Type: application/json; charset=UTF-8\r\n\r\n" +
      JSON.stringify(metadata)

    const fileBytes = await file.arrayBuffer()
    const fileBytesArray = new Uint8Array(fileBytes)

    const filePart = delimiter +
      `Content-Type: ${file.type || "application/octet-stream"}\r\n\r\n`

    const encoder = new TextEncoder()
    const metadataEncoded = encoder.encode(metadataPart)
    const filePartEncoded = encoder.encode(filePart)
    const closeDelimiterEncoded = encoder.encode(closeDelimiter)

    const body = new Uint8Array(
      metadataEncoded.length + filePartEncoded.length + fileBytesArray.length + closeDelimiterEncoded.length
    )
    body.set(metadataEncoded, 0)
    body.set(filePartEncoded, metadataEncoded.length)
    body.set(fileBytesArray, metadataEncoded.length + filePartEncoded.length)
    body.set(closeDelimiterEncoded, metadataEncoded.length + filePartEncoded.length + fileBytesArray.length)

    const uploadToDrive = async (token: string) => {
      return await fetch(
        "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart",
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": `multipart/related; boundary=${boundary}`,
          },
          body: body,
        }
      )
    }

    let driveResponse = await uploadToDrive(accessToken)

    // Handle token expiration / 401 status
    if (driveResponse.status === 401) {
      console.log("Google Drive API returned 401. Attempting token refresh...")
      if (profile.google_refresh_token) {
        try {
          accessToken = await refreshGoogleToken(user.id, profile.google_refresh_token, supabaseAdmin)
          driveResponse = await uploadToDrive(accessToken)
        } catch (refreshError) {
          console.error("Token refresh failed during upload retry:", refreshError)
        }
      }
    }

    if (!driveResponse.ok) {
      const errorData = await driveResponse.json()
      throw new Error(errorData.error?.message || "Failed to upload to Google Drive")
    }

    const driveFile = await driveResponse.json()

    // Delete old file version from Google Drive if specified
    if (oldFileId) {
      console.log(`Deleting old file version from Google Drive: ${oldFileId}`)
      const deleteFromDrive = async (token: string) => {
        return await fetch(
          `https://www.googleapis.com/drive/v3/files/${oldFileId}`,
          {
            method: "DELETE",
            headers: {
              Authorization: `Bearer ${token}`,
            },
          }
        )
      }

      let deleteResponse = await deleteFromDrive(accessToken)
      if (deleteResponse.status === 401 && profile.google_refresh_token) {
        try {
          accessToken = await refreshGoogleToken(user.id, profile.google_refresh_token, supabaseAdmin)
          deleteResponse = await deleteFromDrive(accessToken)
        } catch (err) {
          console.error("Token refresh failed during delete retry:", err)
        }
      }

      if (!deleteResponse.ok && deleteResponse.status !== 404) {
        console.error(`Failed to delete old file version ${oldFileId}:`, await deleteResponse.text())
      } else {
        console.log(`Old file version ${oldFileId} deleted successfully`)
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        file_id: driveFile.id,
        file_name: driveFile.name,
        mime_type: driveFile.mimeType,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
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
