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

    // Fall back to getSession if not provided in formData
    let accessToken = clientProviderToken
    if (!accessToken) {
      const { data: { session } } = await supabaseClient.auth.getSession()
      accessToken = session?.provider_token
    }

    if (!accessToken) {
      throw new Error("Google Drive access token not found. Please sign out and sign in again.")
    }

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

    const filePart = delimiter +
      `Content-Type: ${file.type || "application/octet-stream"}\r\n` +
      `Content-Transfer-Encoding: base64\r\n\r\n`

    const encoder = new TextEncoder()
    const metadataEncoded = encoder.encode(metadataPart)
    const filePartEncoded = encoder.encode(filePart)
    const closeDelimiterEncoded = encoder.encode(closeDelimiter)

    // Convert file bytes to base64 using fast Deno std encoder
    const base64String = encode(new Uint8Array(fileBytes))
    const base64Encoded = encoder.encode(base64String)

    const body = new Uint8Array(
      metadataEncoded.length + filePartEncoded.length + base64Encoded.length + closeDelimiterEncoded.length
    )
    body.set(metadataEncoded, 0)
    body.set(filePartEncoded, metadataEncoded.length)
    body.set(base64Encoded, metadataEncoded.length + filePartEncoded.length)
    body.set(closeDelimiterEncoded, metadataEncoded.length + filePartEncoded.length + base64Encoded.length)

    const driveResponse = await fetch(
      "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": `multipart/related; boundary=${boundary}`,
        },
        body: body,
      }
    )

    if (!driveResponse.ok) {
      const errorData = await driveResponse.json()
      throw new Error(errorData.error?.message || "Failed to upload to Google Drive")
    }

    const driveFile = await driveResponse.json()

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
