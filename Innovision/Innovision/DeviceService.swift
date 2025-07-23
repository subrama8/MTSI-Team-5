import Foundation
import Network
import SwiftUI

@MainActor
final class DeviceService: ObservableObject {
    @Published var isConnected = false
    @Published var isRunning   = false
    @Published var connectionError: String?
    @Published var lastCommand: String?

    private var connection: NWConnection?
    private let connectionQueue = DispatchQueue(label: "device-connection", qos: .userInitiated)

    func connect() {
        guard !isConnected else { return }
        
        connectionError = nil
        let host = NWEndpoint.Host("192.168.4.1")  // replace with your board's IP
        let port = NWEndpoint.Port(rawValue: 8080)!
        
        connection = NWConnection(host: host, port: port, using: .tcp)
        connection?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard let self = self else { return }
                
                switch state {
                case .ready:
                    self.isConnected = true
                    self.connectionError = nil
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

    func startDropper() {
        guard isConnected else {
            connectionError = "Device not connected"
            return
        }
        send("START")
        isRunning = true
    }
    
    func stopDropper() {
        send("STOP")
        isRunning = false
    }

    private func send(_ cmd: String) {
        guard let conn = connection, isConnected else {
            connectionError = "Cannot send command: not connected"
            return
        }
        
        lastCommand = cmd
        connectionError = nil
        
        conn.send(content: Data(cmd.utf8), completion: .contentProcessed { error in
            Task { @MainActor in
                if let error = error {
                    self.connectionError = "Send failed: \(error.localizedDescription)"
                }
            }
        })
    }
}
