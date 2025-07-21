//
//  DeviceService.swift
//  Innovision
//
//  Created by Stephanie Shen on 7/21/25.
//


import Foundation
import Network

/// Simple wrapper that connects to the Arduino R4 WiFi
/// at 192.168.4.1:8080 (change to your host) and sends
/// "START" / "STOP" commands.
@MainActor
final class DeviceService: ObservableObject {
    @Published var isConnected = false
    @Published var isRunning   = false

    private var connection: NWConnection?

    func connect() {
        guard !isConnected else { return }
        let host = NWEndpoint.Host("192.168.4.1")
        let port = NWEndpoint.Port(rawValue: 8080)!
        connection = NWConnection(host: host, port: port, using: .tcp)
        connection?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.isConnected = (state == .ready)
            }
        }
        connection?.start(queue: .global())
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        isConnected = false
        isRunning   = false
    }

    func startDropper() { send("START");  isRunning = true  }
    func stopDropper()  { send("STOP");   isRunning = false }

    private func send(_ cmd: String) {
        guard let conn = connection, isConnected else { return }
        conn.send(content: cmd.data(using: .utf8), completion: .contentProcessed { _ in })
    }
}
