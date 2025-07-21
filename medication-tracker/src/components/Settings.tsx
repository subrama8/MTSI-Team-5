import React, { useState, useEffect } from 'react'
import { 
  CogIcon, 
  BellIcon, 
  DevicePhoneMobileIcon,
  TrashIcon,
  ExclamationTriangleIcon,
  CheckCircleIcon 
} from '@heroicons/react/24/outline'

const Settings: React.FC = () => {
  const [notificationsEnabled, setNotificationsEnabled] = useState(false)
  const [notificationPermission, setNotificationPermission] = useState<NotificationPermission>('default')
  const [reminderSound, setReminderSound] = useState(true)
  const [darkMode, setDarkMode] = useState(false)
  const [showClearDataDialog, setShowClearDataDialog] = useState(false)

  useEffect(() => {
    // Check notification permission status
    if ('Notification' in window) {
      setNotificationPermission(Notification.permission)
      setNotificationsEnabled(Notification.permission === 'granted')
    }

    // Load settings from localStorage
    const savedSettings = localStorage.getItem('app_settings')
    if (savedSettings) {
      const settings = JSON.parse(savedSettings)
      setReminderSound(settings.reminderSound ?? true)
      setDarkMode(settings.darkMode ?? false)
    }
  }, [])

  const saveSettings = (newSettings: any) => {
    const settings = {
      reminderSound,
      darkMode,
      ...newSettings
    }
    localStorage.setItem('app_settings', JSON.stringify(settings))
  }

  const handleNotificationToggle = async () => {
    if (!('Notification' in window)) {
      alert('This browser does not support notifications')
      return
    }

    if (notificationPermission === 'granted') {
      setNotificationsEnabled(!notificationsEnabled)
      saveSettings({ notificationsEnabled: !notificationsEnabled })
    } else if (notificationPermission === 'default') {
      const permission = await Notification.requestPermission()
      setNotificationPermission(permission)
      
      if (permission === 'granted') {
        setNotificationsEnabled(true)
        saveSettings({ notificationsEnabled: true })
      }
    } else {
      alert('Notifications are blocked. Please enable them in your browser settings.')
    }
  }

  const handleSoundToggle = () => {
    const newValue = !reminderSound
    setReminderSound(newValue)
    saveSettings({ reminderSound: newValue })
  }

  const handleDarkModeToggle = () => {
    const newValue = !darkMode
    setDarkMode(newValue)
    saveSettings({ darkMode: newValue })
    
    // Note: Full dark mode implementation would require theme provider
    if (newValue) {
      document.documentElement.classList.add('dark')
    } else {
      document.documentElement.classList.remove('dark')
    }
  }

  const clearAllData = () => {
    const keys = ['medication_schedules', 'scheduled_doses', 'medication_logs', 'arduino_ip', 'app_settings']
    keys.forEach(key => localStorage.removeItem(key))
    
    setShowClearDataDialog(false)
    
    // Refresh the page to reset state
    window.location.reload()
  }

  const exportData = () => {
    const data = {
      schedules: localStorage.getItem('medication_schedules'),
      doses: localStorage.getItem('scheduled_doses'),
      logs: localStorage.getItem('medication_logs'),
      settings: localStorage.getItem('app_settings'),
      exportDate: new Date().toISOString()
    }

    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    
    const a = document.createElement('a')
    a.href = url
    a.download = `medication-tracker-backup-${new Date().toISOString().split('T')[0]}.json`
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    
    URL.revokeObjectURL(url)
  }

  const getStorageSize = () => {
    let totalSize = 0
    const keys = ['medication_schedules', 'scheduled_doses', 'medication_logs', 'app_settings']
    
    keys.forEach(key => {
      const item = localStorage.getItem(key)
      if (item) {
        totalSize += item.length
      }
    })
    
    return (totalSize / 1024).toFixed(2) // KB
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="text-center">
        <h2 className="text-3xl font-bold text-gray-900 mb-2">Settings</h2>
        <p className="text-gray-600">Customize your medication tracking experience</p>
      </div>

      {/* Notifications */}
      <div className="card">
        <div className="flex items-center space-x-3 mb-4">
          <BellIcon className="w-6 h-6 text-light-blue-500" />
          <h3 className="text-lg font-semibold text-gray-900">Notifications</h3>
        </div>

        <div className="space-y-4">
          {/* Push Notifications */}
          <div className="flex items-center justify-between py-3">
            <div className="flex-1">
              <h4 className="font-medium text-gray-900">Push Notifications</h4>
              <p className="text-sm text-gray-600">
                Get reminders for upcoming medication doses
              </p>
              {notificationPermission === 'denied' && (
                <div className="flex items-center space-x-2 mt-2">
                  <ExclamationTriangleIcon className="w-4 h-4 text-red-500" />
                  <span className="text-xs text-red-600">
                    Notifications blocked. Enable in browser settings.
                  </span>
                </div>
              )}
              {notificationPermission === 'granted' && notificationsEnabled && (
                <div className="flex items-center space-x-2 mt-2">
                  <CheckCircleIcon className="w-4 h-4 text-green-500" />
                  <span className="text-xs text-green-600">
                    Notifications enabled
                  </span>
                </div>
              )}
            </div>
            <button
              onClick={handleNotificationToggle}
              className={`toggle-button ${notificationPermission === 'denied' ? 'opacity-50' : ''}`}
              data-enabled={notificationsEnabled && notificationPermission === 'granted'}
              disabled={notificationPermission === 'denied'}
            >
              <span className="toggle-slider"></span>
            </button>
          </div>

          {/* Sound Notifications */}
          <div className="flex items-center justify-between py-3">
            <div className="flex-1">
              <h4 className="font-medium text-gray-900">Reminder Sound</h4>
              <p className="text-sm text-gray-600">
                Play sound with notifications
              </p>
            </div>
            <button
              onClick={handleSoundToggle}
              className="toggle-button"
              data-enabled={reminderSound}
            >
              <span className="toggle-slider"></span>
            </button>
          </div>
        </div>
      </div>

      {/* Device Settings */}
      <div className="card">
        <div className="flex items-center space-x-3 mb-4">
          <DevicePhoneMobileIcon className="w-6 h-6 text-light-blue-500" />
          <h3 className="text-lg font-semibold text-gray-900">Device & Data</h3>
        </div>

        <div className="space-y-4">
          {/* Dark Mode */}
          <div className="flex items-center justify-between py-3">
            <div className="flex-1">
              <h4 className="font-medium text-gray-900">Dark Mode</h4>
              <p className="text-sm text-gray-600">
                Use dark theme (coming soon)
              </p>
            </div>
            <button
              onClick={handleDarkModeToggle}
              className="toggle-button opacity-50"
              data-enabled={false}
              disabled
            >
              <span className="toggle-slider"></span>
            </button>
          </div>

          {/* Storage Info */}
          <div className="py-3 border-t border-gray-100">
            <h4 className="font-medium text-gray-900 mb-2">Storage</h4>
            <div className="text-sm text-gray-600 space-y-1">
              <p>Data usage: {getStorageSize()} KB</p>
              <p>Stored locally on your device</p>
            </div>
          </div>
        </div>
      </div>

      {/* Data Management */}
      <div className="card">
        <div className="flex items-center space-x-3 mb-4">
          <CogIcon className="w-6 h-6 text-light-blue-500" />
          <h3 className="text-lg font-semibold text-gray-900">Data Management</h3>
        </div>

        <div className="space-y-3">
          {/* Export Data */}
          <button
            onClick={exportData}
            className="w-full btn-secondary flex items-center justify-center space-x-2"
          >
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 10v6m0 0l-3-3m3 3l3-3M3 17V7a2 2 0 012-2h6l2 2h6a2 2 0 012 2v10a2 2 0 01-2 2H5a2 2 0 01-2-2z" />
            </svg>
            <span>Export Data</span>
          </button>

          {/* Clear All Data */}
          <button
            onClick={() => setShowClearDataDialog(true)}
            className="w-full bg-red-500 hover:bg-red-600 text-white py-3 px-4 rounded-2xl font-semibold transition-colors flex items-center justify-center space-x-2"
          >
            <TrashIcon className="w-4 h-4" />
            <span>Clear All Data</span>
          </button>
        </div>
      </div>

      {/* App Info */}
      <div className="card">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">About</h3>
        <div className="text-sm text-gray-600 space-y-2">
          <p><strong>Eye Medication Tracker</strong></p>
          <p>Version 1.0.0</p>
          <p>Built for managing eye medication schedules with device integration</p>
          <p className="text-xs text-gray-500 mt-4">
            Data is stored locally on your device and never transmitted to external servers.
          </p>
        </div>
      </div>

      {/* Clear Data Confirmation Dialog */}
      {showClearDataDialog && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-3xl shadow-2xl max-w-sm w-full p-6">
            <div className="text-center">
              <ExclamationTriangleIcon className="w-12 h-12 text-red-500 mx-auto mb-4" />
              <h3 className="text-lg font-semibold text-gray-900 mb-2">Clear All Data?</h3>
              <p className="text-sm text-gray-600 mb-6">
                This will permanently delete all your medication schedules, logs, and settings. 
                This action cannot be undone.
              </p>
              
              <div className="flex space-x-3">
                <button
                  onClick={() => setShowClearDataDialog(false)}
                  className="flex-1 btn-secondary"
                >
                  Cancel
                </button>
                <button
                  onClick={clearAllData}
                  className="flex-1 bg-red-500 hover:bg-red-600 text-white py-3 px-4 rounded-2xl font-semibold transition-colors"
                >
                  Clear Data
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export default Settings