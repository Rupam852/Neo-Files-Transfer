import React, { useState } from 'react'
import { LogOut, Loader2 } from 'lucide-react'

export default function LogoutConfirmModal({ isOpen, onClose, onConfirm }) {
  const [isLoggingOut, setIsLoggingOut] = useState(false)

  if (!isOpen) return null

  const handleConfirm = async () => {
    setIsLoggingOut(true)
    try {
      // Small grace period for buttery-smooth transition feel
      await new Promise((resolve) => setTimeout(resolve, 400))
      await onConfirm()
    } catch (err) {
      console.error('Logout error:', err)
      setIsLoggingOut(false)
    }
  }

  return (
    <div className="fixed inset-0 bg-black/70 backdrop-blur-md z-50 flex items-center justify-center p-4 transition-all duration-300 animate-in fade-in">
      <div
        className="bg-dark-600/95 border border-dark-400/80 rounded-2xl max-w-sm w-full p-6 space-y-6 shadow-2xl relative overflow-hidden transition-all duration-300 scale-100 animate-in zoom-in-95"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Ambient Top Glow */}
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-48 h-1 bg-gradient-to-r from-transparent via-red-500/50 to-transparent blur-sm pointer-events-none" />

        {isLoggingOut ? (
          /* Smooth Logging Out State */
          <div className="py-4 text-center space-y-5 animate-in fade-in zoom-in-95 duration-200">
            <div className="relative w-16 h-16 mx-auto flex items-center justify-center">
              <div className="absolute inset-0 rounded-full border-4 border-red-500/20 animate-pulse" />
              <div className="absolute inset-0 rounded-full border-4 border-transparent border-t-red-500 border-r-red-400 animate-spin" />
              <LogOut size={22} className="text-red-400 animate-pulse" />
            </div>

            <div className="space-y-1.5">
              <h3 className="text-lg font-bold text-white font-['Space_Grotesk'] tracking-wide">
                Logging out...
              </h3>
              <p className="text-xs text-gray-400 max-w-[240px] mx-auto leading-relaxed">
                Securing your session and safely signing out...
              </p>
            </div>

            <div className="w-full bg-dark-500/60 rounded-full h-1 overflow-hidden">
              <div className="h-full bg-gradient-to-r from-red-600 to-amber-500 w-full animate-pulse" />
            </div>
          </div>
        ) : (
          /* Confirmation Prompt State */
          <>
            <div className="space-y-2 text-center">
              <div className="w-14 h-14 bg-red-500/10 border border-red-500/20 rounded-2xl flex items-center justify-center mx-auto text-red-400 shadow-lg shadow-red-500/5 transition-transform duration-300 hover:scale-105">
                <LogOut size={26} />
              </div>
              <h3 className="text-lg font-bold text-gray-100 font-['Space_Grotesk'] pt-1">
                Sign Out
              </h3>
              <p className="text-sm text-gray-400 leading-relaxed">
                Are you sure you want to log out of your session?
              </p>
            </div>

            <div className="flex gap-3 pt-1">
              <button
                type="button"
                onClick={onClose}
                className="flex-1 py-2.5 bg-dark-500 hover:bg-dark-400 active:scale-[0.98] border border-dark-300 text-gray-300 rounded-xl text-sm font-semibold transition-all duration-150"
              >
                No, cancel
              </button>
              <button
                type="button"
                onClick={handleConfirm}
                className="flex-1 py-2.5 bg-red-600 hover:bg-red-500 active:scale-[0.98] text-white rounded-xl text-sm font-semibold transition-all duration-150 shadow-lg shadow-red-600/25 flex items-center justify-center gap-1.5"
              >
                Yes, sign out
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  )
}
