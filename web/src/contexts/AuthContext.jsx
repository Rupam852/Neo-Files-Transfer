import { createContext, useContext, useEffect, useState } from 'react'
import { supabase } from '../services/supabase'

const AuthContext = createContext(null)

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null)
  const [profile, setProfile] = useState(null)
  const [isAdmin, setIsAdmin] = useState(false)
  const [adminRecord, setAdminRecord] = useState(null)
  const [loading, setLoading] = useState(true)

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
      (_event, session) => {
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
          try {
            localStorage.removeItem('google_provider_token')
            localStorage.removeItem('google_refresh_token')
          } catch (e) {}
          setProfile(null)
          setIsAdmin(false)
          setAdminRecord(null)
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

    return () => {
      supabase.removeChannel(adminChannel)
    }
  }, [user])


  async function loadProfile(authUser, sessionTokens = {}) {
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

      // If the user is not an admin, check if their email is in the approved_users list
      if (!isUserAdmin) {
        const { data: approvedData } = await supabase
          .from('approved_users')
          .select('id')
          .eq('email', authUser.email.toLowerCase())
          .maybeSingle()

        if (!approvedData) {
          // If not approved and not admin, revoke local session immediately
          await supabase.auth.signOut()
          setUser(null)
          setProfile(null)
          setIsAdmin(false)
          return
        }
      }
    } catch (err) {
      console.error('Error loading profile:', err)
    } finally {
      setLoading(false)
    }
  }

  async function signInWithGoogle() {
    const { error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: `${window.location.origin}/auth/callback`,
        scopes: 'https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/drive',
        queryParams: {
          access_type: 'offline',
          prompt: 'consent'
        }
      }
    })
    if (error) throw error
  }

  async function signOut() {
    await supabase.auth.signOut()
    setUser(null)
    setProfile(null)
    setIsAdmin(false)
    setAdminRecord(null)
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
