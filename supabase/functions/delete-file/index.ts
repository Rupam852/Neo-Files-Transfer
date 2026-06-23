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
    const { file_id, provider_token } = await req.json()

    if (!file_id) {
      throw new Error("file_id is required")
    }

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

    let accessToken = provider_token || profile.google_access_token
    if (!accessToken) {
      if (profile.google_refresh_token) {
        accessToken = await refreshGoogleToken(user.id, profile.google_refresh_token, supabaseAdmin)
      } else {
        throw new Error("Google Drive access token not found. Please sign out and sign in again.")
      }
    }

    // Delete file from Google Drive
    const deleteFromDrive = async (token: string) => {
      return await fetch(
        `https://www.googleapis.com/drive/v3/files/${file_id}`,
        {
          method: "DELETE",
          headers: {
            Authorization: `Bearer ${token}`,
          },
        }
      )
    }

    let driveResponse = await deleteFromDrive(accessToken)

    // Handle token expiration / 401 status
    if (driveResponse.status === 401) {
      console.log("Google Drive API returned 401. Attempting token refresh...")
      if (profile.google_refresh_token) {
        try {
          accessToken = await refreshGoogleToken(user.id, profile.google_refresh_token, supabaseAdmin)
          driveResponse = await deleteFromDrive(accessToken)
        } catch (refreshError) {
          console.error("Token refresh failed during delete retry:", refreshError)
        }
      }
    }

    if (!driveResponse.ok && driveResponse.status !== 404) {
      const errorData = await driveResponse.json()
      console.error("Drive delete error:", errorData)
    }

    return new Response(
      JSON.stringify({ success: true }),
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
