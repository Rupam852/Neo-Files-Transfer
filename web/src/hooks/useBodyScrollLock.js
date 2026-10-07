import { useEffect } from 'react'

let lockCount = 0

/**
 * Custom hook to lock body scrolling when a modal / popup is open
 * Prevents background scroll chaining / leaking on desktop & mobile devices.
 */
export function useBodyScrollLock(isLocked = true) {
  useEffect(() => {
    if (!isLocked) return

    lockCount++
    if (lockCount === 1) {
      document.body.style.overflow = 'hidden'
      document.documentElement.style.overflow = 'hidden'
      document.body.classList.add('modal-open')
    }

    return () => {
      lockCount = Math.max(0, lockCount - 1)
      if (lockCount === 0) {
        document.body.style.overflow = ''
        document.documentElement.style.overflow = ''
        document.body.classList.remove('modal-open')
      }
    }
  }, [isLocked])
}
