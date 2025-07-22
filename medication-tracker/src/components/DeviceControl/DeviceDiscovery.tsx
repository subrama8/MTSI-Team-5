import React, { useState, useEffect } from 'react'
import { 
  XMarkIcon, 
  MagnifyingGlassIcon, 
  WifiIcon,
  ExclamationTriangleIcon 
} from '@heroicons/react/24/outline'
import { ArduinoWiFiService, DeviceInfo } from '../../services/arduino-wifi'

interface DeviceDiscoveryProps {
  onDeviceSelected: (device: DeviceInfo) => void
  onClose: () => void
  isLoading: boolean
}

const DeviceDiscovery: React.FC<DeviceDiscoveryProps> = ({
  onDeviceSelected,
  onClose,
  isLoading: parentLoading
}) => {
  const [devices, setDevices] = useState<DeviceInfo[]>([])
  const [isSearching, setIsSearching] = useState(false)
  const [searchComplete, setSearchComplete] = useState(false)
  const [manualIP, setManualIP] = useState('')
  const [showManualEntry, setShowManualEntry] = useState(false)

  useEffect(() => {
    startDiscovery()
  }, [])

  const startDiscovery = async () => {
    setIsSearching(true)
    setSearchComplete(false)
    setDevices([])
    
    try {
      const arduinoService = new ArduinoWiFiService()
      const foundDevices = await arduinoService.discoverDevices()
      setDevices(foundDevices)
    } catch (error) {
      console.error('Discovery failed:', error)
    } finally {
      setIsSearching(false)
      setSearchComplete(true)
    }
  }

  const handleManualConnect = () => {
    if (!manualIP.trim()) return
    
    const manualDevice: DeviceInfo = {
      device: 'Manual Entry',
      type: 'eye-tracker-plotter',
      version: 'Unknown',
      capabilities: 'plotter,eye-tracking',
      ipAddress: manualIP.trim()
    }
    
    onDeviceSelected(manualDevice)
  }

  const isValidIP = (ip: string) => {
    const parts = ip.split('.')
    return parts.length === 4 && parts.every(part => {
      const num = parseInt(part, 10)
      return !isNaN(num) && num >= 0 && num <= 255
    })
  }

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-3xl shadow-2xl max-w-md w-full max-h-[90vh] overflow-hidden">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-gray-100">
          <div className="flex items-center space-x-3">
            <WifiIcon className="w-6 h-6 text-light-blue-500" />
            <h3 className="text-lg font-semibold text-gray-900">Find Device</h3>
          </div>
          <button
            onClick={onClose}
            disabled={parentLoading}
            className="p-2 hover:bg-gray-100 rounded-xl transition-colors"
          >
            <XMarkIcon className="w-5 h-5 text-gray-500" />
          </button>
        </div>

        <div className="p-6 space-y-6 overflow-y-auto max-h-[calc(90vh-120px)]">
          {/* Search Status */}
          <div className="text-center">
            {isSearching && (
              <div className="flex items-center justify-center space-x-2 text-light-blue-600">
                <MagnifyingGlassIcon className="w-5 h-5 animate-pulse" />
                <span>Searching for devices...</span>
              </div>
            )}
            
            {!isSearching && !searchComplete && (
              <p className="text-gray-600">Ready to search for devices</p>
            )}
            
            {searchComplete && devices.length === 0 && (
              <div className="text-center py-4">
                <ExclamationTriangleIcon className="w-12 h-12 text-yellow-500 mx-auto mb-2" />
                <p className="text-gray-600 mb-4">No devices found on your network</p>
                <button
                  onClick={startDiscovery}
                  disabled={parentLoading}
                  className="btn-secondary text-sm py-2 px-4"
                >
                  Search Again
                </button>
              </div>
            )}
          </div>

          {/* Found Devices */}
          {devices.length > 0 && (
            <div className="space-y-3">
              <h4 className="font-medium text-gray-900">Available Devices</h4>
              {devices.map((device, index) => (
                <button
                  key={index}
                  onClick={() => onDeviceSelected(device)}
                  disabled={parentLoading}
                  className="w-full p-4 bg-light-blue-50 hover:bg-light-blue-100 rounded-2xl transition-colors text-left disabled:opacity-50"
                >
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="font-medium text-gray-900">{device.device}</p>
                      <p className="text-sm text-gray-600">{device.ipAddress}</p>
                      <p className="text-xs text-gray-500 mt-1">
                        Version: {device.version} • {device.capabilities}
                      </p>
                    </div>
                    <WifiIcon className="w-5 h-5 text-light-blue-500" />
                  </div>
                </button>
              ))}
            </div>
          )}

          {/* Manual IP Entry */}
          <div className="border-t border-gray-100 pt-6">
            <button
              onClick={() => setShowManualEntry(!showManualEntry)}
              className="text-light-blue-600 hover:text-light-blue-700 text-sm font-medium"
            >
              {showManualEntry ? 'Hide manual entry' : 'Enter IP address manually'}
            </button>
            
            {showManualEntry && (
              <div className="mt-4 space-y-4">
                <div>
                  <label htmlFor="manual-ip" className="block text-sm font-medium text-gray-700 mb-2">
                    Device IP Address
                  </label>
                  <input
                    id="manual-ip"
                    type="text"
                    value={manualIP}
                    onChange={(e) => setManualIP(e.target.value)}
                    placeholder="192.168.1.100"
                    className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-light-blue-200 focus:border-light-blue-500"
                  />
                  <p className="text-xs text-gray-500 mt-1">
                    Enter the IP address shown on your Arduino device
                  </p>
                </div>
                
                <button
                  onClick={handleManualConnect}
                  disabled={!manualIP.trim() || !isValidIP(manualIP.trim()) || parentLoading}
                  className="w-full btn-primary disabled:bg-gray-300"
                >
                  Connect to Device
                </button>
              </div>
            )}
          </div>

          {/* Instructions */}
          <div className="bg-gray-50 rounded-2xl p-4">
            <h4 className="font-medium text-gray-900 mb-2">Setup Instructions</h4>
            <ol className="text-sm text-gray-600 space-y-1 list-decimal list-inside">
              <li>Make sure your Arduino R4 WiFi is powered on</li>
              <li>Ensure it's connected to the same WiFi network</li>
              <li>The device should appear in the search results</li>
              <li>If not found, check the Arduino serial monitor for the IP address</li>
            </ol>
          </div>
        </div>
      </div>
    </div>
  )
}

export default DeviceDiscovery