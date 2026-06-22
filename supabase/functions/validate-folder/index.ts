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
    const { folder_id } = await req.json()

    if (!folder_id) {
      throw new Error("folder_id is required")
    }

    const authHeader = req.headers.get("Authorization")
    if (!authHeader) {
      throw new Error("Missing authorization header")
    }

    // Create Supabase client
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    )

    // Get user's access token from session
    const { data: { session } } = await supabaseClient.auth.getSession()
    if (!session) {
      throw new Error("Not authenticated")
    }

    const accessToken = session.provider_token

    // Validate folder using Google Drive API
    const driveResponse = await fetch(
      `https://www.googleapis.com/drive/v3/files/${folder_id}?fields=id,name,mimeType,webContentLink,webViewLink`,
      {
        headers: {
          Authorization: `Bearer ${accessToken}`,
        },
      }
    )

    if (!driveResponse.ok) {
      const errorData = await driveResponse.json()
      throw new Error(errorData.error?.message || "Folder not found or not accessible")
    }

    const folderData = await driveResponse.json()

    // Verify it's actually a folder
    if (folderData.mimeType !== "application/vnd.google-apps.folder") {
      throw new Error("The provided ID is not a Google Drive folder")
    }

    return new Response(
      JSON.stringify({
        success: true,
        folder: {
          id: folderData.id,
          name: folderData.name,
          mimeType: folderData.mimeType,
        },
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
