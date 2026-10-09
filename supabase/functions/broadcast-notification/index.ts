// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { create, getNumericDate } from "https://deno.land/x/djwt@v2.8/mod.ts"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

// Convert PEM string to CryptoKey for RS256 signing
async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const cleanPem = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");

  const binaryDer = Uint8Array.from(atob(cleanPem), (c) => c.charCodeAt(0));

  return await crypto.subtle.importKey(
    "pkcs8",
    binaryDer.buffer,
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"]
  );
}

// Generate Google OAuth2 Access Token using Service Account
async function getGoogleAccessToken(clientEmail: string, privateKeyPem: string): Promise<string> {
  const privateKey = await importPrivateKey(privateKeyPem);
  const now = Math.floor(Date.now() / 1000);

  const jwt = await create(
    { alg: "RS256", typ: "JWT" },
    {
      iss: clientEmail,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      exp: getNumericDate(now + 3600),
      iat: getNumericDate(now),
    },
    privateKey
  );

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const data = await res.json();
  if (!res.ok) {
    throw new Error(`Failed to obtain Google access token: ${JSON.stringify(data)}`);
  }
  return data.access_token;
}

// Send FCM Push Notification via FCM HTTP v1 API
async function sendFcmMessage({
  projectId,
  accessToken,
  target,
  targetType, // 'topic' | 'token'
  title,
  body,
  dataPayload = {},
}: {
  projectId: string;
  accessToken: string;
  target: string;
  targetType: "topic" | "token";
  title: string;
  body: string;
  dataPayload?: Record<string, string>;
}) {
  const message: Record<string, any> = {
    notification: {
      title,
      body,
    },
    data: {
      click_action: "FLUTTER_NOTIFICATION_CLICK",
      ...dataPayload,
    },
    android: {
      priority: "high",
      notification: {
        channel_id: "neo_transfers_channel",
        icon: "launcher_icon",
        sound: "default",
      },
    },
  };

  if (targetType === "topic") {
    message.topic = target;
  } else {
    message.token = target;
  }

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ message }),
    }
  );

  const result = await res.json();
  if (!res.ok) {
    throw new Error(`FCM send error: ${JSON.stringify(result)}`);
  }
  return result;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // Verify Admin authentication
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization header" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: userError } = await supabase.auth.getUser(token);
    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Check if requester is an admin in admins table
    const { data: adminRecord, error: adminErr } = await supabase
      .from("admins")
      .select("id, role")
      .eq("user_id", user.id)
      .single();

    if (adminErr || !adminRecord) {
      return new Response(JSON.stringify({ error: "Forbidden: Admin privileges required" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const {
      title,
      body,
      targetType = "topic", // 'topic' | 'token' | 'user'
      target = "all_users",  // topic name or user_id or fcm_token
      dataPayload = {},
    } = await req.json();

    if (!title || !body) {
      return new Response(JSON.stringify({ error: "Missing title or body" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Read Firebase Service Account details from environment or database
    const fcmClientEmail = Deno.env.get("FCM_CLIENT_EMAIL") || "firebase-adminsdk-fbsvc@neo-files-transfer-24881.iam.gserviceaccount.com";
    const fcmProjectId = Deno.env.get("FCM_PROJECT_ID") || "neo-files-transfer-24881";
    let fcmPrivateKey = Deno.env.get("FCM_PRIVATE_KEY") || "";

    // Fallback if not configured in env
    if (!fcmPrivateKey) {
      // Try to fetch from system_settings or secret table
      const { data: keySetting } = await supabase
        .from("system_settings")
        .select("value")
        .eq("key", "fcm_service_account_private_key")
        .maybeSingle();
      if (keySetting?.value) {
        fcmPrivateKey = keySetting.value;
      }
    }

    if (!fcmPrivateKey) {
      throw new Error("FCM service account private key not configured.");
    }

    const accessToken = await getGoogleAccessToken(fcmClientEmail, fcmPrivateKey);

    let finalResults = [];

    if (targetType === "user") {
      // Fetch all FCM tokens registered for this user
      const { data: tokens, error: tokenErr } = await supabase
        .from("user_fcm_tokens")
        .select("fcm_token")
        .eq("user_id", target);

      if (tokenErr || !tokens || tokens.length === 0) {
        return new Response(JSON.stringify({ message: "No active device tokens found for this user", sentCount: 0 }), {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      for (const t of tokens) {
        try {
          const res = await sendFcmMessage({
            projectId: fcmProjectId,
            accessToken,
            target: t.fcm_token,
            targetType: "token",
            title,
            body,
            dataPayload,
          });
          finalResults.push(res);
        } catch (e) {
          console.error("Failed to send to token:", t.fcm_token, e);
        }
      }
    } else {
      // Send to topic ('all_users' | 'app_updates') or raw token
      const res = await sendFcmMessage({
        projectId: fcmProjectId,
        accessToken,
        target,
        targetType: targetType === "token" ? "token" : "topic",
        title,
        body,
        dataPayload,
      });
      finalResults.push(res);
    }

    // Log the broadcast in activity logs
    await supabase.from("activity_logs").insert({
      user_id: user.id,
      action: "ADMIN_BROADCAST_SENT",
      details: {
        title,
        body,
        target,
        targetType,
        timestamp: new Date().toISOString(),
      },
    });

    return new Response(
      JSON.stringify({
        success: true,
        sentCount: finalResults.length,
        results: finalResults,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err: any) {
    console.error("Broadcast notification error:", err);
    return new Response(
      JSON.stringify({ error: err.message || "Internal server error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
