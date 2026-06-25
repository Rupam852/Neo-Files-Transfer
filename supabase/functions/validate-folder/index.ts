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

    // Get user using getUser to verify JWT on the server
    const { data: { user }, error: authError } = await supabaseClient.auth.getUser()
    if (authError || !user) {
      throw new Error("Not authenticated")
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

    let accessToken = profile?.google_access_token
    let refreshToken = profile?.google_refresh_token

    let isValid = false
    let folderName = "Google Drive Folder"

    let validationError = ""

    if (accessToken) {
      try {
        const fetchFolder = async (token: string) => {
          return await fetch(
            `https://www.googleapis.com/drive/v3/files/${folder_id}?fields=id,name,mimeType,capabilities`,
            {
              headers: {
                Authorization: `Bearer ${token}`,
              },
            }
          )
        }

        let driveResponse = await fetchFolder(accessToken)

        // Handle token expiration / 401 status
        if (driveResponse.status === 401 && refreshToken) {
          console.log("Google Drive API returned 401 during validation. Refreshing token...")
          try {
            accessToken = await refreshGoogleToken(user.id, refreshToken, supabaseAdmin)
            driveResponse = await fetchFolder(accessToken)
          } catch (refreshError) {
            console.error("Token refresh failed during folder validation:", refreshError)
          }
        }

        if (driveResponse.ok) {
          const folderData = await driveResponse.json()
          if (folderData.mimeType === "application/vnd.google-apps.folder") {
            if (folderData.capabilities?.canAddChildren === true) {
              isValid = true
              folderName = folderData.name
            } else {
              validationError = "Google Drive Permission Error: This folder does not belong to your account or you do not have write/edit permissions. Please open Google Drive and grant 'Editor' permissions to this folder."
            }
          } else {
            validationError = "Google Drive Error: The specified ID is a file, not a folder."
          }
        } else {
          const errData = await driveResponse.json().catch(() => ({}))
          const isInsufficient = errData.error?.errors?.some((e: any) => e.reason === 'insufficientPermissions')
          if (isInsufficient || driveResponse.status === 403) {
            validationError = "Google Drive Scope Error: Insufficient permissions. Please ensure you checked the Google Drive write permission checkbox during login."
          } else if (driveResponse.status === 404) {
            validationError = "Google Drive Error: Folder not found. Please verify the folder ID."
          } else {
            validationError = errData.error?.message || `Google Drive API returned status ${driveResponse.status}`
          }
        }
      } catch (e) {
        console.error("Google Drive API check failed:", e)
        validationError = e.message
      }
    }

    if (!isValid) {
      if (validationError) {
        throw new Error(validationError)
      }

      // Fallback to checking the public folder page only if no accessToken was checked
      if (!accessToken) {
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
