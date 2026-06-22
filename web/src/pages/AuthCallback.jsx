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
        navigate('/login')
        return
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
        await supabase.auth.signOut()
        toast.error('Your account has not been approved yet. Please contact an admin.')
        navigate('/login')
        return
      }

      // Create/update user profile if it doesn't exist
      const { data: existingProfile } = await supabase
        .from('user_profiles')
        .select('id')
        .eq('id', session.user.id)
        .maybeSingle()

      if (!existingProfile) {
        await supabase.from('user_profiles').insert({
          id: session.user.id,
          email: userEmail,
          name: session.user.user_metadata?.full_name || session.user.user_metadata?.name || '',
          avatar_url: session.user.user_metadata?.avatar_url || '',
        })
      }

      // Log activity
      await supabase.from('activity_logs').insert({
        user_id: session.user.id,
        action: 'login',
        details: 'User logged in via Google OAuth',
      })

      // Redirect based on role
      if (admin) {
        navigate('/admin/dashboard')
      } else {
        navigate('/dashboard')
      }
    }

    handleCallback()
  }, [navigate])

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="flex flex-col items-center gap-4">
        <div className="w-10 h-10 border-4 border-primary-600 border-t-transparent rounded-full animate-spin" />
        <p className="text-gray-500 text-sm">Authenticating...</p>
      </div>
    </div>
  )
}
