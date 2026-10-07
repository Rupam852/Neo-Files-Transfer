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
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) {
      throw new Error("Missing authorization header")
    }

    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    )

    // Verify JWT token
    const { data: { user }, error: authError } = await supabaseClient.auth.getUser()
    if (authError || !user) {
      throw new Error("Not authenticated")
    }

    const { folder_name = "Neo Files Transfer" } = await req.json().catch(() => ({}))

    // Admin Supabase client
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    )

    const { data: profile, error: profileError } = await supabaseAdmin
      .from("user_profiles")
      .select("google_access_token, google_refresh_token, drive_folder_id")
      .eq("id", user.id)
      .single()

    if (profileError || !profile) {
      throw new Error("Failed to load user profile.")
    }

    let accessToken = profile.google_access_token
    const refreshToken = profile.google_refresh_token

    if (!accessToken) {
      if (refreshToken) {
        accessToken = await refreshGoogleToken(user.id, refreshToken, supabaseAdmin)
      } else {
        throw new Error("Google Drive connection expired. Please reconnect in Settings.")
      }
    }

    // Step 1: Create new Neo Files Transfer folder at root
    const createFolderInDrive = async (token: string) => {
      return await fetch("https://www.googleapis.com/drive/v3/files", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          name: folder_name,
          mimeType: "application/vnd.google-apps.folder",
        }),
      })
    }

    let driveResponse = await createFolderInDrive(accessToken)

    if (driveResponse.status === 401 && refreshToken) {
      accessToken = await refreshGoogleToken(user.id, refreshToken, supabaseAdmin)
      driveResponse = await createFolderInDrive(accessToken)
    }

    if (!driveResponse.ok) {
      const errorData = await driveResponse.json().catch(() => ({}))
      throw new Error(errorData.error?.message || "Failed to create new folder in Google Drive")
    }

    const newFolder = await driveResponse.json()
    const newFolderId = newFolder.id

    // Step 2: Fetch all user's shared files from Supabase
    const { data: files, error: filesError } = await supabaseAdmin
      .from("shared_files")
      .select("id, google_drive_file_id, file_name, is_folder")
      .eq("user_id", user.id)

    let migratedCount = 0

    if (files && files.length > 0) {
      // Step 3: Link/Move each file into the new folder
      for (const file of files) {
        if (!file.google_drive_file_id) continue
        try {
          const moveRes = await fetch(
            `https://www.googleapis.com/drive/v3/files/${file.google_drive_file_id}?addParents=${newFolderId}&fields=id,parents`,
            {
              method: "PATCH",
              headers: {
                Authorization: `Bearer ${accessToken}`,
              },
            }
          )
          if (moveRes.ok) {
            migratedCount++
          } else {
            console.warn(`File ${file.file_name} (${file.google_drive_file_id}) move warning:`, await moveRes.text())
          }
        } catch (moveErr) {
          console.error(`Error migrating file ${file.file_name}:`, moveErr)
        }
      }
    }

    // Step 4: Update user profile with the verified new folder ID
    const { error: updateError } = await supabaseAdmin
      .from("user_profiles")
      .update({
        drive_folder_id: newFolderId,
        is_folder_verified: true,
      })
      .eq("id", user.id)

    if (updateError) throw updateError

    return new Response(
      JSON.stringify({
        success: true,
        new_folder_id: newFolderId,
        folder_name: newFolder.name,
        total_files: files ? files.length : 0,
        migrated_count: migratedCount,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    )
  } catch (error) {
    console.error("Migration error:", error)
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

  const { error: updateError } = await supabaseAdmin
    .from("user_profiles")
    .update({ google_access_token: newAccessToken })
    .eq("id", userId)

  if (updateError) {
    console.error("Failed to update new access token in database:", updateError)
  }

  return newAccessToken
}
