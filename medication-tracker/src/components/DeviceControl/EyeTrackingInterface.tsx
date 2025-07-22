import React, { useState, useEffect, useRef } from 'react'
import { XMarkIcon, CameraIcon, ExclamationTriangleIcon } from '@heroicons/react/24/outline'
import { ArduinoWiFiService } from '../../services/arduino-wifi'

interface EyeTrackingInterfaceProps {
  arduinoService: ArduinoWiFiService
  onClose: () => void
}

const EyeTrackingInterface: React.FC<EyeTrackingInterfaceProps> = ({
  arduinoService,
  onClose
}) => {
  const videoRef = useRef<HTMLVideoElement>(null)
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const [isActive, setIsActive] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [lastPacket, setLastPacket] = useState<string | null>(null)
  const [stream, setStream] = useState<MediaStream | null>(null)

  useEffect(() => {
    return () => {
      // Cleanup on unmount
      if (stream) {
        stream.getTracks().forEach(track => track.stop())
      }
    }
  }, [stream])

  const startEyeTracking = async () => {
    setError(null)
    
    try {
      // Request camera access
      const mediaStream = await navigator.mediaDevices.getUserMedia({
        video: {
          width: 640,
          height: 480,
          facingMode: 'user'
        }
      })
      
      if (videoRef.current) {
        videoRef.current.srcObject = mediaStream
        setStream(mediaStream)
        setIsActive(true)
        
        // Start processing once video is ready
        videoRef.current.addEventListener('loadeddata', startProcessing)
      }
    } catch (err) {
      setError('Failed to access camera. Please check permissions.')
      console.error('Camera access error:', err)
    }
  }

  const stopEyeTracking = () => {
    if (stream) {
      stream.getTracks().forEach(track => track.stop())
      setStream(null)
    }
    setIsActive(false)
    setLastPacket(null)
  }

  const startProcessing = () => {
    if (!videoRef.current || !canvasRef.current) return
    
    const processFrame = () => {
      if (!isActive || !videoRef.current || !canvasRef.current) return
      
      const canvas = canvasRef.current
      const ctx = canvas.getContext('2d')
      const video = videoRef.current
      
      if (ctx && video.readyState === video.HAVE_ENOUGH_DATA) {
        // Set canvas size to match video
        canvas.width = video.videoWidth
        canvas.height = video.videoHeight
        
        // Draw current frame
        ctx.drawImage(video, 0, 0, canvas.width, canvas.height)
        
        // Simple eye position detection (center of frame for demo)
        // In a real implementation, you would use MediaPipe or similar
        const centerX = canvas.width / 2
        const centerY = canvas.height / 2
        
        // Add some random movement for demo purposes
        const offsetX = (Math.random() - 0.5) * 100
        const offsetY = (Math.random() - 0.5) * 100
        
        const eyeX = Math.round(centerX + offsetX)
        const eyeY = Math.round(centerY + offsetY)
        
        // Draw eye position indicator
        ctx.fillStyle = 'red'
        ctx.beginPath()
        ctx.arc(eyeX, eyeY, 5, 0, 2 * Math.PI)
        ctx.fill()
        
        // Draw center reference
        ctx.fillStyle = 'blue'
        ctx.beginPath()
        ctx.arc(centerX, centerY, 3, 0, 2 * Math.PI)
        ctx.fill()
        
        // Calculate directional packet
        const packet = calculateDirectionalPacket(eyeX, eyeY, canvas.width, canvas.height)
        setLastPacket(packet)
        
        // Send to Arduino
        if (arduinoService.isDeviceConnected()) {
          arduinoService.sendEyeData(packet)
        }
      }
      
      // Continue processing
      if (isActive) {
        requestAnimationFrame(processFrame)
      }
    }
    
    // Start processing loop
    requestAnimationFrame(processFrame)
  }

  const calculateDirectionalPacket = (eyeX: number, eyeY: number, frameWidth: number, frameHeight: number): string => {
    const centerX = frameWidth / 2
    const centerY = frameHeight / 2
    
    const dx = eyeX - centerX
    const dy = eyeY - centerY
    
    const dirV = dy <= 0 ? 'U' : 'D'
    const dirH = dx <= 0 ? 'L' : 'R'
    
    const distV = Math.min(Math.abs(dy), 999)
    const distH = Math.min(Math.abs(dx), 999)
    
    return `${dirV}${distV.toString().padStart(3, '0')}${dirH}${distH.toString().padStart(3, '0')}`
  }

  return (
    <div className="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-3xl shadow-2xl max-w-4xl w-full max-h-[90vh] overflow-hidden">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-gray-100">
          <div className="flex items-center space-x-3">
            <CameraIcon className="w-6 h-6 text-light-blue-500" />
            <h3 className="text-lg font-semibold text-gray-900">Live Eye Tracking</h3>
          </div>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-100 rounded-xl transition-colors"
          >
            <XMarkIcon className="w-5 h-5 text-gray-500" />
          </button>
        </div>

        <div className="p-6 space-y-6">
          {/* Camera Feed */}
          <div className="bg-gray-900 rounded-2xl overflow-hidden relative">
            {!isActive ? (
              <div className="aspect-video flex items-center justify-center">
                <div className="text-center text-white">
                  <CameraIcon className="w-16 h-16 mx-auto mb-4 opacity-50" />
                  <p className="text-lg mb-4">Camera not active</p>
                  <button
                    onClick={startEyeTracking}
                    className="btn-primary"
                  >
                    Start Camera
                  </button>
                </div>
              </div>
            ) : (
              <div className="relative">
                <video
                  ref={videoRef}
                  autoPlay
                  muted
                  playsInline
                  className="w-full h-auto"
                />
                <canvas
                  ref={canvasRef}
                  className="absolute inset-0 w-full h-full"
                />
                
                {/* Controls Overlay */}
                <div className="absolute bottom-4 left-4 right-4 flex justify-between items-center">
                  <div className="bg-black bg-opacity-50 text-white px-3 py-2 rounded-lg text-sm">
                    {lastPacket ? `Packet: ${lastPacket}` : 'Initializing...'}
                  </div>
                  
                  <button
                    onClick={stopEyeTracking}
                    className="bg-red-500 hover:bg-red-600 text-white px-4 py-2 rounded-lg transition-colors"
                  >
                    Stop
                  </button>
                </div>
              </div>
            )}
          </div>

          {/* Error Display */}
          {error && (
            <div className="bg-red-50 border-2 border-red-200 rounded-2xl p-4">
              <div className="flex items-center space-x-3">
                <ExclamationTriangleIcon className="w-6 h-6 text-red-500" />
                <div>
                  <h4 className="text-red-800 font-medium">Camera Error</h4>
                  <p className="text-red-700 text-sm mt-1">{error}</p>
                </div>
              </div>
            </div>
          )}

          {/* Instructions */}
          <div className="bg-light-blue-50 rounded-2xl p-4">
            <h4 className="font-medium text-gray-900 mb-2">Instructions</h4>
            <ul className="text-sm text-gray-600 space-y-1">
              <li>• Position your face in the center of the camera view</li>
              <li>• The red dot shows detected eye position</li>
              <li>• The blue dot shows the center reference point</li>
              <li>• Eye tracking data is sent to the plotter in real-time</li>
              <li>• Keep good lighting for best results</li>
            </ul>
          </div>

          {/* Status Info */}
          {isActive && (
            <div className="bg-green-50 border-2 border-green-200 rounded-2xl p-4">
              <div className="flex items-center space-x-3">
                <div className="w-3 h-3 bg-green-500 rounded-full animate-pulse"></div>
                <div>
                  <h4 className="text-green-800 font-medium">Eye Tracking Active</h4>
                  <p className="text-green-700 text-sm mt-1">
                    Sending eye position data to plotter device
                  </p>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

export default EyeTrackingInterface