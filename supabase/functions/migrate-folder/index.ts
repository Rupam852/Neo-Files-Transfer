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

    const body = await req.json().catch(() => ({}))
    const { mode = "all", folder_name = "Neo Files Transfer", target_folder_id, google_drive_file_id } = body

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

    // MODE 1: Create Folder Only
    if (mode === "create_folder") {
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
      return new Response(
        JSON.stringify({
          success: true,
          folder_id: newFolder.id,
          folder_name: newFolder.name,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      )
    }

    // MODE 2: Move Single File to Target Folder
    if (mode === "move_file") {
      if (!google_drive_file_id || !target_folder_id) {
        throw new Error("google_drive_file_id and target_folder_id are required")
      }

      const moveFileInDrive = async (token: string) => {
        return await fetch(
          `https://www.googleapis.com/drive/v3/files/${google_drive_file_id}?addParents=${target_folder_id}&fields=id,name,parents`,
          {
            method: "PATCH",
            headers: {
              Authorization: `Bearer ${token}`,
            },
          }
        )
      }

      let moveRes = await moveFileInDrive(accessToken)
      if (moveRes.status === 401 && refreshToken) {
        accessToken = await refreshGoogleToken(user.id, refreshToken, supabaseAdmin)
        moveRes = await moveFileInDrive(accessToken)
      }

      if (!moveRes.ok) {
        const errTxt = await moveRes.text()
        console.warn(`File move warning for ${google_drive_file_id}:`, errTxt)
      }

      return new Response(
        JSON.stringify({ success: true, file_id: google_drive_file_id, moved: moveRes.ok }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      )
    }

    // MODE 3: Finish Migration (Update Profile)
    if (mode === "finish") {
      if (!target_folder_id) {
        throw new Error("target_folder_id is required")
      }

      const { error: updateError } = await supabaseAdmin
        .from("user_profiles")
        .update({
          drive_folder_id: target_folder_id,
          is_folder_verified: true,
        })
        .eq("id", user.id)

      if (updateError) throw updateError

      return new Response(
        JSON.stringify({ success: true, drive_folder_id: target_folder_id }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      )
    }

    // MODE 4: Default Full Auto Migration
    // 1. Create root folder
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

    // 2. Fetch and move all files
    const { data: files } = await supabaseAdmin
      .from("shared_files")
      .select("id, google_drive_file_id, file_name")
      .eq("user_id", user.id)

    let movedCount = 0
    if (files && files.length > 0) {
      for (const file of files) {
        if (!file.google_drive_file_id) continue
        try {
          const moveRes = await fetch(
            `https://www.googleapis.com/drive/v3/files/${file.google_drive_file_id}?addParents=${newFolderId}&fields=id,parents`,
            {
              method: "PATCH",
              headers: { Authorization: `Bearer ${accessToken}` },
            }
          )
          if (moveRes.ok) movedCount++
        } catch (e) {
          console.error(`Move file error:`, e)
        }
      }
    }

    // 3. Update profile
    await supabaseAdmin
      .from("user_profiles")
      .update({
        drive_folder_id: newFolderId,
        is_folder_verified: true,
      })
      .eq("id", user.id)

    return new Response(
      JSON.stringify({
        success: true,
        new_folder_id: newFolderId,
        folder_name: newFolder.name,
        total_files: files ? files.length : 0,
        migrated_count: movedCount,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
    )
  } catch (error) {
    console.error("Migration error:", error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
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
