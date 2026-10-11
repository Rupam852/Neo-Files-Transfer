import { createContext, useContext, useEffect, useState, useRef } from 'react'
import { supabase } from '../services/supabase'

const AuthContext = createContext(null)

// 1 Hour Inactivity Timeout (in milliseconds)
const INACTIVITY_TIMEOUT_MS = 60 * 60 * 1000

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null)
  const [profile, setProfile] = useState(null)
  const [isAdmin, setIsAdmin] = useState(false)
  const [adminRecord, setAdminRecord] = useState(null)
  const [isPaused, setIsPaused] = useState(false)
  const [isUnderMaintenance, setIsUnderMaintenance] = useState(false)
  const [downloadsEnabled, setDownloadsEnabled] = useState(true)
  const [sharingEnabled, setSharingEnabled] = useState(true)
  const [loading, setLoading] = useState(true)
  const loadingProfileRef = useRef(false)

  // 1-Hour Inactivity System: Check and update activity
  const recordActivity = () => {
    localStorage.setItem('neo_last_active_time', Date.now().toString())
  }

  const isSessionTimedOut = () => {
    const lastActiveStr = localStorage.getItem('neo_last_active_time')
    if (!lastActiveStr) return false
    const lastActive = parseInt(lastActiveStr, 10)
    if (isNaN(lastActive)) return false
    return (Date.now() - lastActive) > INACTIVITY_TIMEOUT_MS
  }

  useEffect(() => {
    // Check active session on initial load
    supabase.auth.getSession().then(async ({ data: { session } }) => {
      if (session?.user) {
        // If 1 hour of inactivity has already elapsed while tab/browser was closed
        if (isSessionTimedOut()) {
          console.log('Web session expired due to 1 hour of inactivity.')
          localStorage.removeItem('neo_last_active_time')
          await supabase.auth.signOut({ scope: 'local' })
          setUser(null)
          setLoading(false)
          return
        }

        // Active session: record current activity timestamp
        recordActivity()
        setUser(session.user)

        const sessionTokens = {}
        if (session.provider_token) {
          sessionTokens.google_access_token = session.provider_token
          localStorage.setItem('google_provider_token', session.provider_token)
        }
        if (session.provider_refresh_token) {
          sessionTokens.google_refresh_token = session.provider_refresh_token
          localStorage.setItem('google_refresh_token', session.provider_refresh_token)
        }
        loadProfile(session.user, sessionTokens)
      } else {
        localStorage.removeItem('neo_last_active_time')
        setLoading(false)
      }
    })

    // Listen for auth state changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      (event, session) => {
        if (session?.user) {
          recordActivity()
          setUser(session.user)
          const sessionTokens = {}
          if (session.provider_token) {
            sessionTokens.google_access_token = session.provider_token
            localStorage.setItem('google_provider_token', session.provider_token)
          }
          if (session.provider_refresh_token) {
            sessionTokens.google_refresh_token = session.provider_refresh_token
            localStorage.setItem('google_refresh_token', session.provider_refresh_token)
          }
          const isFresh = event === 'SIGNED_IN'
          loadProfile(session.user, sessionTokens, isFresh)
        } else {
          try {
            localStorage.removeItem('google_provider_token')
            localStorage.removeItem('google_refresh_token')
            localStorage.removeItem('neo_last_active_time')
          } catch (e) {}
          setUser(null)
          setProfile(null)
          setIsAdmin(false)
          setAdminRecord(null)
          setIsUnderMaintenance(false)
          setLoading(false)
        }
      }
    )

    return () => subscription.unsubscribe()
  }, [])

  // Web Inactivity Tracker: Listen for user actions & keep session alive while user is active
  useEffect(() => {
    if (!user) return

    let lastThrottle = 0
    const handleUserActivity = () => {
      const now = Date.now()
      if (now - lastThrottle > 15000) { // Throttle every 15s max
        lastThrottle = now
        recordActivity()
      }
    }

    const events = ['mousedown', 'keydown', 'scroll', 'touchstart', 'click', 'mousemove']
    events.forEach(e => window.addEventListener(e, handleUserActivity, { passive: true }))

    // Periodic check every 30s to verify if 1 hour of inactivity has elapsed
    const checkInterval = setInterval(async () => {
      if (isSessionTimedOut()) {
        console.log('User inactive for >1 hour. Logging out automatically.')
        clearInterval(checkInterval)
        await signOut()
      }
    }, 30000)

    return () => {
      events.forEach(e => window.removeEventListener(e, handleUserActivity))
      clearInterval(checkInterval)
    }
  }, [user])

  // Realtime listeners for Admins and Approved Users
  useEffect(() => {
    if (!user) return

    // Subscribe to realtime updates for the current user's entry in the admins table
    const adminChannel = supabase
      .channel(`admin-status-${user.id}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'admins',
          filter: `user_id=eq.${user.id}`,
        },
        async (payload) => {
          console.log('Realtime admin status change:', payload)
          await loadProfile(user)
        }
      )
      .subscribe()

    // Subscribe to realtime updates for the current user's entry in the approved_users table
    const approvedChannel = supabase
      .channel(`approved-status-${user.id}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'approved_users',
        },
        async (payload) => {
          console.log('Realtime approved user update:', payload)
          const targetEmail = user.email.toLowerCase()
          if (payload.eventType === 'DELETE') {
            const oldEmail = payload.old?.email?.toLowerCase()
            if (oldEmail === targetEmail) {
              await signOut()
            }
          } else if (payload.new) {
            const newEmail = payload.new.email?.toLowerCase()
            if (newEmail === targetEmail) {
              setIsPaused(payload.new.is_paused || false)
            }
          }
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(adminChannel)
      supabase.removeChannel(approvedChannel)
    }
  }, [user])

  // Fetch system settings on initial app mount
  const fetchSystemSettings = async () => {
    try {
      const { data } = await supabase.from('system_settings').select('key, value')
      if (data) {
        const maintenance = data.find(s => s.key === 'maintenance_mode')?.value || false
        setIsUnderMaintenance(maintenance)
        const downloads = data.find(s => s.key === 'downloads_enabled')?.value !== false
        setDownloadsEnabled(downloads)
        const sharing = data.find(s => s.key === 'sharing_enabled')?.value !== false
        setSharingEnabled(sharing)
      }
    } catch (e) {
      console.error('Failed to fetch system settings:', e)
    }
  }

  // Realtime listener for system_settings (maintenance mode & downloads & sharing) - active for all visitors & users
  useEffect(() => {
    fetchSystemSettings()

    const settingsChannel = supabase
      .channel('auth-settings-maintenance-global')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'system_settings' },
        async () => {
          await fetchSystemSettings()
        }
      )
      .subscribe()

    return () => supabase.removeChannel(settingsChannel)
  }, [])

  async function loadProfile(authUser, sessionTokens = {}, isFreshSignIn = false) {
    if (loadingProfileRef.current) {
      console.log('Ignore concurrent loadProfile call')
      return
    }
    loadingProfileRef.current = true
    try {
      // Load user profile
      let { data: profileData, error: profileError } = await supabase
        .from('user_profiles')
        .select('*')
        .eq('id', authUser.id)
        .maybeSingle()

      if (!profileData) {
        // Create profile on the fly if missing
        const newProfile = {
          id: authUser.id,
          email: authUser.email,
          name: authUser.user_metadata?.full_name || authUser.user_metadata?.name || '',
          avatar_url: authUser.user_metadata?.avatar_url || '',
        }
        if (sessionTokens.google_access_token) newProfile.google_access_token = sessionTokens.google_access_token
        if (sessionTokens.google_refresh_token) newProfile.google_refresh_token = sessionTokens.google_refresh_token

        const { data: insertedData, error: insertError } = await supabase
          .from('user_profiles')
          .insert(newProfile)
          .select()
          .maybeSingle()

        if (!insertError && insertedData) {
          profileData = insertedData
        } else {
          profileData = { ...newProfile, is_folder_verified: false, drive_folder_id: null }
        }
      } else {
        // If profile exists, sync Google tokens if needed
        const updates = {}
        if (sessionTokens.google_access_token && profileData.google_access_token !== sessionTokens.google_access_token) {
          updates.google_access_token = sessionTokens.google_access_token
        }
        if (sessionTokens.google_refresh_token && profileData.google_refresh_token !== sessionTokens.google_refresh_token) {
          updates.google_refresh_token = sessionTokens.google_refresh_token
        }

        if (Object.keys(updates).length > 0) {
          const { data: updatedData } = await supabase
            .from('user_profiles')
            .update(updates)
            .eq('id', authUser.id)
            .select()
            .maybeSingle()
          if (updatedData) {
            profileData = updatedData
          }
        }
      }

      setProfile(profileData)

      // Check if user is admin
      const { data: adminData } = await supabase
        .from('admins')
        .select('*')
        .eq('user_id', authUser.id)
        .maybeSingle()

      const isUserAdmin = !!adminData
      setIsAdmin(isUserAdmin)
      setAdminRecord(adminData)

      // Fetch maintenance mode setting
      try {
        const { data: settingsData } = await supabase.from('system_settings').select('key, value')
        const maintenance = settingsData?.find(s => s.key === 'maintenance_mode')?.value || false
        setIsUnderMaintenance(maintenance)
        const downloads = settingsData?.find(s => s.key === 'downloads_enabled')?.value !== false
        setDownloadsEnabled(downloads)
        const sharing = settingsData?.find(s => s.key === 'sharing_enabled')?.value !== false
        setSharingEnabled(sharing)
      } catch (e) {
        console.error('Failed to fetch settings:', e)
      }

      // If the user is not an admin, check if their email is in the approved_users list
      if (!isUserAdmin) {
        const { data: approvedData } = await supabase
          .from('approved_users')
          .select('id, is_paused')
          .eq('email', authUser.email.toLowerCase())
          .maybeSingle()

        if (!approvedData) {
          // If not approved and not admin, revoke session
          await supabase.auth.signOut({ scope: 'local' })
          setUser(null)
          setProfile(null)
          setIsAdmin(false)
          setIsPaused(false)
          return
        }
        setIsPaused(approvedData.is_paused || false)
      } else {
        setIsPaused(false)
      }
    } catch (err) {
      console.error('Error loading profile:', err)
    } finally {
      loadingProfileRef.current = false
      setLoading(false)
    }
  }

  async function signInWithGoogle(forceConsent = false) {
    recordActivity()
    const queryParams = { access_type: 'offline' }
    if (forceConsent) {
      queryParams.prompt = 'consent select_account'
    }
    const { error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: `${window.location.origin}/auth/callback`,
        scopes: 'https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/drive.file',
        queryParams
      }
    })
    if (error) throw error
  }

  async function signOut() {
    try {
      localStorage.removeItem('neo_last_active_time')
      localStorage.removeItem('google_provider_token')
      localStorage.removeItem('google_refresh_token')
    } catch (e) {}

    await supabase.auth.signOut({ scope: 'local' })
    setUser(null)
    setProfile(null)
    setIsAdmin(false)
    setAdminRecord(null)
    setIsPaused(false)
    setIsUnderMaintenance(false)
    setDownloadsEnabled(true)
    setSharingEnabled(true)
  }

  async function refreshProfile() {
    if (user) {
      await loadProfile(user)
    }
  }

  return (
    <AuthContext.Provider value={{
      user,
      profile,
      isAdmin,
      adminRecord,
      isPaused,
      isUnderMaintenance,
      downloadsEnabled,
      sharingEnabled,
      loading,
      signInWithGoogle,
      signOut,
      refreshProfile,
    }}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const context = useContext(AuthContext)
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider')
  }
  return context
}
