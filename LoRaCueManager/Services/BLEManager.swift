import CoreBluetooth
import Foundation
import OSLog

/// Manages Bluetooth Low Energy connectivity for LoRaCue devices.
///
/// `BLEManager` handles device discovery, connection management, and data communication
/// using the Nordic UART Service (NUS) protocol.
///
/// ## Topics
/// ### Scanning
/// - ``startScanning()``
/// - ``stopScanning()``
/// ### Connection
/// - ``connect(to:)``
/// - ``disconnect()``
/// ### Communication
/// - ``sendCommand(_:)``
@MainActor
class BLEManager: NSObject, ObservableObject {
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var isScanning = false
    @Published var connectedPeripheral: CBPeripheral?
    @Published var connectionState: CBPeripheralState = .disconnected

    private var centralManager: CBCentralManager!
    private var txCharacteristic: CBCharacteristic?
    private var rxCharacteristic: CBCharacteristic?
    private var responseBuffer = ""
    private var responseContinuation: CheckedContinuation<String, Error>?

    // Nordic UART Service UUIDs
    private nonisolated(unsafe) let nusServiceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    private nonisolated(unsafe) let nusTxUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    private nonisolated(unsafe) let nusRxUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")

    override init() {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    func startScanning() {
        Logger.ble.info("🔍 startScanning called, centralManager.state: \(self.centralManager.state.rawValue)")
        guard self.centralManager.state == .poweredOn else {
            Logger.ble.info("⚠️ Cannot scan - Bluetooth not powered on")
            return
        }
        self.discoveredDevices.removeAll()
        // Scan for ALL devices temporarily to test
        self.centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        self.isScanning = true
        Logger.ble.info("✅ Scanning started for ALL BLE devices")
    }

    func stopScanning() {
        self.centralManager.stopScan()
        self.isScanning = false
    }

    func connect(to peripheral: CBPeripheral) {
        Logger.ble.info("🔌 Attempting to connect to: \(peripheral.name ?? "Unknown")")
        self.stopScanning()
        self.connectionState = .connecting
        self.centralManager.connect(peripheral, options: nil)
    }

    func disconnect() {
        guard let peripheral = connectedPeripheral else { return }
        self.centralManager.cancelPeripheralConnection(peripheral)
    }

    func sendCommand(_ command: String) async throws -> String {
        guard let peripheral = connectedPeripheral,
              let tx = txCharacteristic
        else {
            throw BLEError.notConnected
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.responseContinuation = continuation
            self.responseBuffer = ""

            let data = (command + "\n").data(using: .utf8)!
            peripheral.writeValue(data, for: tx, type: .withResponse)

            Task {
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5s timeout
                if self.responseContinuation != nil {
                    self.responseContinuation?.resume(throwing: BLEError.timeout)
                    self.responseContinuation = nil
                }
            }
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            Logger.ble.info("📡 Bluetooth state changed to: \(central.state.rawValue)")
            switch central.state {
            case .poweredOn:
                Logger.ble.info("✅ Bluetooth is powered on and ready")
                if self.isScanning {
                    self.startScanning()
                }
            case .poweredOff:
                Logger.ble.info("❌ Bluetooth is powered off - Enable in System Settings")
            case .unauthorized:
                Logger.ble.info("⚠️ Bluetooth UNAUTHORIZED - Grant in System Settings → Privacy → Bluetooth")
            case .unsupported:
                Logger.ble.info("❌ Bluetooth not supported on this device")
            default:
                Logger.ble.info("⏳ Bluetooth state: \(central.state.rawValue)")
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        Task { @MainActor in
            Logger.ble.info("📱 Discovered device: \(peripheral.name ?? "Unknown") (\(peripheral.identifier))")
            if !self.discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                self.discoveredDevices.append(peripheral)
                Logger.ble.info("✅ Added to list, total devices: \(self.discoveredDevices.count)")
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            Logger.ble.info("✅ Connected to: \(peripheral.name ?? "Unknown")")
            objectWillChange.send()
            self.connectedPeripheral = peripheral
            self.connectionState = .connected
            Logger.ble.info("📊 Connection state updated, objectWillChange sent")
            peripheral.delegate = self
            peripheral.discoverServices([self.nusServiceUUID])
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            self.connectedPeripheral = nil
            self.connectionState = .disconnected
            self.txCharacteristic = nil
            self.rxCharacteristic = nil
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == self.nusServiceUUID {
            peripheral.discoverCharacteristics([nusTxUUID, nusRxUUID], for: service)
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard let characteristics = service.characteristics else { return }
        Task { @MainActor in
            for characteristic in characteristics {
                if characteristic.uuid == self.nusTxUUID {
                    self.txCharacteristic = characteristic
                } else if characteristic.uuid == self.nusRxUUID {
                    self.rxCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard let data = characteristic.value,
              let string = String(data: data, encoding: .utf8) else { return }

        Task { @MainActor in
            self.responseBuffer += string
            if self.responseBuffer.contains("\n") {
                let response = self.responseBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
                self.responseContinuation?.resume(returning: response)
                self.responseContinuation = nil
                self.responseBuffer = ""
            }
        }
    }
}

enum BLEError: Error {
    case notConnected
    case timeout
    case invalidResponse
}
