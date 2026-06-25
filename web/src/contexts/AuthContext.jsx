import { createContext, useContext, useEffect, useState, useRef } from 'react'
import { supabase } from '../services/supabase'

const AuthContext = createContext(null)

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null)
  const [profile, setProfile] = useState(null)
  const [isAdmin, setIsAdmin] = useState(false)
  const [adminRecord, setAdminRecord] = useState(null)
  const [isPaused, setIsPaused] = useState(false)
  const [isSessionInvalidated, setIsSessionInvalidated] = useState(false)
  const [isUnderMaintenance, setIsUnderMaintenance] = useState(false)
  const [downloadsEnabled, setDownloadsEnabled] = useState(true)
  const [sharingEnabled, setSharingEnabled] = useState(true)
  const [loading, setLoading] = useState(true)
  const loadingProfileRef = useRef(false)

  const generateSessionId = () => {
    if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
      return crypto.randomUUID()
    }
    return Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15)
  }

  useEffect(() => {
    // Check active session
    supabase.auth.getSession().then(({ data: { session } }) => {
      setUser(session?.user ?? null)
      if (session?.user) {
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
        setLoading(false)
      }
    })

    // Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      (event, session) => {
        setUser(session?.user ?? null)
        if (session?.user) {
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
          } catch (e) {}
          setProfile(null)
          setIsAdmin(false)
          setAdminRecord(null)
          setIsSessionInvalidated(false)
          setIsUnderMaintenance(false)
          setLoading(false)
        }
      }
    )

    return () => subscription.unsubscribe()
  }, [])

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

    // Subscribe to realtime updates for the current user's entry in the user_profiles table
    const profileChannel = supabase
      .channel(`profile-status-${user.id}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'user_profiles',
          filter: `id=eq.${user.id}`,
        },
        async (payload) => {
          console.log('Realtime profile status change:', payload)
          if (payload.new) {
            const newWebSession = payload.new.active_web_session_id
            const localSession = localStorage.getItem('active_web_session_id')
            if (newWebSession && localSession && newWebSession !== localSession) {
              setIsSessionInvalidated(true)
            }
          }
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(adminChannel)
      supabase.removeChannel(approvedChannel)
      supabase.removeChannel(profileChannel)
    }
  }, [user])

  // Realtime listener for system_settings (maintenance mode & downloads & sharing)
  useEffect(() => {
    if (!user) return

    const settingsChannel = supabase
      .channel('auth-settings-maintenance')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'system_settings' },
        async () => {
          try {
            const { data } = await supabase.from('system_settings').select('key, value')
            const maintenance = data?.find(s => s.key === 'maintenance_mode')?.value || false
            setIsUnderMaintenance(maintenance)
            const downloads = data?.find(s => s.key === 'downloads_enabled')?.value !== false
            setDownloadsEnabled(downloads)
            const sharing = data?.find(s => s.key === 'sharing_enabled')?.value !== false
            setSharingEnabled(sharing)
          } catch (e) {
            console.error('Failed to refresh settings:', e)
          }
        }
      )
      .subscribe()

    return () => supabase.removeChannel(settingsChannel)
  }, [user])


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
        // Create profile on the fly if missing (e.g. if the user was previously blocked but now logged in)
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
          // Fallback to local profile info if insert fails
          profileData = { ...newProfile, is_folder_verified: false, drive_folder_id: null }
        }
      } else {
        // If profile exists, check if we need to sync Google tokens to DB
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

      // Establish & Validate active Web Session
      let localSessionId = localStorage.getItem('active_web_session_id')
      if (!localSessionId) {
        localSessionId = generateSessionId()
        localStorage.setItem('active_web_session_id', localSessionId)
      }

      const claimActiveSession =
        localStorage.getItem('claim_active_session') === 'true' ||
        isFreshSignIn ||
        window.location.pathname === '/auth/callback'
      if (claimActiveSession || !profileData.active_web_session_id) {
        // Claim active session
        await supabase
          .from('user_profiles')
          .update({ active_web_session_id: localSessionId })
          .eq('id', authUser.id)
        
        localStorage.removeItem('claim_active_session')
        profileData.active_web_session_id = localSessionId
        setIsSessionInvalidated(false)
      } else if (profileData.active_web_session_id !== localSessionId) {
        // Logged out because another session is active
        setIsSessionInvalidated(true)
        setLoading(false)
        return
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
          // If not approved and not admin, revoke local session immediately
          await supabase.auth.signOut()
          setUser(null)
          setProfile(null)
          setIsAdmin(false)
          setIsPaused(false)
          setIsSessionInvalidated(false)
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
    localStorage.setItem('claim_active_session', 'true')
    const { error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: `${window.location.origin}/auth/callback`,
        scopes: 'https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/drive',
        queryParams: {
          access_type: 'offline',
          prompt: forceConsent ? 'consent' : 'select_account'
        }
      }
    })
    if (error) throw error
  }

  async function signOut() {
    try {
      if (user) {
        const localSessionId = localStorage.getItem('active_web_session_id')
        if (localSessionId) {
          // Only clear if the DB session matches our local session
          const { data: profileData } = await supabase
            .from('user_profiles')
            .select('active_web_session_id')
            .eq('id', user.id)
            .maybeSingle()

          if (profileData && profileData.active_web_session_id === localSessionId) {
            await supabase
              .from('user_profiles')
              .update({ active_web_session_id: null })
              .eq('id', user.id)
          }
        }
      }
    } catch (e) {
      console.error('Failed to clear active session in DB:', e)
    }

    await supabase.auth.signOut()
    setUser(null)
    setProfile(null)
    setIsAdmin(false)
    setAdminRecord(null)
    setIsPaused(false)
    setIsSessionInvalidated(false)
    setIsUnderMaintenance(false)
    setDownloadsEnabled(true)
    setSharingEnabled(true)
    try {
      localStorage.removeItem('active_web_session_id')
    } catch (e) {}
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
      isSessionInvalidated,
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
