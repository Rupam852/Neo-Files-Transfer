import { Outlet } from 'react-router-dom'

export default function MainLayout() {
  return (
    <div className="min-h-screen bg-dark-800">
      <Outlet />
    </div>
  )
}
