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

    // Fall back to getSession if not provided in JSON body
    let accessToken = provider_token
    if (!accessToken) {
      const { data: { session } } = await supabaseClient.auth.getSession()
      accessToken = session?.provider_token
    }

    if (!accessToken) {
      throw new Error("Google Drive access token not found. Please sign out and sign in again.")
    }

    // Delete file from Google Drive
    const driveResponse = await fetch(
      `https://www.googleapis.com/drive/v3/files/${file_id}`,
      {
        method: "DELETE",
        headers: {
          Authorization: `Bearer ${accessToken}`,
        },
      }
    )

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
