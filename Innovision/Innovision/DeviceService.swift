import Foundation
import Network
import SwiftUI

@MainActor
final class DeviceService: ObservableObject {
    @Published var isConnected = false
    @Published var isRunning   = false

    private var connection: NWConnection?

    func connect() {
        guard !isConnected else { return }
        let host = NWEndpoint.Host("192.168.4.1")  // replace with your board’s IP
        let port = NWEndpoint.Port(rawValue: 8080)!
        connection = NWConnection(host: host, port: port, using: .tcp)
        connection?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in self?.isConnected = (state == .ready) }
        }
        connection?.start(queue: .global())
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        isConnected = false
        isRunning   = false
    }

    func startDropper() { send("START"); isRunning = true  }
    func stopDropper()  { send("STOP");  isRunning = false }

    private func send(_ cmd: String) {
        guard let conn = connection, isConnected else { return }
        conn.send(content: Data(cmd.utf8), completion: .contentProcessed { _ in })
    }
}
