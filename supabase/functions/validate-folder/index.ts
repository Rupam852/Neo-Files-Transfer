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

    let isValid = false
    let folderName = "Google Drive Folder"

    if (accessToken) {
      try {
        const driveResponse = await fetch(
          `https://www.googleapis.com/drive/v3/files/${folder_id}?fields=id,name,mimeType`,
          {
            headers: {
              Authorization: `Bearer ${accessToken}`,
            },
          }
        )
        if (driveResponse.ok) {
          const folderData = await driveResponse.json()
          if (folderData.mimeType === "application/vnd.google-apps.folder") {
            isValid = true
            folderName = folderData.name
          }
        }
      } catch (e) {
        console.error("Google Drive API check failed:", e)
      }
    }

    if (!isValid) {
      // Fallback to checking the public folder page
      try {
        const publicResponse = await fetch(
          `https://drive.google.com/drive/folders/${folder_id}`,
          { method: "HEAD" }
        )
        if (publicResponse.status === 200) {
          isValid = true
        } else {
          // If HEAD fails or gets blocked, try a GET request
          const publicResponseGet = await fetch(
            `https://drive.google.com/drive/folders/${folder_id}`
          )
          if (publicResponseGet.status === 200) {
            isValid = true
          }
        }
      } catch (e) {
        console.error("Public folder check failed:", e)
      }
    }

    if (!isValid) {
      throw new Error("Folder not found or not accessible. Make sure sharing is set to 'Anyone with the link can view'.")
    }

    return new Response(
      JSON.stringify({
        success: true,
        folder: {
          id: folder_id,
          name: folderName,
          mimeType: "application/vnd.google-apps.folder",
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
