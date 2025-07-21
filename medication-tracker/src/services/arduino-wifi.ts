export interface DeviceStatus {
  device: string
  plotterEnabled: boolean
  wifiConnected: boolean
  ipAddress: string
}

export interface DeviceInfo {
  device: string
  type: string
  version: string
  capabilities: string
  ipAddress: string
}

export class ArduinoWiFiService {
  private baseUrl: string = ''
  private isConnected: boolean = false
  private deviceInfo: DeviceInfo | null = null

  constructor() {
    // Try to load saved device IP from localStorage
    const savedIP = localStorage.getItem('arduino_ip')
    if (savedIP) {
      this.baseUrl = `http://${savedIP}`
    }
  }

  async discoverDevices(): Promise<DeviceInfo[]> {
    const devices: DeviceInfo[] = []
    const promises: Promise<void>[] = []

    // Scan common local network IPs for Arduino devices
    const baseIP = await this.getLocalNetworkBase()
    
    for (let i = 1; i < 255; i++) {
      const ip = `${baseIP}.${i}`
      const promise = this.checkDevice(ip)
        .then((device) => {
          if (device) {
            devices.push({ ...device, ipAddress: ip })
          }
        })
        .catch(() => {
          // Ignore connection errors during discovery
        })
      
      promises.push(promise)
    }

    await Promise.allSettled(promises)
    return devices
  }

  private async getLocalNetworkBase(): Promise<string> {
    try {
      // Try to get local IP to determine network base
      const response = await fetch('/api/network-info')
      if (response.ok) {
        const data = await response.json()
        return data.networkBase || '192.168.1'
      }
    } catch {
      // Fallback to common network bases
    }
    return '192.168.1'
  }

  private async checkDevice(ip: string): Promise<DeviceInfo | null> {
    try {
      const controller = new AbortController()
      const timeoutId = setTimeout(() => controller.abort(), 2000) // 2 second timeout

      const response = await fetch(`http://${ip}/api/discover`, {
        method: 'GET',
        signal: controller.signal,
      })
      
      clearTimeout(timeoutId)

      if (response.ok) {
        const data = await response.json()
        if (data.type === 'eye-tracker-plotter') {
          return data
        }
      }
    } catch (error) {
      // Device not responding or not our type
    }
    return null
  }

  async connectToDevice(ipAddress: string): Promise<boolean> {
    try {
      this.baseUrl = `http://${ipAddress}`
      const device = await this.checkDevice(ipAddress)
      
      if (device) {
        this.isConnected = true
        this.deviceInfo = { ...device, ipAddress }
        localStorage.setItem('arduino_ip', ipAddress)
        return true
      }
    } catch (error) {
      console.error('Failed to connect to device:', error)
    }
    
    this.isConnected = false
    this.deviceInfo = null
    return false
  }

  async getDeviceStatus(): Promise<DeviceStatus | null> {
    if (!this.isConnected || !this.baseUrl) {
      return null
    }

    try {
      const response = await fetch(`${this.baseUrl}/api/status`, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
        },
      })

      if (response.ok) {
        return await response.json()
      }
    } catch (error) {
      console.error('Failed to get device status:', error)
      this.isConnected = false
    }

    return null
  }

  async startPlotter(): Promise<boolean> {
    if (!this.isConnected || !this.baseUrl) {
      throw new Error('Device not connected')
    }

    try {
      const response = await fetch(`${this.baseUrl}/api/plotter/start`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
      })

      return response.ok
    } catch (error) {
      console.error('Failed to start plotter:', error)
      throw error
    }
  }

  async stopPlotter(): Promise<boolean> {
    if (!this.isConnected || !this.baseUrl) {
      throw new Error('Device not connected')
    }

    try {
      const response = await fetch(`${this.baseUrl}/api/plotter/stop`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
      })

      return response.ok
    } catch (error) {
      console.error('Failed to stop plotter:', error)
      throw error
    }
  }

  async sendEyeData(packet: string): Promise<boolean> {
    if (!this.isConnected || !this.baseUrl) {
      return false
    }

    try {
      const response = await fetch(`${this.baseUrl}/api/eye-data`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ packet }),
      })

      return response.ok
    } catch (error) {
      console.error('Failed to send eye data:', error)
      return false
    }
  }

  isDeviceConnected(): boolean {
    return this.isConnected
  }

  getDeviceInfo(): DeviceInfo | null {
    return this.deviceInfo
  }

  disconnect(): void {
    this.isConnected = false
    this.deviceInfo = null
    this.baseUrl = ''
    localStorage.removeItem('arduino_ip')
  }
}