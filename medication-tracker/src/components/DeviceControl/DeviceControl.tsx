import React, { useState, useEffect } from 'react'
import { 
  WifiIcon, 
  ExclamationTriangleIcon, 
  CheckCircleIcon,
  MagnifyingGlassIcon,
  CameraIcon 
} from '@heroicons/react/24/outline'
import { ArduinoWiFiService, DeviceInfo, DeviceStatus } from '../../services/arduino-wifi'
import DeviceDiscovery from './DeviceDiscovery'
import EyeTrackingInterface from './EyeTrackingInterface'

const DeviceControl: React.FC = () => {
  const [arduinoService] = useState(new ArduinoWiFiService())
  const [deviceStatus, setDeviceStatus] = useState<DeviceStatus | null>(null)
  const [isConnected, setIsConnected] = useState(false)
  const [plotterEnabled, setPlotterEnabled] = useState(false)
  const [isLoading, setIsLoading] = useState(false)
  const [showDiscovery, setShowDiscovery] = useState(false)
  const [showEyeTracking, setShowEyeTracking] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    checkDeviceConnection()
  }, [])

  useEffect(() => {
    let interval: NodeJS.Timeout
    if (isConnected) {
      // Poll device status every 3 seconds when connected
      interval = setInterval(checkDeviceConnection, 3000)
    }
    return () => {
      if (interval) clearInterval(interval)
    }
  }, [isConnected])

  const checkDeviceConnection = async () => {
    try {
      const status = await arduinoService.getDeviceStatus()
      if (status) {
        setDeviceStatus(status)
        setIsConnected(true)
        setPlotterEnabled(status.plotterEnabled)
        setError(null)
      } else {
        setIsConnected(false)
        setDeviceStatus(null)
        setPlotterEnabled(false)
      }
    } catch (err) {
      setError('Failed to connect to device')
      setIsConnected(false)
      setDeviceStatus(null)
      setPlotterEnabled(false)
    }
  }

  const handleDeviceSelected = async (device: DeviceInfo) => {
    setIsLoading(true)
    setError(null)
    
    try {
      const connected = await arduinoService.connectToDevice(device.ipAddress)
      if (connected) {
        await checkDeviceConnection()
        setShowDiscovery(false)
      } else {
        setError('Failed to connect to selected device')
      }
    } catch (err) {
      setError('Connection failed')
    } finally {
      setIsLoading(false)
    }
  }

  const togglePlotter = async () => {
    if (!isConnected) {
      setError('Device not connected')
      return
    }

    setIsLoading(true)
    setError(null)

    try {
      let success: boolean
      if (plotterEnabled) {
        success = await arduinoService.stopPlotter()
      } else {
        success = await arduinoService.startPlotter()
      }

      if (success) {
        // Update local state immediately for better UX
        setPlotterEnabled(!plotterEnabled)
        
        // Refresh status to confirm
        setTimeout(checkDeviceConnection, 500)
        
        // Log medication usage when plotter is started
        if (!plotterEnabled) {
          logMedicationUsage()
        }
      } else {
        setError('Failed to toggle plotter')
      }
    } catch (err) {
      setError('Communication error')
    } finally {
      setIsLoading(false)
    }
  }

  const logMedicationUsage = () => {
    // Save medication usage to localStorage
    const usage = {
      timestamp: new Date().toISOString(),
      type: 'automatic',
      notes: 'Eye tracker plotter activated'
    }
    
    const existingLogs = localStorage.getItem('medication_logs')
    const logs = existingLogs ? JSON.parse(existingLogs) : []
    logs.push(usage)
    localStorage.setItem('medication_logs', JSON.stringify(logs))
  }

  const handleDisconnect = () => {
    arduinoService.disconnect()
    setIsConnected(false)
    setDeviceStatus(null)
    setPlotterEnabled(false)
    setError(null)
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="text-center">
        <h2 className="text-3xl font-bold text-gray-900 mb-2">Device Control</h2>
        <p className="text-gray-600">Connect and control your eye tracking device</p>
      </div>

      {/* Connection Status Card */}
      <div className="card">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center space-x-3">
            <WifiIcon className="w-8 h-8 text-light-blue-500" />
            <div>
              <h3 className="text-lg font-semibold text-gray-900">Connection Status</h3>
              <div className="flex items-center mt-1">
                <div className={`status-dot ${isConnected ? 'status-connected' : 'status-disconnected'}`}></div>
                <span className="text-sm text-gray-600">
                  {isConnected ? 'Connected' : 'Disconnected'}
                </span>
              </div>
            </div>
          </div>
          
          {isConnected && (
            <button
              onClick={handleDisconnect}
              className="btn-secondary text-sm py-2 px-4"
            >
              Disconnect
            </button>
          )}
        </div>

        {/* Device Info */}
        {deviceStatus && (
          <div className="bg-light-blue-50 rounded-2xl p-4 mb-6">
            <h4 className="font-medium text-gray-900 mb-2">Device Information</h4>
            <div className="text-sm text-gray-600 space-y-1">
              <p><strong>Name:</strong> {deviceStatus.device}</p>
              <p><strong>IP Address:</strong> {deviceStatus.ipAddress}</p>
              <p><strong>WiFi:</strong> {deviceStatus.wifiConnected ? 'Connected' : 'Disconnected'}</p>
            </div>
          </div>
        )}

        {/* Connection Actions */}
        {!isConnected && (
          <div className="space-y-4">
            <button
              onClick={() => setShowDiscovery(true)}
              disabled={isLoading}
              className="w-full btn-primary flex items-center justify-center space-x-2"
            >
              <MagnifyingGlassIcon className="w-5 h-5" />
              <span>{isLoading ? 'Searching...' : 'Find Device'}</span>
            </button>
          </div>
        )}
      </div>

      {/* Main Control Card */}
      {isConnected && (
        <div className="card">
          <div className="text-center mb-8">
            <h3 className="text-2xl font-bold text-gray-900 mb-2">Eye Tracker Control</h3>
            <p className="text-gray-600">Start or stop the eye tracking plotter</p>
          </div>

          {/* Large Toggle Button */}
          <div className="flex justify-center mb-8">
            <button
              onClick={togglePlotter}
              disabled={isLoading}
              className={`toggle-button focus-visible ${isLoading ? 'opacity-50 cursor-not-allowed' : ''}`}
              data-enabled={plotterEnabled}
              aria-label={`${plotterEnabled ? 'Stop' : 'Start'} eye tracking plotter`}
            >
              <span className="toggle-slider"></span>
            </button>
          </div>

          {/* Status Text */}
          <div className="text-center mb-6">
            <p className="text-xl font-semibold text-gray-900 mb-2">
              {plotterEnabled ? 'Plotter Active' : 'Plotter Inactive'}
            </p>
            <p className="text-gray-600">
              {plotterEnabled 
                ? 'Eye tracking is active and logging medication usage' 
                : 'Tap the switch above to start eye tracking'}
            </p>
          </div>

          {/* Eye Tracking Interface */}
          {plotterEnabled && (
            <div className="mt-6">
              <button
                onClick={() => setShowEyeTracking(!showEyeTracking)}
                className="w-full btn-secondary flex items-center justify-center space-x-2"
              >
                <CameraIcon className="w-5 h-5" />
                <span>{showEyeTracking ? 'Hide' : 'Show'} Eye Tracking View</span>
              </button>
            </div>
          )}
        </div>
      )}

      {/* Error Display */}
      {error && (
        <div className="bg-red-50 border-2 border-red-200 rounded-2xl p-4">
          <div className="flex items-center space-x-3">
            <ExclamationTriangleIcon className="w-6 h-6 text-red-500" />
            <div>
              <h4 className="text-red-800 font-medium">Connection Error</h4>
              <p className="text-red-700 text-sm mt-1">{error}</p>
            </div>
          </div>
        </div>
      )}

      {/* Success Message */}
      {isConnected && !error && (
        <div className="bg-green-50 border-2 border-green-200 rounded-2xl p-4">
          <div className="flex items-center space-x-3">
            <CheckCircleIcon className="w-6 h-6 text-green-500" />
            <div>
              <h4 className="text-green-800 font-medium">Device Connected</h4>
              <p className="text-green-700 text-sm mt-1">
                Your eye tracking device is ready to use
              </p>
            </div>
          </div>
        </div>
      )}

      {/* Device Discovery Modal */}
      {showDiscovery && (
        <DeviceDiscovery
          onDeviceSelected={handleDeviceSelected}
          onClose={() => setShowDiscovery(false)}
          isLoading={isLoading}
        />
      )}

      {/* Eye Tracking Interface */}
      {showEyeTracking && plotterEnabled && (
        <EyeTrackingInterface
          arduinoService={arduinoService}
          onClose={() => setShowEyeTracking(false)}
        />
      )}
    </div>
  )
}

export default DeviceControl