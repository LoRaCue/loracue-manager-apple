import CoreBluetooth
import Foundation
import OSLog

struct DeviceAdvertisementData {
    let model: String?
    let version: String?
}

/// Manages Bluetooth Low Energy connectivity for LoRaCue devices.
///
/// `BLEManager` handles device discovery, connection management, and data communication
/// using the Nordic UART Service (NUS) protocol.
@MainActor
class BLEManager: NSObject, ObservableObject, DeviceTransport {
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var isScanning = false
    @Published var connectedPeripheral: CBPeripheral?
    @Published var connectionState: CBPeripheralState = .disconnected
    @Published var bluetoothState: CBManagerState = .unknown
    @Published private var _isReady = false

    private var advertisementData: [UUID: DeviceAdvertisementData] = [:]

    nonisolated var isReady: Bool {
        MainActor.assumeIsolated {
            self._isReady
        }
    }

    nonisolated var isConnected: Bool {
        MainActor.assumeIsolated {
            self.connectedPeripheral != nil
        }
    }

    // MARK: - Constants

    private enum Constants {
        static let nusServiceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
        static let nusTxUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
        static let nusRxUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")

        static let connectionTimeout: UInt64 = 5_000_000_000 // 5 seconds
        static let commandTimeout: UInt64 = 5_000_000_000 // 5 seconds
        static let deviceReadyTimeoutIterations = 50
        static let deviceReadyCheckInterval: UInt64 = 100_000_000 // 100 ms
        static let responseAccumulationDelay: UInt64 = 200_000_000 // 200 ms
        static let maxResponseBufferSize = 65536
    }

    var onConnectionChanged: (() -> Void)?

    let instanceId = UUID().uuidString.prefix(8)

    private var centralManager: CBCentralManager!
    private var txCharacteristic: CBCharacteristic?
    private var rxCharacteristic: CBCharacteristic?
    private var responseBuffer = Data()
    private var responseContinuation: CheckedContinuation<String, Error>?
    private var responseAccumulationTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?

    private struct QueuedCommand {
        let command: String
        let continuation: CheckedContinuation<String, Error>
    }

    private var commandQueue: [QueuedCommand] = []
    private var isProcessingQueue = false

    override init() {
        super.init()
        Logger.ble.info("🆕 BLEManager created: \(self.instanceId)")
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

        // Timeout after 5 seconds
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: Constants.connectionTimeout)
            if self.connectionState == .connecting {
                Logger.ble.error("⏱️ Connection timeout")
                self.centralManager.cancelPeripheralConnection(peripheral)
            }
        }
    }

    func disconnect() {
        guard let peripheral = connectedPeripheral else { return }
        self.centralManager.cancelPeripheralConnection(peripheral)
    }

    func getAdvertisementData(for peripheral: CBPeripheral) -> DeviceAdvertisementData? {
        self.advertisementData[peripheral.identifier]
    }

    func sendCommand(_ command: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                self.commandQueue.append(QueuedCommand(command: command, continuation: continuation))
                if !self.isProcessingQueue {
                    self.processCommandQueue()
                }
            }
        }
    }

    /// Processes the command queue serially.
    ///
    /// This method checks if the queue is currently being processed. If not, it
    /// iterates through the queue, sending each command and handling the result.
    /// If a command fails, the error is propagated to the caller via the continuation.
    private func processCommandQueue() {
        guard !self.isProcessingQueue, !self.commandQueue.isEmpty else { return }

        self.isProcessingQueue = true

        Task { @MainActor in
            while !self.commandQueue.isEmpty {
                let queued = self.commandQueue.removeFirst()

                do {
                    let result = try await self.sendCommandInternal(queued.command)
                    queued.continuation.resume(returning: result)
                } catch {
                    queued.continuation.resume(throwing: error)
                }
            }

            self.isProcessingQueue = false
        }
    }

    /// Sends a command to the connected peripheral and awaits a response.
    ///
    /// This method performs the following steps:
    /// 1. Verifies connection and characteristic availability.
    /// 2. Waits for the device to be in a "ready" state (signaled by RX characteristic discovery).
    /// 3. Writes the command string (UTF-8) to the TX characteristic.
    /// 4. Awaits a response via `responseContinuation`, with a timeout mechanism.
    ///
    /// - Parameter command: The string command to send (without newline, as it's added automatically).
    /// - Returns: The complete response string from the device.
    /// - Throws: `BLEError.notConnected` if device is not ready, `BLEError.timeout` if no response.
    private func sendCommandInternal(_ command: String) async throws -> String {
        guard let peripheral = connectedPeripheral,
              let tx = txCharacteristic
        else {
            throw BLEError.notConnected
        }

        // Wait for device to be ready
        if !self._isReady {
            Logger.ble.info("⏳ Waiting for device to be ready...")
            for _ in 0 ..< Constants.deviceReadyTimeoutIterations {
                if self._isReady { break }
                try await Task.sleep(nanoseconds: Constants.deviceReadyCheckInterval)
            }
            if !self._isReady {
                Logger.ble.error("❌ Device not ready after timeout")
                throw BLEError.notConnected
            }
            Logger.ble.info("✅ Device ready, proceeding with command")
        }

        Logger.ble.info("📤 Sending command: \(command)")

        let result: String
        do {
            result = try await withCheckedThrowingContinuation { continuation in
                // Cancel any previous timeout
                self.timeoutTask?.cancel()

                self.responseContinuation = continuation
                self.responseBuffer.removeAll()

                let data = (command + "\n").data(using: .utf8)!
                Logger.ble.info("📤 Writing \(data.count) bytes to TX characteristic")
                peripheral.writeValue(data, for: tx, type: .withResponse)

                self.timeoutTask = Task { @MainActor in
                    do {
                        try await Task.sleep(nanoseconds: Constants.commandTimeout)
                    } catch {
                        return // Task was cancelled
                    }
                    if self.responseContinuation != nil {
                        Logger.ble.error("⏱️ Command timed out: \(command)")
                        self.responseContinuation?.resume(throwing: BLEError.timeout)
                        self.responseContinuation = nil
                    }
                }
            }
        } catch {
            // Clean up on error
            self.timeoutTask?.cancel()
            self.responseContinuation = nil
            self.responseBuffer.removeAll()
            throw error
        }

        // Cancel timeout on success
        self.timeoutTask?.cancel()
        return result
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            self.bluetoothState = central.state
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
            guard peripheral.name?.hasPrefix("LoRaCue") == true else { return }

            Logger.ble.info("📱 Discovered device: \(peripheral.name ?? "Unknown") (\(peripheral.identifier))")

            // Parse manufacturer data
            var advData: DeviceAdvertisementData?
            Logger.ble.debug("📊 Advertisement data keys: \(advertisementData.keys)")
            if let mfgData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data, mfgData.count >= 7 {
                Logger.ble.debug("📊 Manufacturer data length: \(mfgData.count) bytes")
                // Skip company ID (first 2 bytes)
                let major = mfgData[2]
                let minor = mfgData[3]
                let patch = mfgData[4]
                let buildFlags = UInt16(mfgData[5]) | (UInt16(mfgData[6]) << 8)
                let buildNumber = (buildFlags >> 2) & 0x3FFF
                let releaseType = buildFlags & 0b11
                let modelName = String(data: mfgData[7...], encoding: .utf8) ?? "Unknown"

                let typeString = ["", "beta", "alpha", "dev"][Int(releaseType)]
                let versionString = buildNumber > 0 && !typeString.isEmpty
                    ? "v\(major).\(minor).\(patch)-\(typeString).\(buildNumber)"
                    : "v\(major).\(minor).\(patch)"

                advData = DeviceAdvertisementData(model: modelName, version: versionString)
                Logger.ble.info("📦 Parsed: \(modelName) \(versionString)")
            }

            if !self.discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                self.discoveredDevices.append(peripheral)
                if let advData {
                    self.advertisementData[peripheral.identifier] = advData
                }
                Logger.ble.info("✅ Added to list, total devices: \(self.discoveredDevices.count)")
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        Task { @MainActor in
            Logger.ble.info("✅ Connected to: \(peripheral.name ?? "Unknown") [BLEManager: \(self.instanceId)]")
            Logger.ble.info("📤 Sending objectWillChange...")
            objectWillChange.send()
            if let callback = self.onConnectionChanged {
                Logger.ble.info("📤 Calling onConnectionChanged callback")
                callback()
                Logger.ble.info("✅ onConnectionChanged callback completed")
            } else {
                Logger.ble.error("❌ onConnectionChanged is nil! Cannot notify service")
            }
            Logger.ble.info("✅ objectWillChange sent")
            self.connectedPeripheral = peripheral
            Logger.ble.info("✅ connectedPeripheral set to: \(peripheral.identifier.uuidString)")
            self.connectionState = .connected
            Logger.ble.info("📊 Connection state updated, discovering services...")
        }
        peripheral.discoverServices([Constants.nusServiceUUID])
        Logger.ble.info("🔍 Requested service discovery for NUS")
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                Logger.ble.error("❌ Connection lost: \(error.localizedDescription)")
            } else {
                Logger.ble.info("✅ Disconnected gracefully")
            }

            // Cancel pending operations
            self.responseContinuation?.resume(throwing: BLEError.notConnected)
            self.responseContinuation = nil
            self.responseAccumulationTask?.cancel()
            self.responseAccumulationTask = nil
            self.responseBuffer.removeAll()

            // Clean up state
            self.connectedPeripheral = nil
            self.connectionState = .disconnected
            self.txCharacteristic = nil
            self.rxCharacteristic = nil
            self._isReady = false

            // Notify observers
            self.onConnectionChanged?()
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            if let error {
                Logger.ble.error("❌ Service discovery error: \(error.localizedDescription)")
                return
            }
            guard let services = peripheral.services else {
                Logger.ble.warning("⚠️ No services found")
                return
            }
            Logger.ble.info("🔍 Discovered \(services.count) service(s)")
            for service in services where service.uuid == Constants.nusServiceUUID {
                Logger.ble.info("✅ Found NUS service, discovering characteristics...")
                peripheral.discoverCharacteristics([Constants.nusTxUUID, Constants.nusRxUUID], for: service)
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                Logger.ble.error("❌ Characteristic discovery error: \(error.localizedDescription)")
                return
            }
            guard let characteristics = service.characteristics else {
                Logger.ble.warning("⚠️ No characteristics found")
                return
            }
            Logger.ble.info("🔍 Discovered \(characteristics.count) characteristic(s)")
            var foundTx = false
            var foundRx = false
            for characteristic in characteristics {
                if characteristic.uuid == Constants.nusTxUUID {
                    foundTx = true
                } else if characteristic.uuid == Constants.nusRxUUID {
                    foundRx = true
                }
            }
            if foundTx, foundRx {
                Logger.ble.info("📤 Sending objectWillChange (characteristics ready)...")
                self.objectWillChange.send()
                Logger.ble.info("✅ objectWillChange sent (characteristics ready)")
            }
            for characteristic in characteristics {
                if characteristic.uuid == Constants.nusTxUUID {
                    self.txCharacteristic = characteristic
                    Logger.ble.info("✅ TX characteristic ready")
                } else if characteristic.uuid == Constants.nusRxUUID {
                    self.rxCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                    Logger.ble.info("✅ RX characteristic ready, notifications enabled")
                }
            }
            if self.txCharacteristic != nil, self.rxCharacteristic != nil {
                self._isReady = true
                Logger.ble.info("🎉 Device fully ready for communication")
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error {
            Logger.ble.error("⚠️ Characteristic update error: \(error.localizedDescription)")
            return
        }

        guard let data = characteristic.value else {
            Logger.ble.warning("⚠️ Received empty data or nil")
            return
        }

        Task { @MainActor in
            Logger.ble.info("📥 Received chunk: \(data.count) bytes")
            self.responseBuffer.append(data)

            // Prevent buffer overflow from corrupted stream
            if self.responseBuffer.count > Constants.maxResponseBufferSize {
                Logger.ble.error("❌ Response buffer overflow - possible corrupted data")
                self.responseContinuation?.resume(throwing: BLEError.invalidResponse)
                self.responseContinuation = nil
                self.responseBuffer.removeAll()
                self.responseAccumulationTask?.cancel()
                self.responseAccumulationTask = nil
                return
            }

            // Cancel previous accumulation task
            self.responseAccumulationTask?.cancel()

            // Wait for more chunks (200ms to handle large responses)
            self.responseAccumulationTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: Constants.responseAccumulationDelay)

                guard let string = String(data: self.responseBuffer, encoding: .utf8) else {
                    // Keep waiting? Or fail? For now, assume split char and wait,
                    // OR it might just be garbage.
                    // If we don't decode, we can't check for newline/JSON easily.
                    // Let's just log and wait for next packet or timeout.
                    Logger.ble.warning("⚠️ Buffer not valid UTF-8 yet, waiting for more data...")
                    return
                }

                let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                Logger.ble.info("📦 Accumulated response: \(trimmed.count) chars")

                // Check for complete response:
                // 1. Contains newline
                // 2. Complete JSON object or array
                // 3. Plain text response (OK/ERROR)
                let hasNewline = trimmed.contains("\n")
                let isCompleteJSON = (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) ||
                    (trimmed.hasPrefix("[") && trimmed.hasSuffix("]"))
                let isPlainText = trimmed.hasPrefix("OK ") || trimmed.hasPrefix("ERROR ")

                if hasNewline || isCompleteJSON || isPlainText {
                    Logger.ble.info("✅ Complete response: \(trimmed.prefix(100))...")
                    self.responseContinuation?.resume(returning: trimmed)
                    self.responseContinuation = nil
                    self.responseBuffer.removeAll()
                    self.responseAccumulationTask = nil
                }
            }
        }
    }
}
