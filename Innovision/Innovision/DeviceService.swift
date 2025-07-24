import Foundation
import Network
import SwiftUI

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

    private var connection: NWConnection?
    private let connectionQueue = DispatchQueue(label: "device-connection", qos: .userInitiated)
    
    // Arduino R4 WiFi - Update this IP if your Arduino gets a different address
    // Check Arduino Serial Monitor for actual IP after WiFi connection
    private let arduinoHost = "192.168.1.60"
    private let arduinoPort: UInt16 = 8080

    func connect() {
        guard !isConnected else { return }
        
        connectionError = nil
        let host = NWEndpoint.Host(arduinoHost)
        let port = NWEndpoint.Port(rawValue: arduinoPort)!
        
        connection = NWConnection(host: host, port: port, using: .tcp)
        connection?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard let self = self else { return }
                
                switch state {
                case .ready:
                    self.isConnected = true
                    self.connectionError = nil
                    // Get initial plotter status
                    await self.getPlotterStatus()
                case .failed(let error):
                    self.isConnected = false
                    self.connectionError = "Connection failed: \(error.localizedDescription)"
                case .cancelled:
                    self.isConnected = false
                    self.connectionError = nil
                default:
                    self.isConnected = false
                }
            }
        }
        connection?.start(queue: connectionQueue)
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        isConnected = false
        isRunning   = false
    }

    func startPlotter() async {
        guard isConnected else {
            connectionError = "Device not connected"
            return
        }
        await sendHTTPRequest(endpoint: "/start")
    }
    
    func stopPlotter() async {
        await sendHTTPRequest(endpoint: "/stop")
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
        guard let conn = connection, isConnected else {
            connectionError = "Cannot send command: not connected"
            return
        }
        
        let httpRequest = "GET \(endpoint) HTTP/1.1\r\nHost: \(arduinoHost)\r\nConnection: close\r\n\r\n"
        lastCommand = endpoint
        connectionError = nil
        
        return await withCheckedContinuation { continuation in
            conn.send(content: Data(httpRequest.utf8), completion: .contentProcessed { [weak self] error in
                Task { @MainActor in
                    guard let self = self else {
                        continuation.resume()
                        return
                    }
                    
                    if let error = error {
                        self.connectionError = "Send failed: \(error.localizedDescription)"
                        continuation.resume()
                        return
                    }
                    
                    // Read response
                    conn.receive(minimumIncompleteLength: 1, maximumLength: 1024) { [weak self] data, _, isComplete, error in
                        Task { @MainActor in
                            guard let self = self else {
                                continuation.resume()
                                return
                            }
                            
                            if let error = error {
                                self.connectionError = "Receive failed: \(error.localizedDescription)"
                            } else if let data = data, let response = String(data: data, encoding: .utf8) {
                                self.parseHTTPResponse(response)
                            }
                            
                            continuation.resume()
                        }
                    }
                }
            })
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
}
