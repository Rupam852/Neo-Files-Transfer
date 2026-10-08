/**
 * Cloudflare Worker for Ultra High-Speed Google Drive Downloads
 * With Real-Time Download Logging & Supabase Owner Notifications
 * 
 * Domain: download.neofilestransfer.site
 */

const SUPABASE_URL = "https://opdeyfbbkcuqljgjldys.supabase.co"
// Use your Supabase Service Role Key or Anon Key with public table permissions
const SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9wZGV5ZmJia2N1cWxqZ2psZHlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIxNDU1ODEsImV4cCI6MjA5NzcyMTU4MX0.ORIxfisjAaoxvKI7PWEGk0tPS_cP0rvG_Ytio7h4xCc"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS",
  "Access-Control-Allow-Headers": "*",
  "Access-Control-Expose-Headers": "content-length, content-disposition",
}

function parseUserAgent(ua) {
  const userAgent = ua || ""
  const isMobile = /mobile|android|iphone|ipad/i.test(userAgent)
  const deviceType = isMobile ? "Mobile" : "Desktop"
  const browser = /chrome/i.test(userAgent) ? "Chrome" : /firefox/i.test(userAgent) ? "Firefox" : /safari/i.test(userAgent) ? "Safari" : /edge/i.test(userAgent) ? "Edge" : "Browser"
  const os = /android/i.test(userAgent) ? "Android" : /windows/i.test(userAgent) ? "Windows" : /mac/i.test(userAgent) ? "macOS" : /linux/i.test(userAgent) ? "Linux" : /ios|iphone|ipad/i.test(userAgent) ? "iOS" : "OS"
  return { deviceType, browser, os }
}

export default {
  async fetch(request, env, ctx) {
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders })
    }

    const url = new URL(request.url)
    const pathname = url.pathname.replace(/\/+$/, "")
    const hash = url.searchParams.get("hash")
    const isStream = url.searchParams.get("stream") === "true"
    const skipIncrement = url.searchParams.get("skip_increment") === "true"

    const sbUrl = env?.SUPABASE_URL || SUPABASE_URL
    const sbKey = env?.SUPABASE_SERVICE_ROLE_KEY || env?.SUPABASE_KEY || SUPABASE_KEY

    // Health / Ping / Keep-Alive Endpoint (keeps Supabase PostgreSQL awake & active)
    if (pathname === "/ping" || pathname === "/health" || pathname === "/keep-alive" || (!hash && (pathname === "" || pathname === "/"))) {
      try {
        const pingDb = await fetch(
          `${sbUrl}/rest/v1/shared_files?select=id&limit=1`,
          {
            headers: {
              apikey: sbKey,
              Authorization: `Bearer ${sbKey}`,
            },
          }
        )
        const dbStatus = pingDb.ok ? "healthy" : `status ${pingDb.status}`
        return new Response(
          JSON.stringify({
            status: "ok",
            message: "Neo Files Edge Worker & Supabase DB are active!",
            database: dbStatus,
            timestamp: new Date().toISOString()
          }, null, 2),
          {
            status: 200,
            headers: {
              "Content-Type": "application/json",
              ...corsHeaders
            }
          }
        )
      } catch (err) {
        return new Response(
          JSON.stringify({
            status: "error",
            message: "Ping failed to reach Supabase",
            error: err.message
          }),
          {
            status: 500,
            headers: {
              "Content-Type": "application/json",
              ...corsHeaders
            }
          }
        )
      }
    }

    const fileId = url.searchParams.get("file_id")

    if (!hash && !fileId) {
      return new Response(
        JSON.stringify({ error: "File Hash or File ID is required" }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
      )
    }

    try {
      let file = null

      // 0. Direct lookup by file_id
      if (fileId) {
        const fileByIdRes = await fetch(
          `${sbUrl}/rest/v1/shared_files?id=eq.${fileId}&select=id,file_name,mime_type,file_size,sharing_status,google_drive_file_id,user_id,is_folder`,
          {
            headers: {
              apikey: sbKey,
              Authorization: `Bearer ${sbKey}`,
            },
          }
        )
        if (fileByIdRes.ok) {
          const list = await fileByIdRes.json()
          if (list && list.length > 0) {
            file = list[0]
          }
        }
      }

      // 1. Fetch file record by unique_share_hash
      if (!file && hash) {
        const fileRes = await fetch(
          `${sbUrl}/rest/v1/shared_files?unique_share_hash=eq.${hash}&select=id,file_name,mime_type,file_size,sharing_status,google_drive_file_id,user_id,is_folder`,
          {
            headers: {
              apikey: sbKey,
              Authorization: `Bearer ${sbKey}`,
            },
          }
        )

        if (fileRes.ok) {
          const list = await fileRes.json()
          if (list && list.length > 0) {
            file = list[0]
          }
        }
      }

      // If not found in standard shared_files, check custom_share_links
      let customLink = null
      if (!file) {
        const linkRes = await fetch(
          `${sbUrl}/rest/v1/custom_share_links?custom_share_hash=eq.${hash}&select=*`,
          {
            headers: {
              apikey: sbKey,
              Authorization: `Bearer ${sbKey}`,
            },
          }
        )
        if (linkRes.ok) {
          const links = await linkRes.json()
          if (links && links.length > 0) {
            customLink = links[0]
            if (customLink.expires_at && new Date(customLink.expires_at) < new Date()) {
              return new Response(JSON.stringify({ error: "Share link has expired" }), { status: 410, headers: corsHeaders })
            }
            if (customLink.max_downloads && customLink.download_count >= customLink.max_downloads) {
              return new Response(JSON.stringify({ error: "Download limit reached" }), { status: 410, headers: corsHeaders })
            }

            const linkedFileRes = await fetch(
              `${sbUrl}/rest/v1/shared_files?id=eq.${customLink.file_id}&select=id,file_name,mime_type,file_size,sharing_status,google_drive_file_id,user_id,is_folder`,
              {
                headers: {
                  apikey: sbKey,
                  Authorization: `Bearer ${sbKey}`,
                },
              }
            )
            if (linkedFileRes.ok) {
              const linkedList = await linkedFileRes.json()
              if (linkedList && linkedList.length > 0) {
                file = linkedList[0]
              }
            }
          }
        }
      }

      if (!file) {
        return new Response(
          JSON.stringify({ error: "File not found or link has expired" }),
          { status: 404, headers: { "Content-Type": "application/json", ...corsHeaders } }
        )
      }

      // If it's a folder, redirect to Render proxy for dynamic ZIP compilation
      if (file.is_folder) {
        return Response.redirect(`https://api.neofilestransfer.site/download-file?hash=${hash}`, 302)
      }

      // 2. Fetch Owner's Google Tokens
      const profileRes = await fetch(
        `${sbUrl}/rest/v1/user_profiles?id=eq.${file.user_id}&select=google_access_token,google_refresh_token`,
        {
          headers: {
            apikey: sbKey,
            Authorization: `Bearer ${sbKey}`,
          },
        }
      )

      if (!profileRes.ok) {
        throw new Error("Failed to load user profile credentials")
      }

      const profiles = await profileRes.json()
      if (!profiles || profiles.length === 0) {
        throw new Error("File owner credentials not found")
      }

      let accessToken = profiles[0].google_access_token

      // 3. Fetch media from Google Drive with edge streaming
      const driveHeaders = {
        Authorization: `Bearer ${accessToken}`,
      }

      const clientRange = request.headers.get("range")
      if (clientRange) {
        driveHeaders["Range"] = clientRange
      }

      const driveRes = await fetch(
        `https://www.googleapis.com/drive/v3/files/${file.google_drive_file_id}?alt=media`,
        {
          headers: driveHeaders,
        }
      )

      if (!driveRes.ok && driveRes.status !== 206) {
        // Fallback: Redirect to Render proxy if token expired
        return Response.redirect(`https://api.neofilestransfer.site/download-file?hash=${hash}`, 302)
      }

      // 4. Build high-performance streaming response headers
      const resHeaders = new Headers(driveRes.headers)
      resHeaders.set("Content-Disposition", `attachment; filename="${encodeURIComponent(file.file_name)}"; filename*=UTF-8''${encodeURIComponent(file.file_name)}`)
      resHeaders.set("Content-Type", file.mime_type || driveRes.headers.get("content-type") || "application/octet-stream")
      resHeaders.set("Cache-Control", "no-cache, no-store, must-revalidate")

      for (const [k, v] of Object.entries(corsHeaders)) {
        resHeaders.set(k, v)
      }

      // 5. ASYNCHRONOUS NON-BLOCKING DOWNLOAD LOG & NOTIFICATION (Zero latency impact!)
      if (!skipIncrement && ctx?.waitUntil) {
        ctx.waitUntil(
          (async () => {
            try {
              const { deviceType, browser, os } = parseUserAgent(request.headers.get("user-agent"))

              // A. Increment download count RPC
              fetch(`${sbUrl}/rest/v1/rpc/increment_download_count`, {
                method: "POST",
                headers: {
                  apikey: sbKey,
                  Authorization: `Bearer ${sbKey}`,
                  "Content-Type": "application/json",
                },
                body: JSON.stringify({ file_id: file.id }),
              }).catch(() => {})

              // B. Insert into file_download_logs (which triggers Supabase In-App Notification instantly!)
              await fetch(`${sbUrl}/rest/v1/file_download_logs`, {
                method: "POST",
                headers: {
                  apikey: sbKey,
                  Authorization: `Bearer ${sbKey}`,
                  "Content-Type": "application/json",
                  Prefer: "return=minimal",
                },
                body: JSON.stringify({
                  file_id: file.id,
                  owner_id: file.user_id,
                  custom_link_id: customLink ? customLink.id : null,
                  device_type: deviceType,
                  browser: browser,
                  os: os,
                }),
              })
            } catch (bgErr) {
              console.error("Cloudflare background log error:", bgErr)
            }
          })()
        )
      }

      return new Response(driveRes.body, {
        status: driveRes.status,
        headers: resHeaders,
      })

    } catch (err) {
      console.error("Cloudflare Worker Error:", err)
      return new Response(
        JSON.stringify({ error: err.message || "An unexpected worker error occurred" }),
        { status: 500, headers: { "Content-Type": "application/json", ...corsHeaders } }
      )
    }
  },
}
