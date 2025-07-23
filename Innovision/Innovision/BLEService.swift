import Foundation
import CoreBluetooth
import SwiftUI

@MainActor
final class BLEService: NSObject, ObservableObject {
    @Published var isScanning = false
    @Published var isConnected = false
    @Published var connectedPeripheral: CBPeripheral?
    @Published var connectionError: String?
    @Published var discoveredPeripherals: [CBPeripheral] = []
    
    private var centralManager: CBCentralManager!
    private var characteristic: CBCharacteristic?
    
    nonisolated private let serviceUUID = CBUUID(string: "12345678-1234-1234-1234-123456789ABC")
    nonisolated private let characteristicUUID = CBUUID(string: "87654321-4321-4321-4321-CBA987654321")
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            connectionError = "Bluetooth is not powered on"
            return
        }
        connectionError = nil
        discoveredPeripherals.removeAll()
        isScanning = true
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
        
        // Auto-stop scanning after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            if self.isScanning {
                self.stopScanning()
            }
        }
    }
    
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
    }
    
    func connect(to peripheral: CBPeripheral) {
        guard centralManager.state == .poweredOn else {
            connectionError = "Bluetooth is not available"
            return
        }
        connectionError = nil
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    func sendCommand(_ command: String) {
        guard let characteristic = characteristic,
              let data = command.data(using: .utf8),
              let peripheral = connectedPeripheral else {
            connectionError = "Device not properly connected"
            return
        }
        
        connectionError = nil
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }
}

extension BLEService: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("BLE is powered on")
        case .poweredOff:
            print("BLE is powered off")
        case .resetting:
            print("BLE is resetting")
        case .unauthorized:
            print("BLE is unauthorized")
        case .unsupported:
            print("BLE is unsupported")
        case .unknown:
            print("BLE state unknown")
        @unknown default:
            print("Unknown BLE state")
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        Task { @MainActor in
            if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
                discoveredPeripherals.append(peripheral)
            }
            
            // Auto-connect to first discovered device (you may want to change this behavior)
            if discoveredPeripherals.count == 1 {
                connect(to: peripheral)
                stopScanning()
            }
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            connectedPeripheral = peripheral
            peripheral.delegate = self
            isConnected = true
            peripheral.discoverServices([serviceUUID])
            print("Connected to peripheral: \(peripheral.name ?? "Unknown")")
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            connectedPeripheral = nil
            isConnected = false
            
            if let error = error {
                connectionError = "Disconnected unexpectedly: \(error.localizedDescription)"
                print("Disconnected with error: \(error.localizedDescription)")
            } else {
                print("Disconnected from peripheral")
            }
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            let errorMessage = "Failed to connect: \(error?.localizedDescription ?? "Unknown error")"
            connectionError = errorMessage
            print(errorMessage)
            isConnected = false
        }
    }
}

extension BLEService: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            peripheral.discoverCharacteristics([characteristicUUID], for: service)
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.uuid == characteristicUUID {
                Task { @MainActor in
                    self.characteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let data = characteristic.value, let string = String(data: data, encoding: .utf8) {
            print("Received data: \(string)")
        }
    }
}