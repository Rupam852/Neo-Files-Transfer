// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import nodemailer from "npm:nodemailer"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

const SMTP_USER = "neofilestransfar@gmail.com"
const SMTP_PASS = "ufvjbezstctwamqy"

// Create Gmail Transporter
const transporter = nodemailer.createTransport({
  host: "smtp.gmail.com",
  port: 465,
  secure: true, // true for 465, false for other ports
  auth: {
    user: SMTP_USER,
    pass: SMTP_PASS,
  },
})

serve(async (req) => {
  // Handle CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? ""
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    
    // Create service client to bypass RLS
    const supabase = createClient(supabaseUrl, serviceRoleKey)

    // Parse URL path to resolve endpoint
    const url = new URL(req.url)
    const path = url.pathname

    if (path.endsWith("/send-otp")) {
      const { email, name, phone } = await req.json()
      if (!email || !name || !phone) {
        throw new Error("Missing email, name, or phone")
      }

      const normalizedEmail = email.trim().toLowerCase()

      // Fetch existing verification record
      const { data: existing, error: fetchError } = await supabase
        .from("email_verifications")
        .select("*")
        .eq("email", normalizedEmail)
        .maybeSingle()

      const now = new Date()

      // Check if user is currently blocked
      if (existing && existing.blocked_until) {
        const blockedUntil = new Date(existing.blocked_until)
        if (blockedUntil > now) {
          const diffMs = blockedUntil.getTime() - now.getTime()
          const diffMins = Math.ceil(diffMs / 60000)
          return new Response(
            JSON.stringify({ 
              error: `You have requested too many OTPs. You are blocked from resending for ${diffMins} minutes. Please check your spam folder.` 
            }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 429 }
          )
        } else {
          // Block expired, reset count
          await supabase
            .from("email_verifications")
            .update({ resend_count: 0, blocked_until: null })
            .eq("email", normalizedEmail)
        }
      }

      // Calculate resend count
      let currentResends = existing ? existing.resend_count : 0
      currentResends += 1

      if (currentResends > 5) {
        // Block user for 1 hour
        const blockTime = new Date(now.getTime() + 60 * 60 * 1000) // 1 hour later
        if (existing) {
          await supabase
            .from("email_verifications")
            .update({ resend_count: currentResends, blocked_until: blockTime.toISOString() })
            .eq("email", normalizedEmail)
        } else {
          // Generate a fake OTP just to create the row
          await supabase
            .from("email_verifications")
            .insert({
              email: normalizedEmail,
              otp_code: "BLOCKED",
              expires_at: now.toISOString(),
              resend_count: currentResends,
              blocked_until: blockTime.toISOString()
            })
        }

        return new Response(
          JSON.stringify({ 
            error: "You have requested too many OTPs. You are blocked from resending for 1 hour. Please check your spam folder." 
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 429 }
        )
      }

      // Generate 6-digit numeric OTP
      const otp = Math.floor(100000 + Math.random() * 900000).toString()
      const expiry = new Date(now.getTime() + 10 * 60 * 1000) // 10 minutes expiry

      // Save to database
      if (existing) {
        await supabase
          .from("email_verifications")
          .update({
            otp_code: otp,
            expires_at: expiry.toISOString(),
            resend_count: currentResends,
            attempts: 0 // Reset validation attempts
          })
          .eq("email", normalizedEmail)
      } else {
        await supabase
          .from("email_verifications")
          .insert({
            email: normalizedEmail,
            otp_code: otp,
            expires_at: expiry.toISOString(),
            resend_count: currentResends,
            attempts: 0
          })
      }

      // Send email via Gmail SMTP
      await transporter.sendMail({
        from: `"Neo Files Transfer" <${SMTP_USER}>`,
        to: normalizedEmail,
        subject: "Verify your email address - Neo Files Transfer",
        html: `
          <div style="font-family: sans-serif; max-width: 500px; margin: 0 auto; padding: 20px; border: 1px solid #e2e8f0; rounded-lg: 12px; background-color: #030712; color: #f1f5f9;">
            <div style="text-align: center; margin-bottom: 20px;">
              <h2 style="color: #6366f1; font-weight: bold; font-size: 24px;">NeoFiles</h2>
            </div>
            <p style="font-size: 15px; line-height: 1.5; color: #cbd5e1;">Hi ${name},</p>
            <p style="font-size: 15px; line-height: 1.5; color: #cbd5e1;">Thank you for requesting access to the Neo Files Transfer console. To proceed with your request, please verify your email address using the one-time verification code below:</p>
            <div style="text-align: center; margin: 30px 0;">
              <span style="font-size: 32px; font-weight: bold; letter-spacing: 6px; padding: 12px 24px; background-color: #0f172a; border: 1px solid #334155; border-radius: 8px; color: #818cf8; display: inline-block;">${otp}</span>
            </div>
            <p style="font-size: 13px; line-height: 1.5; color: #94a3b8;">This verification code is valid for 10 minutes. If you did not make this request, you can safely ignore this email.</p>
            <p style="font-size: 13px; font-weight: bold; color: #fbbf24; border-top: 1px dashed #334155; padding-top: 15px; margin-top: 25px;">IMPORTANT: Please check your Spam folder if this email does not arrive in your Inbox within a minute.</p>
          </div>
        `,
      })

      return new Response(
        JSON.stringify({ success: true, message: "Verification code sent to your email" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      )

    } else if (path.endsWith("/verify-otp")) {
      const { email, name, phone, otp } = await req.json()
      if (!email || !name || !phone || !otp) {
        throw new Error("Missing verification parameters")
      }

      const normalizedEmail = email.trim().toLowerCase()

      // Fetch verification record
      const { data: record, error: fetchError } = await supabase
        .from("email_verifications")
        .select("*")
        .eq("email", normalizedEmail)
        .maybeSingle()

      if (!record) {
        throw new Error("No verification code found. Please request a new OTP.")
      }

      // Check block expiration
      const now = new Date()
      if (record.blocked_until) {
        const blockedUntil = new Date(record.blocked_until)
        if (blockedUntil > now) {
          throw new Error("You are temporarily blocked from submitting requests. Please try again after 1 hour.")
        }
      }

      // Check OTP expiry
      const expiresAt = new Date(record.expires_at)
      if (expiresAt < now) {
        throw new Error("Verification code has expired. Please resend a new OTP.")
      }

      // Check OTP value
      if (record.otp_code !== otp.trim()) {
        const newAttempts = record.attempts + 1
        if (newAttempts >= 3) {
          // Expire OTP and block user if they fail repeatedly
          await supabase
            .from("email_verifications")
            .update({ attempts: newAttempts, expires_at: now.toISOString() })
            .eq("email", normalizedEmail)
          throw new Error("Too many incorrect attempts. This OTP has been expired. Please request a new one.")
        } else {
          await supabase
            .from("email_verifications")
            .update({ attempts: newAttempts })
            .eq("email", normalizedEmail)
          throw new Error(`Incorrect verification code. Attempts left: ${3 - newAttempts}`)
        }
      }

      // Insert into pending_registrations
      const { error: registerError } = await supabase
        .from("pending_registrations")
        .insert({
          name: name.trim(),
          phone: phone.trim(),
          email: normalizedEmail,
          status: "pending",
        })

      if (registerError) {
        // If email already has an active pending/approved registration
        if (registerError.code === "23505" || registerError.message?.includes("unique")) {
          throw new Error("This email is already registered.")
        }
        throw registerError
      }

      // Delete verification record
      await supabase
        .from("email_verifications")
        .delete()
        .eq("email", normalizedEmail)

      // Send email to Admin
      const ADMIN_EMAIL = "rupambairagya08@gmail.com"
      await transporter.sendMail({
        from: `"Neo Files Notification" <${SMTP_USER}>`,
        to: ADMIN_EMAIL,
        subject: "New Console Access Request - Neo Files Transfer",
        html: `
          <div style="font-family: sans-serif; max-width: 500px; margin: 0 auto; padding: 20px; border: 1px solid #cbd5e1; border-radius: 8px;">
            <h3 style="color: #4f46e5; border-bottom: 2px solid #f1f5f9; padding-bottom: 10px; margin-top: 0;">New Request Received</h3>
            <p style="font-size: 14px; line-height: 1.5;">Hello Admin,</p>
            <p style="font-size: 14px; line-height: 1.5;">A new user has successfully verified their email address and requested access to the console node:</p>
            <table style="width: 100%; font-size: 13px; margin: 15px 0; border-collapse: collapse;">
              <tr>
                <td style="font-weight: bold; padding: 6px 0; width: 35%;">Name:</td>
                <td style="padding: 6px 0;">${name}</td>
              </tr>
              <tr>
                <td style="font-weight: bold; padding: 6px 0;">Email:</td>
                <td style="padding: 6px 0;">${normalizedEmail}</td>
              </tr>
              <tr>
                <td style="font-weight: bold; padding: 6px 0;">Phone:</td>
                <td style="padding: 6px 0;">${phone}</td>
              </tr>
            </table>
            <p style="font-size: 14px; line-height: 1.5;">Please log in to your admin dashboard to review and approve/reject this request.</p>
          </div>
        `,
      })

      return new Response(
        JSON.stringify({ success: true, message: "Email verified and request submitted successfully." }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      )

    } else if (path.endsWith("/notify-user")) {
      // Admin notification trigger
      const authHeader = req.headers.get("Authorization")
      if (!authHeader) {
        throw new Error("Missing authorization header")
      }

      // Verify caller is authenticated and is an admin
      const userClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY") ?? "", {
        global: { headers: { Authorization: authHeader } }
      })

      const { data: { user }, error: userError } = await userClient.auth.getUser()
      if (userError || !user) {
        return new Response(JSON.stringify({ error: "Unauthorized" }), { headers: corsHeaders, status: 401 })
      }

      const { data: adminRecord, error: adminError } = await supabase
        .from("admins")
        .select("id")
        .eq("user_id", user.id)
        .maybeSingle()

      if (adminError || !adminRecord) {
        return new Response(JSON.stringify({ error: "Access Denied: Admin role required" }), { headers: corsHeaders, status: 403 })
      }

      const { email, action } = await req.json()
      if (!email || !action) {
        throw new Error("Missing email or action")
      }

      const targetEmail = email.trim().toLowerCase()
      let subject = ""
      let htmlBody = ""

      if (action === "approved") {
        subject = "Console Access Request Approved - Neo Files Transfer"
        htmlBody = `
          <div style="font-family: sans-serif; max-width: 500px; margin: 0 auto; padding: 20px; border: 1px solid #cbd5e1; border-radius: 8px;">
            <h3 style="color: #10b981; border-bottom: 2px solid #f1f5f9; padding-bottom: 10px; margin-top: 0;">Request Approved</h3>
            <p style="font-size: 14px; line-height: 1.5;">Hello,</p>
            <p style="font-size: 14px; line-height: 1.5;">We are pleased to inform you that your request for console access has been <strong>approved</strong> by the administrator.</p>
            <p style="font-size: 14px; line-height: 1.5;">You can now log in to the console using your Google account:</p>
            <div style="text-align: center; margin: 25px 0;">
              <a href="${Deno.env.get("VITE_APP_URL") || "https://neo-files-transfer.pages.dev"}/login" style="background-color: #4f46e5; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; font-weight: bold; display: inline-block;">Log In to Console</a>
            </div>
            <p style="font-size: 13px; color: #64748b;">If you have any questions, please contact our support team.</p>
          </div>
        `
      } else if (action === "rejected") {
        subject = "Console Access Request Status - Neo Files Transfer"
        htmlBody = `
          <div style="font-family: sans-serif; max-width: 500px; margin: 0 auto; padding: 20px; border: 1px solid #cbd5e1; border-radius: 8px;">
            <h3 style="color: #ef4444; border-bottom: 2px solid #f1f5f9; padding-bottom: 10px; margin-top: 0;">Request Rejected</h3>
            <p style="font-size: 14px; line-height: 1.5;">Hello,</p>
            <p style="font-size: 14px; line-height: 1.5;">We regret to inform you that your request for console access has been <strong>rejected</strong> by the administrator.</p>
            <p style="font-size: 14px; line-height: 1.5;">If you believe this is a mistake, please reach out to the administrator to resolve the issue.</p>
          </div>
        `
      } else if (action === "suspended") {
        subject = "Console Account Status - Neo Files Transfer"
        htmlBody = `
          <div style="font-family: sans-serif; max-width: 500px; margin: 0 auto; padding: 20px; border: 1px solid #cbd5e1; border-radius: 8px;">
            <h3 style="color: #f59e0b; border-bottom: 2px solid #f1f5f9; padding-bottom: 10px; margin-top: 0;">Account Suspended</h3>
            <p style="font-size: 14px; line-height: 1.5;">Hello,</p>
            <p style="font-size: 14px; line-height: 1.5;">Please note that your access request has been <strong>suspended/deleted</strong> by the administrator.</p>
            <p style="font-size: 14px; line-height: 1.5; color: #ef4444; font-weight: bold;">Admin suspended your account. Please resubmit your request and connect with the administrator.</p>
          </div>
        `
      } else {
        throw new Error("Invalid notification action type")
      }

      await transporter.sendMail({
        from: `"Neo Files Support" <${SMTP_USER}>`,
        to: targetEmail,
        subject: subject,
        html: htmlBody,
      })

      return new Response(
        JSON.stringify({ success: true, message: "User status email sent successfully." }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      )
    } else {
      return new Response("Not found", { headers: corsHeaders, status: 404 })
    }

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
