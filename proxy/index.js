import express from 'express'
import cors from 'cors'
import { createClient } from '@supabase/supabase-js'
import archiver from 'archiver'
import { Readable } from 'stream'

const app = express()
const PORT = process.env.PORT || 3001

// Setup CORS
app.use(cors({
  origin: '*',
  exposedHeaders: ['content-length', 'content-disposition']
}))

// Simple health check
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', service: 'neo-transfer-proxy' })
})

// Endpoint to refresh and return the Google access token to the frontend
app.get('/refresh-token', async (req, res) => {
  try {
    const supabaseUrl = process.env.SUPABASE_URL
    const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY
    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Supabase environment variables are missing on the proxy server.')
    }
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)

    // Authenticate user via Supabase JWT
    const user = await getAuthenticatedUser(req, supabaseAdmin)

    // Get Owner's Google Tokens
    const { data: profile, error: profileError } = await supabaseAdmin
      .from('user_profiles')
      .select('google_access_token, google_refresh_token')
      .eq('id', user.id)
      .single()

    if (profileError || !profile) {
      throw new Error('Failed to load user profile Google tokens.')
    }

    if (!profile.google_refresh_token) {
      throw new Error('No Google refresh token is available.')
    }

    // Refresh Google access token
    const newAccessToken = await refreshGoogleToken(user.id, profile.google_refresh_token, supabaseAdmin)

    return res.status(200).json({ google_access_token: newAccessToken })
  } catch (err) {
    console.error('Refresh Token Proxy Error:', err)
    return res.status(400).json({ error: err.message || 'Failed to refresh Google token.' })
  }
})

// Main download endpoint
app.get('/download-file', async (req, res) => {
  const hash = req.query.hash
  const isStream = req.query.stream === 'true'

  if (!hash) {
    return res.status(400).json({ error: 'File Hash Required' })
  }

  try {
    // Verify environment variables
    const supabaseUrl = process.env.SUPABASE_URL
    const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY
    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Supabase environment variables are missing on the proxy server.')
    }

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)

    // 1. Resolve file metadata by share hash
    const { data: file, error: fileError } = await supabaseAdmin
      .from('shared_files')
      .select('id, file_name, mime_type, sharing_status, current_version_num, google_drive_file_id, is_folder, user_id, file_size')
      .eq('unique_share_hash', hash)
      .maybeSingle()

    if (fileError || !file) {
      return res.status(404).json({ error: 'The requested file does not exist or has been removed.' })
    }

    // 2. Check sharing status
    if (file.sharing_status === 'private') {
      return res.status(403).json({ error: 'This file is private and cannot be downloaded.' })
    }

    // 3. Check system setting for downloads
    const { data: downloadSetting } = await supabaseAdmin
      .from('system_settings')
      .select('value')
      .eq('key', 'downloads_enabled')
      .maybeSingle()

    if (downloadSetting && downloadSetting.value === false) {
      return res.status(503).json({ error: 'Downloads are currently disabled by the administrator.' })
    }

    // 4. Resolve correct Google Drive file ID (latest version)
    const { data: latestVersion } = await supabaseAdmin
      .from('file_versions')
      .select('google_drive_file_id')
      .eq('file_id', file.id)
      .order('version_number', { ascending: false })
      .limit(1)
      .maybeSingle()

    const driveFileId = latestVersion?.google_drive_file_id || file.google_drive_file_id

    // 5. Get Owner's Google Tokens
    const { data: ownerProfile, error: ownerError } = await supabaseAdmin
      .from('user_profiles')
      .select('google_access_token, google_refresh_token')
      .eq('id', file.user_id)
      .single()

    if (ownerError || !ownerProfile) {
      throw new Error('Failed to retrieve file owner credentials.')
    }

    let accessToken = ownerProfile.google_access_token
    const refreshToken = ownerProfile.google_refresh_token

    if (!accessToken && refreshToken) {
      accessToken = await refreshGoogleToken(file.user_id, refreshToken, supabaseAdmin)
    } else if (!accessToken) {
      throw new Error("Owner's Google authentication connection is missing.")
    }

    // Helper to fetch file stream from Google Drive
    const fetchMediaFromDrive = async (driveId, token) => {
      return await fetch(
        `https://www.googleapis.com/drive/v3/files/${driveId}?alt=media`,
        {
          headers: {
            Authorization: `Bearer ${token}`,
          },
        }
      )
    }

    // --- CASE A: DOWNLOAD DIRECTORY (COMPRESS & STREAM ZIP ON-THE-FLY) ---
    if (file.is_folder) {
      const { data: allFiles, error: allFilesError } = await supabaseAdmin
        .from('shared_files')
        .select('id, file_name, is_folder, google_drive_file_id, mime_type, parent_folder_id')
        .eq('user_id', file.user_id)

      if (allFilesError || !allFiles) {
        throw new Error('Failed to load folder contents metadata.')
      }

      const filesToZip = []
      
      const buildTree = (folderId, currentPath) => {
        const children = allFiles.filter(f => f.parent_folder_id === folderId)
        for (const child of children) {
          const relativePath = currentPath ? `${currentPath}/${child.file_name}` : child.file_name
          if (child.is_folder) {
            filesToZip.push({
              google_drive_file_id: child.google_drive_file_id,
              relativePath: relativePath,
              is_folder: true,
              file_name: child.file_name
            })
            buildTree(child.id, relativePath)
          } else {
            filesToZip.push({
              google_drive_file_id: child.google_drive_file_id,
              relativePath: relativePath,
              is_folder: false,
              file_name: child.file_name
            })
          }
        }
      }

      buildTree(file.id, file.file_name)

      // Add root folder to ensure directory structure is created even if empty
      filesToZip.push({
        google_drive_file_id: file.google_drive_file_id,
        relativePath: file.file_name,
        is_folder: true,
        file_name: file.file_name
      })

      // Set headers for ZIP stream
      res.setHeader('Content-Type', 'application/zip')
      res.setHeader('Content-Disposition', `attachment; filename="${encodeURIComponent(file.file_name)}.zip"; filename*=UTF-8''${encodeURIComponent(file.file_name)}.zip`)
      res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate')

      const archive = archiver('zip', { zlib: { level: 5 } })
      
      archive.on('error', (err) => {
        console.error('Archiver error:', err)
        if (!res.headersSent) {
          res.status(500).end('ZIP compilation aborted due to an internal error.')
        }
      })

      // Pipe archive stream directly to response
      archive.pipe(res)

      // Process and append files one by one (fully streamed)
      for (const item of filesToZip) {
        if (item.is_folder) {
          archive.append('', { name: item.relativePath + '/' })
          continue
        }

        try {
          let fileResponse = await fetchMediaFromDrive(item.google_drive_file_id, accessToken)

          if (fileResponse.status === 401 && refreshToken) {
            accessToken = await refreshGoogleToken(file.user_id, refreshToken, supabaseAdmin)
            fileResponse = await fetchMediaFromDrive(item.google_drive_file_id, accessToken)
          }

          if (fileResponse.ok && fileResponse.body) {
            // Convert Web ReadableStream to Node Readable
            const nodeReadableStream = Readable.fromWeb(fileResponse.body)
            archive.append(nodeReadableStream, { name: item.relativePath })
          } else {
            console.error(`Failed to fetch file ${item.file_name} from Drive during folder compilation. Status: ${fileResponse.status}`)
          }
        } catch (itemErr) {
          console.error(`Error processing file ${item.file_name} for ZIP:`, itemErr)
        }
      }

      // Finalize the archive stream
      archive.finalize()
      return
    }

    // --- CASE B: SINGLE FILE STREAMING ---
    let driveResponse = await fetchMediaFromDrive(driveFileId, accessToken)

    if (driveResponse.status === 401 && refreshToken) {
      try {
        accessToken = await refreshGoogleToken(file.user_id, refreshToken, supabaseAdmin)
        driveResponse = await fetchMediaFromDrive(driveFileId, accessToken)
      } catch (refreshErr) {
        console.error('Token refresh failed during download retry:', refreshErr)
      }
    }

    if (!driveResponse.ok) {
      console.error('Google Drive alt=media fetch failed with status:', driveResponse.status)
      const downloadUrl = `https://drive.google.com/uc?export=download&id=${driveFileId}`
      if (isStream) {
        return res.status(400).json({
          error: `Failed to fetch file content from Google Drive (HTTP ${driveResponse.status})`,
          fallbackUrl: downloadUrl
        })
      }
      return res.redirect(downloadUrl)
    }

    // Set correct headers
    const contentType = file.mime_type || driveResponse.headers.get('Content-Type') || 'application/octet-stream'
    res.setHeader('Content-Type', contentType)
    res.setHeader('Content-Disposition', `attachment; filename="${encodeURIComponent(file.file_name)}"; filename*=UTF-8''${encodeURIComponent(file.file_name)}`)
    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate')
    
    const gDriveContentLength = driveResponse.headers.get('Content-Length')
    if (gDriveContentLength) {
      res.setHeader('Content-Length', gDriveContentLength)
    } else if (file.file_size) {
      res.setHeader('Content-Length', file.file_size)
    }

    // Stream directly from Drive to Client
    const driveStream = Readable.fromWeb(driveResponse.body)
    driveStream.pipe(res)

  } catch (error) {
    console.error('Download Proxy Error:', error)
    if (!res.headersSent) {
      res.status(500).json({ error: error.message || 'An unexpected proxy server error occurred.' })
    }
  }
})

// Helper to authenticate user using Supabase JWT token
async function getAuthenticatedUser(req, supabaseAdmin) {
  const authHeader = req.headers.authorization || req.headers.Authorization
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    throw new Error('Missing or invalid authorization header')
  }
  const token = authHeader.split(' ')[1]
  const { data: { user }, error } = await supabaseAdmin.auth.getUser(token)
  if (error || !user) {
    throw new Error('User authentication failed: ' + (error?.message || 'Invalid session'))
  }
  return user
}

// Streaming upload endpoint using Google Drive Resumable Upload API
app.post('/upload-file', async (req, res) => {
  try {
    const supabaseUrl = process.env.SUPABASE_URL
    const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY
    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Supabase environment variables are missing on the proxy server.')
    }
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)

    // Authenticate user via Supabase JWT
    const user = await getAuthenticatedUser(req, supabaseAdmin)

    // Retrieve headers
    const fileName = decodeURIComponent(req.headers['x-file-name'] || '')
    const folderId = req.headers['x-folder-id']
    const fileType = req.headers['x-file-type'] || 'application/octet-stream'
    const fileSize = req.headers['x-file-size']
    const oldFileId = req.headers['x-old-file-id'] // Optional: For version replacements

    if (!fileName || !folderId) {
      return res.status(400).json({ error: 'Missing x-file-name or x-folder-id headers.' })
    }

    // Get Owner's Google Tokens
    const { data: profile, error: profileError } = await supabaseAdmin
      .from('user_profiles')
      .select('google_access_token, google_refresh_token')
      .eq('id', user.id)
      .single()

    if (profileError || !profile) {
      throw new Error('Failed to load user profile Google tokens.')
    }

    let accessToken = profile.google_access_token
    const refreshToken = profile.google_refresh_token

    if (!accessToken && refreshToken) {
      accessToken = await refreshGoogleToken(user.id, refreshToken, supabaseAdmin)
    } else if (!accessToken) {
      throw new Error("Owner's Google authentication connection is missing.")
    }

    // Helper to start the Resumable session on Google Drive
    const startResumableSession = async (token) => {
      return await fetch(
        'https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable',
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json; charset=UTF-8',
            'X-Upload-Content-Type': fileType
          },
          body: JSON.stringify({
            name: fileName,
            parents: [folderId]
          })
        }
      )
    }

    let initiateResponse = await startResumableSession(accessToken)

    // Handle token expiration / 401 status
    if (initiateResponse.status === 401 && refreshToken) {
      console.log('Google Drive upload initiate returned 401. Refreshing token...')
      accessToken = await refreshGoogleToken(user.id, refreshToken, supabaseAdmin)
      initiateResponse = await startResumableSession(accessToken)
    }

    if (!initiateResponse.ok) {
      const errText = await initiateResponse.text()
      throw new Error(`Failed to initiate Google Drive resumable session: ${errText}`)
    }

    const uploadUrl = initiateResponse.headers.get('Location')
    if (!uploadUrl) {
      throw new Error('Google Drive API did not return resumable upload Location header.')
    }

    // Pipe the incoming request stream directly to the Google Drive PUT session
    const webStream = Readable.toWeb(req)

    const uploadHeaders = {
      'Content-Type': fileType
    }
    if (fileSize) {
      uploadHeaders['Content-Length'] = fileSize
    }

    console.log(`Piping upload stream directly to Google Drive for: ${fileName}`)
    const driveUploadResponse = await fetch(uploadUrl, {
      method: 'PUT',
      headers: uploadHeaders,
      body: webStream,
      duplex: 'half' // Required for piping request body stream in Node fetch
    })

    if (!driveUploadResponse.ok) {
      const errText = await driveUploadResponse.text()
      throw new Error(`Google Drive PUT stream failed: ${errText}`)
    }

    const driveFile = await driveUploadResponse.json()

    // Delete old file version from Google Drive if specified
    if (oldFileId) {
      console.log(`Deleting old file version from Google Drive: ${oldFileId}`)
      try {
        await fetch(`https://www.googleapis.com/drive/v3/files/${oldFileId}`, {
          method: 'DELETE',
          headers: {
            'Authorization': `Bearer ${accessToken}`
          }
        })
      } catch (delErr) {
        console.error(`Failed to delete old file version ${oldFileId}:`, delErr)
      }
    }

    return res.status(200).json({
      success: true,
      file_id: driveFile.id,
      file_name: driveFile.name,
      mime_type: driveFile.mimeType
    })

  } catch (err) {
    console.error('Upload Proxy Error:', err)
    return res.status(400).json({ error: err.message || 'An unexpected upload error occurred.' })
  }
})

// Helper function to refresh Google Access Token
async function refreshGoogleToken(userId, refreshToken, supabaseAdmin) {
  const clientId = process.env.GOOGLE_CLIENT_ID
  const clientSecret = process.env.GOOGLE_CLIENT_SECRET

  if (!clientId || !clientSecret) {
    throw new Error('Google OAuth client credentials are not configured on the proxy server.')
  }

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      refresh_token: refreshToken,
      grant_type: 'refresh_token',
    }),
  })

  if (!res.ok) {
    const errText = await res.text()
    console.error('Failed to refresh Google token:', errText)
    throw new Error('Failed to refresh Google access token. Please reconnect Google Drive.')
  }

  const data = await res.json()
  const newAccessToken = data.access_token

  if (!newAccessToken) {
    throw new Error('No access token returned in refresh response.')
  }

  // Update DB
  const { error: updateError } = await supabaseAdmin
    .from('user_profiles')
    .update({ google_access_token: newAccessToken })
    .eq('id', userId)

  if (updateError) {
    console.error('Failed to update refreshed access token in database:', updateError)
  }

  return newAccessToken
}

app.listen(PORT, () => {
  console.log(`Neo Transfer Download Proxy listening on port ${PORT}`)
})
