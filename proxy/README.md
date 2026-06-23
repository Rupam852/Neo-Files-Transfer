# Neo Transfer Download Proxy

High-performance streaming proxy for Neo Files Transfer. Handles single files and folder-to-zip compression on-the-fly without memory leaks or execution limits.

## How to Deploy on Render

1. Go to [Render Dashboard](https://dashboard.render.com/) and click **New > Web Service**.
2. Connect your GitHub repository.
3. Set the following settings:
   - **Root Directory**: `proxy` (Very important so Render only builds this folder!)
   - **Runtime**: `Node`
   - **Build Command**: `npm install`
   - **Start Command**: `npm start`
4. Add the following **Environment Variables** in the Render setup:
   - `SUPABASE_URL`: Your Supabase Project URL (e.g. `https://xxxx.supabase.co`)
   - `SUPABASE_SERVICE_ROLE_KEY`: Your Supabase service_role key (bypasses RLS to read file metadata).
   - `GOOGLE_CLIENT_ID`: Your Google OAuth Client ID.
   - `GOOGLE_CLIENT_SECRET`: Your Google OAuth Client Secret.
5. Click **Deploy Web Service**.

Once deployed, copy the Render URL (e.g., `https://neo-transfer-proxy.onrender.com`).

## Connecting the Frontend

Open your frontend project env file (or dashboard settings in Netlify/Vercel) and add the following variable:

```env
VITE_PROXY_URL=https://neo-transfer-proxy.onrender.com
```

Now, the frontend will automatically use this Render proxy instead of the Supabase Edge Function, enabling unlimited file size downloads and folder compression on all devices!
