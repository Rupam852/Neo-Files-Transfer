import { useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../services/supabase'
import toast from 'react-hot-toast'

export default function AuthCallback() {
  const navigate = useNavigate()

  useEffect(() => {
    async function handleCallback() {
      const { data: { session } } = await supabase.auth.getSession()

      if (!session?.user) {
        navigate('/login', { replace: true })
        return
      }

      sessionStorage.setItem('claim_active_session', 'true')

      // Capture and save Google provider token and refresh token immediately
      if (session.provider_token) {
        localStorage.setItem('google_provider_token', session.provider_token)
      }
      if (session.provider_refresh_token) {
        localStorage.setItem('google_refresh_token', session.provider_refresh_token)
      }

      const userEmail = session.user.email

      // Check if user is approved
      const { data: approved } = await supabase
        .from('approved_users')
        .select('id')
        .eq('email', userEmail.toLowerCase())
        .maybeSingle()

      // Check if user is admin (admins bypass approval)
      const { data: admin } = await supabase
        .from('admins')
        .select('id')
        .eq('email', userEmail.toLowerCase())
        .maybeSingle()

      if (!approved && !admin) {
        let errorMessage = 'Access denied. Please submit a registration request first.'
        try {
          const { data: registration } = await supabase
            .from('pending_registrations')
            .select('status')
            .eq('email', userEmail.toLowerCase())
            .maybeSingle()

          if (registration) {
            if (registration.status === 'rejected') {
              errorMessage = 'Your access request has been rejected by an administrator.'
            } else {
              errorMessage = 'Your access request is pending administrator approval.'
            }
          }
        } catch (e) {
          console.error('Error fetching registration status:', e)
        }

        await supabase.auth.signOut()
        toast.error(errorMessage)
        navigate('/login', { replace: true, state: { error: errorMessage } })
        return
      }

      // Create/update user profile
      const updateData = {
        name: session.user.user_metadata?.full_name || session.user.user_metadata?.name || '',
        avatar_url: session.user.user_metadata?.avatar_url || '',
      }
      if (session.provider_token) {
        updateData.google_access_token = session.provider_token
      }
      if (session.provider_refresh_token) {
        updateData.google_refresh_token = session.provider_refresh_token
      }

      const { data: existingProfile } = await supabase
        .from('user_profiles')
        .select('id')
        .eq('id', session.user.id)
        .maybeSingle()

      if (!existingProfile) {
        await supabase.from('user_profiles').insert({
          id: session.user.id,
          email: userEmail,
          ...updateData
        })
      } else {
        await supabase
          .from('user_profiles')
          .update(updateData)
          .eq('id', session.user.id)
      }

      // Log activity
      await supabase.from('activity_logs').insert({
        user_id: session.user.id,
        action: 'login',
        details: 'User logged in via Google OAuth',
      })

      // Redirect based on role
      if (admin) {
        navigate('/', { replace: true })
      } else {
        navigate('/', { replace: true })
      }
    }

    handleCallback()
  }, [navigate])

  return (
    <div className="min-h-screen flex items-center justify-center bg-dark-800">
      <div className="flex flex-col items-center gap-4">
        <div className="w-10 h-10 border-4 border-primary-600 border-t-transparent rounded-full animate-spin" />
        <p className="text-gray-400 text-sm">Authenticating...</p>
      </div>
    </div>
  )
}
