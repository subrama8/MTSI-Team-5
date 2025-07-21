import Foundation
import Network
import Combine

struct ArduinoDeviceInfo {
    let name: String
    let ipAddress: String
    let type: String
    let version: String
    let capabilities: String
    let isOnline: Bool
}

struct ArduinoStatus {
    let device: String
    let plotterEnabled: Bool
    let wifiConnected: Bool
    let ipAddress: String
}

@MainActor
class ArduinoService: ObservableObject {
    static let shared = ArduinoService()
    
    @Published var isConnected = false
    @Published var plotterEnabled = false
    @Published var deviceInfo: ArduinoDeviceInfo?
    @Published var isScanning = false
    
    private var currentIP: String?
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Load saved device IP
        if let savedIP = UserDefaults.standard.string(forKey: "arduino_ip") {
            currentIP = savedIP
            Task {
                await connectToDevice(ipAddress: savedIP)
            }
        }
    }
    
    // MARK: - Device Discovery
    
    func discoverDevices() async throws -> [ArduinoDeviceInfo] {
        isScanning = true
        defer { isScanning = false }
        
        let localNetworkBase = await getLocalNetworkBase()
        var devices: [ArduinoDeviceInfo] = []
        
        await withTaskGroup(of: ArduinoDeviceInfo?.self) { group in
            // Scan common IP range
            for i in 1..<255 {
                let ip = "\(localNetworkBase).\(i)"
                
                group.addTask {
                    await self.checkDevice(ip: ip)
                }
            }
            
            for await device in group {
                if let device = device {
                    devices.append(device)
                }
            }
        }
        
        return devices
    }
    
    private func getLocalNetworkBase() async -> String {
        // Try to determine local network base
        // For now, return common network base
        return "192.168.1"
    }
    
    private func checkDevice(ip: String) async -> ArduinoDeviceInfo? {
        guard let url = URL(string: "http://\(ip)/api/discover") else { return nil }
        
        do {
            let request = URLRequest(url: url, timeoutInterval: 2.0)
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }
            
            let deviceInfo = try JSONDecoder().decode(DiscoveryResponse.self, from: data)
            
            if deviceInfo.type == "eye-tracker-plotter" {
                return ArduinoDeviceInfo(
                    name: deviceInfo.device,
                    ipAddress: ip,
                    type: deviceInfo.type,
                    version: deviceInfo.version,
                    capabilities: deviceInfo.capabilities,
                    isOnline: true
                )
            }
        } catch {
            // Device not responding or not our type
        }
        
        return nil
    }
    
    // MARK: - Device Connection
    
    func connectToDevice(ipAddress: String) async -> Bool {
        do {
            guard let device = await checkDevice(ip: ipAddress) else {
                return false
            }
            
            currentIP = ipAddress
            deviceInfo = device
            isConnected = true
            
            // Save IP for future connections
            UserDefaults.standard.set(ipAddress, forKey: "arduino_ip")
            
            // Get initial status
            try await refreshStatus()
            
            return true
            
        } catch {
            print("Failed to connect to device: \(error)")
            isConnected = false
            deviceInfo = nil
            return false
        }
    }
    
    func disconnect() {
        isConnected = false
        deviceInfo = nil
        plotterEnabled = false
        currentIP = nil
        UserDefaults.standard.removeObject(forKey: "arduino_ip")
    }
    
    // MARK: - Device Control
    
    func refreshStatus() async throws {
        guard let ip = currentIP,
              let url = URL(string: "http://\(ip)/api/status") else {
            throw ArduinoError.notConnected
        }
        
        let request = URLRequest(url: url, timeoutInterval: 5.0)
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ArduinoError.communicationFailed
        }
        
        let status = try JSONDecoder().decode(StatusResponse.self, from: data)
        
        plotterEnabled = status.plotterEnabled
        
        // Update device info
        if deviceInfo != nil {
            deviceInfo = ArduinoDeviceInfo(
                name: status.device,
                ipAddress: status.ipAddress,
                type: deviceInfo?.type ?? "eye-tracker-plotter",
                version: deviceInfo?.version ?? "Unknown",
                capabilities: deviceInfo?.capabilities ?? "plotter,eye-tracking",
                isOnline: status.wifiConnected
            )
        }
    }
    
    func startPlotter() async throws {
        guard let ip = currentIP,
              let url = URL(string: "http://\(ip)/api/plotter/start") else {
            throw ArduinoError.notConnected
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ArduinoError.commandFailed
        }
        
        plotterEnabled = true
    }
    
    func stopPlotter() async throws {
        guard let ip = currentIP,
              let url = URL(string: "http://\(ip)/api/plotter/stop") else {
            throw ArduinoError.notConnected
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ArduinoError.commandFailed
        }
        
        plotterEnabled = false
    }
    
    func sendEyeData(packet: String) async throws {
        guard let ip = currentIP,
              let url = URL(string: "http://\(ip)/api/eye-data") else {
            throw ArduinoError.notConnected
        }
        
        let payload = EyeDataPayload(packet: packet)
        let jsonData = try JSONEncoder().encode(payload)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ArduinoError.communicationFailed
        }
    }
}

// MARK: - Data Models

struct DiscoveryResponse: Codable {
    let device: String
    let type: String
    let version: String
    let capabilities: String
}

struct StatusResponse: Codable {
    let device: String
    let plotterEnabled: Bool
    let wifiConnected: Bool
    let ipAddress: String
}

struct EyeDataPayload: Codable {
    let packet: String
}

// MARK: - Errors

enum ArduinoError: LocalizedError {
    case notConnected
    case communicationFailed
    case commandFailed
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Device not connected"
        case .communicationFailed:
            return "Failed to communicate with device"
        case .commandFailed:
            return "Command execution failed"
        case .invalidResponse:
            return "Invalid response from device"
        }
    }
}