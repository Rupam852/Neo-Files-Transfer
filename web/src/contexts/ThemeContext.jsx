import { createContext, useContext, useState, useEffect } from 'react'

const ThemeContext = createContext()

export function ThemeProvider({ children }) {
  const [theme, setTheme] = useState(() => {
    try {
      const savedTheme = localStorage.getItem('neo_theme')
      if (savedTheme === 'light' || savedTheme === 'dark') {
        return savedTheme
      }
      return 'dark'
    } catch {
      return 'dark'
    }
  })

  useEffect(() => {
    try {
      const root = document.documentElement
      if (theme === 'light') {
        root.classList.remove('dark')
        root.classList.add('light')
        root.setAttribute('data-theme', 'light')
      } else {
        root.classList.remove('light')
        root.classList.add('dark')
        root.setAttribute('data-theme', 'dark')
      }
      localStorage.setItem('neo_theme', theme)
    } catch (e) {
      console.error('Failed to sync theme:', e)
    }
  }, [theme])

  const toggleTheme = () => {
    setTheme(prev => (prev === 'dark' ? 'light' : 'dark'))
  }

  const setExplicitTheme = (mode) => {
    if (mode === 'light' || mode === 'dark') {
      setTheme(mode)
    }
  }

  return (
    <ThemeContext.Provider value={{ theme, isDark: theme === 'dark', toggleTheme, setTheme: setExplicitTheme }}>
      {children}
    </ThemeContext.Provider>
  )
}

export function useTheme() {
  const context = useContext(ThemeContext)
  if (!context) {
    throw new Error('useTheme must be used within a ThemeProvider')
  }
  return context
}
