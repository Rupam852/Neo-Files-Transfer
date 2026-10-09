// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

// Convert PEM string to CryptoKey for RS256 signing
async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const cleanPem = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\\n/g, "")
    .replace(/\\r/g, "")
    .replace(/[\r\n\s]/g, "")
    .trim();

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

function base64url(input: string | Uint8Array): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  let binary = "";
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

// Generate Google OAuth2 Access Token using Service Account via standard WebCrypto
async function getGoogleAccessToken(clientEmail: string, privateKeyPem: string): Promise<string> {
  const privateKey = await importPrivateKey(privateKeyPem);
  const now = Math.floor(Date.now() / 1000);

  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: clientEmail,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };

  const unsignedJwt = base64url(JSON.stringify(header)) + "." + base64url(JSON.stringify(payload));
  const encoder = new TextEncoder();
  const signatureBuffer = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    privateKey,
    encoder.encode(unsignedJwt)
  );

  const signedJwt = unsignedJwt + "." + base64url(new Uint8Array(signatureBuffer));

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: signedJwt,
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
  targetType,
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
      title,
      body,
      ...dataPayload,
    },
    android: {
      priority: "high",
      notification: {
        channel_id: "neo_push_notifications",
        icon: "launcher_icon",
        sound: "default",
        default_sound: true,
        default_vibrate_timings: true,
        notification_priority: "PRIORITY_HIGH",
        visibility: "PUBLIC",
      },
    },
  };

  if (targetType === "topic") {
    message.topic = target.replace(/^\/topics\//, "");
  } else {
    message.token = target;
  }

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
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

    const reqBody = await req.json();

    // 1. Handle FCM Token Registration / Sync from mobile client
    if (reqBody.action === "sync_token") {
      const { userId, deviceId, fcmToken, deviceName, platform } = reqBody;
      if (!userId || !fcmToken || !deviceId) {
        return new Response(JSON.stringify({ error: "Missing required token sync fields" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      try {
        const { error: upsertErr } = await supabase.from("user_fcm_tokens").upsert({
          user_id: userId,
          device_id: deviceId,
          fcm_token: fcmToken,
          device_name: deviceName || "Android Device",
          platform: platform || "android",
          updated_at: new Date().toISOString(),
        }, { onConflict: "user_id,device_id" });

        if (upsertErr) {
          await supabase.from("user_fcm_tokens").delete().eq("user_id", userId).eq("device_id", deviceId);
          await supabase.from("user_fcm_tokens").insert({
            user_id: userId,
            device_id: deviceId,
            fcm_token: fcmToken,
            device_name: deviceName || "Android Device",
            platform: platform || "android",
            updated_at: new Date().toISOString(),
          });
        }
        return new Response(JSON.stringify({ success: true, message: "FCM token synced via service role" }), {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      } catch (syncErr) {
        return new Response(JSON.stringify({ error: String(syncErr) }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    if (reqBody.action === "unbind_token") {
      const { userId, deviceId } = reqBody;
      if (userId && deviceId) {
        await supabase.from("user_fcm_tokens").delete().eq("user_id", userId).eq("device_id", deviceId);
      }
      return new Response(JSON.stringify({ success: true, message: "Token unbound" }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const {
      title,
      body,
      targetType = "topic",
      target = "all_users",
      dataPayload = {},
    } = reqBody;

    if (!title || !body) {
      return new Response(JSON.stringify({ error: "Missing title or body" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Verify Admin authentication only if broadcasting to all users / topics
    const isTargetingSingleUser = (targetType === "user");
    let callingUserId = "system";

    if (!isTargetingSingleUser) {
      const authHeader = req.headers.get("Authorization");
      if (!authHeader) {
        return new Response(JSON.stringify({ error: "Missing authorization header" }), {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const token = authHeader.replace("Bearer ", "");
      let isServiceRole = (token === serviceRoleKey);

      if (!isServiceRole) {
        const { data: { user }, error: userError } = await supabase.auth.getUser(token);
        if (userError || !user) {
          return new Response(JSON.stringify({ error: "Unauthorized: Invalid user session" }), {
            status: 401,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        }
        callingUserId = user.id;

        // Check admin status by user_id OR email
        let isAdmin = false;
        const { data: adminById } = await supabase
          .from("admins")
          .select("id, role")
          .eq("user_id", user.id)
          .maybeSingle();

        if (adminById) {
          isAdmin = true;
        } else if (user.email) {
          const { data: adminByEmail } = await supabase
            .from("admins")
            .select("id, role")
            .eq("email", user.email.toLowerCase())
            .maybeSingle();
          if (adminByEmail) {
            isAdmin = true;
          }
        }

        if (!isAdmin) {
          return new Response(JSON.stringify({ error: "Forbidden: Your account does not have Admin privileges." }), {
            status: 403,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        }
      }
    }

    const fcmClientEmail = Deno.env.get("FCM_CLIENT_EMAIL") || "firebase-adminsdk-fbsvc@neo-files-transfer-24881.iam.gserviceaccount.com";
    const fcmProjectId = Deno.env.get("FCM_PROJECT_ID") || "neo-files-transfer-24881";
    let fcmPrivateKey = Deno.env.get("FCM_PRIVATE_KEY") || "";

    if (!fcmPrivateKey) {
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
      fcmPrivateKey = "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDjUkRGe0c7GlwS\noVvYD2m9DAqhNLHn4NHCY34qnmrB5uejwWPV8nzaKxxx7Daz5bv4UnSxga/reTnf\nNURQXLApBlyLj8ggJ/pylQXUW1P4yChFEEaD31shI/i9EeJuIoDZJ3fMQ0NKrY1/\nDU6rUR1gLu9rdDx1+yptlvj8bRlI7znvjO3SoByR00r2EIaP+tW5ze6My6Ok8POy\nyMHFKd92GD9ssWZhL2d6Two+Qq1f3myqL1pU55965GgmvEItZ4U3m2f34j3aNyKG\n7UbRNSptDUSnWFPtnK3c4VZlYuW8Q0Cshx4295DU2f1dO65KxnVH4lkrf7I4jVFB\n3U1Obuu3AgMBAAECggEAJnsIn73CoxilOWojOAHz7lKZggx/iTcfiv54nxJOFCDY\nWXolQlRYGj5uBELuR6m+Fh0vL9U6SGwvBb/ononyMB+pjt56DCd4V+kuIXKMVnLb\njkVhCnXG4WdLdgYPBIHGufvaZbOFMqEKcNV52bpTdLK9SL1Wdspbtk12PJTjUNsM\nf3KSAxO2BhS5ccM/60xGHciapizFGC/wvrH8f9dKov5lTgsvVxE3qJr6eQlDxwcb\n81tQbyPZCYMo1F22jKDvfhD7tx0k0L/GCAp71m+wxfXXgGrxwU3VVmuwCBM+dDq4\n3HGL8UGZvJPxINAOiqBgcUdi850BOOPsxgiWT7QzUQKBgQD7bsPR9ly93+2ayGq5\npwFcpjF1oB1B9sdrR78j+O9pNjrzobcyQYeX6aMbMTu37Fq0GZQYuCLgo9tvfbak\nNEr8GtgveqSHjMh14/IGGVscJwmoRpvGZCrXdfFCofCx1l9zBH7YGGQv0CnU9akT\nCxWFetExtymULD3i41sw26OOwwKBgQDnc2CLABUxhI9CGMV3qAkV5Ykr1ZKpYIMj\nAnE+f/IKNAaj+jmJf1BWeAMiaqx74e7/51dfdi4DEOdpX0KPwCxFM3U6+qjsNZrS\nq156/FnR9kwIx9+3TEICm+VEdVQ9DE56vf2mdt+NLkcUIHkB605JhtQ6uPbLzy4G\nh7xkWFaH/QKBgF0aqxB4tebpoMaMKFkO6oYwVGhGHg9rHnUvYCwl5iGDn1jQLVJC\nyb8LGQbcuExnDT9bqWdt6BxfEMa8OoGbi5jHJ/6M35gCHcjp25k+kmpeWkkhvFU+\nik62sdwGs2ZnB3lD1OSYQ6Eg6ByfyzfuBs4iqIxMUu03ZMM7hW0WJ/6ZAoGAKnB0\nhmhYeoD1B8ilBMDSEarKETiTMO2afiPnge9SAV7yzMSIIlcu8vwEjx4CTKDsAw53\nbfCslTFXTXIDMXqqY3IBD/SAXvehUPnNVD3Ldn10CbQkqGaaQAI38uqUrLEB/u2x\nggGQEkInFGCz748nBsJrTe02i76MkPP4rmmoTD0CgYEAtSwDYiDIrjsKWlPRRHkg\nR5hlo07pmoAa94AIncUd7dHtlKGNAPOcpd8UtDN/nxhZoav2lYJRvzTAUXgto8AQ\nuDjL1iBqlLVcmElzsY8+XJirMJlGBNapSiLzgmHF/9K6CrZJFuxrvO0OrgNqcNda\neYU9SDkKsB+yseasn9a6HPY=\n-----END PRIVATE KEY-----\n";
    }

    const accessToken = await getGoogleAccessToken(fcmClientEmail, fcmPrivateKey);
    let finalResults = [];

    if (targetType === "user") {
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
      const res = await sendFcmMessage({
        projectId: fcmProjectId,
        accessToken,
        target: target === "all_users" ? "all_users" : target,
        targetType: target.startsWith("user_") || target === "all_users" || target === "app_updates" ? "topic" : "token",
        title,
        body,
        dataPayload,
      });
      finalResults.push(res);
    }

    // Log admin activity
    try {
      await supabase.from("admin_activity_logs").insert({
        admin_id: callingUserId === "system" ? null : callingUserId,
        action: "push_broadcast",
        details: `Broadcast push sent: "${title}" to ${targetType}:${target}`,
      });
    } catch (_) {}

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
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
