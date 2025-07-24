import Foundation
import Network
import SwiftUI
import Combine

struct PlotterStatus: Codable {
    let status: String
    let enabled: Bool
    let wifi: Bool?
    let error: String?
}

@MainActor
final class DeviceService: ObservableObject {
    @Published var isConnected = false
    @Published var isRunning   = false
    @Published var connectionError: String?
    @Published var lastCommand: String?
    @Published var plotterStatus: String = "unknown"
    
    // Camera streaming properties
    @Published var cameraConnected = false
    @Published var cameraStreamURL: URL?
    @Published var discoveredCameraHosts: [String] = []

    private let connectionQueue = DispatchQueue(label: "device-connection", qos: .userInitiated)
    
    // Arduino R4 WiFi - Update this IP if your Arduino gets a different address
    // Check Arduino Serial Monitor for actual IP after WiFi connection
    private let arduinoHost = "192.168.1.60"
    private let arduinoPort: UInt16 = 8080
    
    // Camera server discovery
    private let cameraPort: UInt16 = 8081
    private var discoveryTimer: Timer?

    func connect() {
        guard !isConnected else { return }
        
        Task {
            connectionError = nil
            
            // Test connectivity by getting plotter status
            await getPlotterStatus()
            
            // If no error occurred, we're connected
            if connectionError == nil {
                isConnected = true
            }
        }
    }

    func disconnect() {
        isConnected = false
        isRunning   = false
        connectionError = nil
    }

    func startPlotter() async {
        await sendHTTPRequest(endpoint: "/start")
        // Give a moment for the Arduino to process, then refresh status
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        await getPlotterStatus()
    }
    
    func stopPlotter() async {
        await sendHTTPRequest(endpoint: "/stop")
        // Give a moment for the Arduino to process, then refresh status
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        await getPlotterStatus()
    }
    
    func getPlotterStatus() async {
        await sendHTTPRequest(endpoint: "/status")
    }
    
    // Legacy methods for backward compatibility
    func startDropper() {
        Task {
            await startPlotter()
        }
    }
    
    func stopDropper() {
        Task {
            await stopPlotter()
        }
    }

    private func sendHTTPRequest(endpoint: String) async {
        lastCommand = endpoint
        connectionError = nil
        
        // Create a new connection for each HTTP request
        let host = NWEndpoint.Host(arduinoHost)
        let port = NWEndpoint.Port(rawValue: arduinoPort)!
        let requestConnection = NWConnection(host: host, port: port, using: .tcp)
        
        return await withCheckedContinuation { continuation in
            var hasResumed = false
            
            requestConnection.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    guard let self = self else {
                        if !hasResumed {
                            hasResumed = true
                            continuation.resume()
                        }
                        return
                    }
                    
                    switch state {
                    case .ready:
                        // Connection ready, send HTTP request
                        let httpRequest = "GET \(endpoint) HTTP/1.1\r\nHost: \(self.arduinoHost)\r\nConnection: close\r\n\r\n"
                        
                        requestConnection.send(content: Data(httpRequest.utf8), completion: .contentProcessed { error in
                            if let error = error {
                                Task { @MainActor in
                                    self.connectionError = "Send failed: \(error.localizedDescription)"
                                    if !hasResumed {
                                        hasResumed = true
                                        continuation.resume()
                                    }
                                }
                                return
                            }
                            
                            // Read response
                            requestConnection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { data, _, isComplete, error in
                                Task { @MainActor in
                                    if let error = error {
                                        self.connectionError = "Receive failed: \(error.localizedDescription)"
                                    } else if let data = data, let response = String(data: data, encoding: .utf8) {
                                        self.parseHTTPResponse(response)
                                    }
                                    
                                    // Allow a brief delay before canceling to let server close gracefully
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        requestConnection.cancel()
                                    }
                                    
                                    if !hasResumed {
                                        hasResumed = true
                                        continuation.resume()
                                    }
                                }
                            }
                        })
                        
                    case .failed(let error):
                        self.connectionError = "Request failed: \(error.localizedDescription)"
                        if !hasResumed {
                            hasResumed = true
                            continuation.resume()
                        }
                        
                    case .cancelled:
                        if !hasResumed {
                            hasResumed = true
                            continuation.resume()
                        }
                        
                    default:
                        break
                    }
                }
            }
            
            requestConnection.start(queue: connectionQueue)
            
            // Set a timeout - increased for slower networks
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                if !hasResumed {
                    hasResumed = true
                    requestConnection.cancel()
                    Task { @MainActor in
                        self.connectionError = "Request timeout"
                    }
                    continuation.resume()
                }
            }
        }
    }
    
    private func parseHTTPResponse(_ response: String) {
        // Extract JSON from HTTP response
        let lines = response.components(separatedBy: "\n")
        guard let jsonLine = lines.first(where: { $0.starts(with: "{") }) else {
            return
        }
        
        guard let jsonData = jsonLine.data(using: .utf8) else {
            return
        }
        
        do {
            let status = try JSONDecoder().decode(PlotterStatus.self, from: jsonData)
            
            // Update UI state based on response
            if let error = status.error {
                connectionError = error
            } else {
                connectionError = nil
                plotterStatus = status.status
                isRunning = status.enabled
                
                print("Plotter status updated: \(status.status), enabled: \(status.enabled)")
            }
        } catch {
            print("Failed to parse plotter status: \(error)")
            connectionError = "Failed to parse response"
        }
    }
    
    // MARK: - Camera Discovery and Streaming
    
    func startCameraDiscovery() {
        stopCameraDiscovery()
        
        discoveryTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task {
                await self.discoverCameraServers()
            }
        }
        
        // Run initial discovery
        Task {
            await discoverCameraServers()
        }
    }
    
    func stopCameraDiscovery() {
        discoveryTimer?.invalidate()
        discoveryTimer = nil
    }
    
    private func discoverCameraServers() async {
        var foundHosts: [String] = []
        
        // Try common local IP ranges
        let baseIPs = [
            "192.168.1.", "192.168.0.", "10.0.0.", "172.16.0."
        ]
        
        await withTaskGroup(of: String?.self) { group in
            // Check common IP addresses in parallel
            for baseIP in baseIPs {
                for i in [1, 100, 101, 102, 103, 104, 105, 110, 150, 200] {
                    let host = "\(baseIP)\(i)"
                    group.addTask {
                        await self.checkCameraServer(host: host)
                    }
                }
            }
            
            // Also check localhost
            group.addTask {
                await self.checkCameraServer(host: "127.0.0.1")
            }
            
            for await result in group {
                if let host = result {
                    foundHosts.append(host)
                }
            }
        }
        
        await MainActor.run {
            discoveredCameraHosts = foundHosts
            if let firstHost = foundHosts.first {
                cameraStreamURL = URL(string: "http://\(firstHost):\(cameraPort)/stream.mjpeg")
                cameraConnected = true
                print("📷 Camera server discovered at: \(firstHost)")
            } else {
                cameraConnected = false
                cameraStreamURL = nil
            }
        }
    }
    
    private func checkCameraServer(host: String) async -> String? {
        do {
            let url = URL(string: "http://\(host):\(cameraPort)/status")!
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? String,
               status == "running" {
                return host
            }
        } catch {
            // Silently ignore connection errors during discovery
        }
        return nil
    }
    
    func connectToCamera(host: String? = nil) {
        if let host = host {
            cameraStreamURL = URL(string: "http://\(host):\(cameraPort)/stream.mjpeg")
            cameraConnected = true
        } else if let firstHost = discoveredCameraHosts.first {
            cameraStreamURL = URL(string: "http://\(firstHost):\(cameraPort)/stream.mjpeg")
            cameraConnected = true
        }
    }
    
    func disconnectFromCamera() {
        cameraConnected = false
        cameraStreamURL = nil
    }
}
