import React from 'react'
import { Outlet, useLocation, Link } from 'react-router-dom'
import { 
  WifiIcon, 
  CalendarDaysIcon, 
  ClipboardDocumentListIcon, 
  CogIcon,
  HeartIcon 
} from '@heroicons/react/24/outline'

const Layout: React.FC = () => {
  const location = useLocation()

  const isActive = (path: string) => {
    return location.pathname === path || location.pathname.startsWith(path + '/')
  }

  return (
    <div className="flex flex-col min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow-sm border-b border-gray-100">
        <div className="px-6 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-3">
              <div className="w-10 h-10 bg-light-blue-500 rounded-2xl flex items-center justify-center">
                <HeartIcon className="w-6 h-6 text-white" />
              </div>
              <div>
                <h1 className="text-xl font-bold text-gray-900">Eye Care Tracker</h1>
                <p className="text-sm text-gray-500">Smart medication management</p>
              </div>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="flex-1 px-6 py-6">
        <div className="max-w-4xl mx-auto">
          <Outlet />
        </div>
      </main>

      {/* Bottom Navigation */}
      <nav className="bg-white border-t border-gray-200 px-6 py-2 safe-area-pb">
        <div className="flex justify-around items-center max-w-md mx-auto">
          <Link
            to="/device"
            className={`flex flex-col items-center space-y-1 py-3 px-4 rounded-2xl transition-all duration-200 touch-target ${
              isActive('/device')
                ? 'bg-light-blue-100 text-light-blue-600'
                : 'text-gray-500 hover:text-gray-700 hover:bg-gray-100'
            }`}
          >
            <WifiIcon className="w-6 h-6" />
            <span className="text-xs font-medium">Device</span>
          </Link>

          <Link
            to="/calendar"
            className={`flex flex-col items-center space-y-1 py-3 px-4 rounded-2xl transition-all duration-200 touch-target ${
              isActive('/calendar')
                ? 'bg-light-blue-100 text-light-blue-600'
                : 'text-gray-500 hover:text-gray-700 hover:bg-gray-100'
            }`}
          >
            <CalendarDaysIcon className="w-6 h-6" />
            <span className="text-xs font-medium">Schedule</span>
          </Link>

          <Link
            to="/logging"
            className={`flex flex-col items-center space-y-1 py-3 px-4 rounded-2xl transition-all duration-200 touch-target ${
              isActive('/logging')
                ? 'bg-light-blue-100 text-light-blue-600'
                : 'text-gray-500 hover:text-gray-700 hover:bg-gray-100'
            }`}
          >
            <ClipboardDocumentListIcon className="w-6 h-6" />
            <span className="text-xs font-medium">History</span>
          </Link>

          <Link
            to="/settings"
            className={`flex flex-col items-center space-y-1 py-3 px-4 rounded-2xl transition-all duration-200 touch-target ${
              isActive('/settings')
                ? 'bg-light-blue-100 text-light-blue-600'
                : 'text-gray-500 hover:text-gray-700 hover:bg-gray-100'
            }`}
          >
            <CogIcon className="w-6 h-6" />
            <span className="text-xs font-medium">Settings</span>
          </Link>
        </div>
      </nav>
    </div>
  )
}

export default Layout