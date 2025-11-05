import Combine
import Foundation

/// High-level service for LoRaCue device configuration and management.
///
/// `LoRaCueService` provides a unified interface for device operations,
/// abstracting the underlying BLE/USB transport layer.
///
/// ## Topics
/// ### Configuration
/// - ``getConfiguration()``
/// - ``setConfiguration(_:)``
/// ### System Operations
/// - ``factoryReset()``
/// - ``updateFirmware(data:progress:)``
@MainActor
class LoRaCueService: ObservableObject {
    let bleManager: BLEManager?
    #if os(macOS)
    let usbManager: USBManager?
    #endif

    enum ConnectionType {
        case ble
        case usb
    }

    private var connectionType: ConnectionType = .ble
    private var cancellables = Set<AnyCancellable>()

    init(bleManager: BLEManager) {
        self.bleManager = bleManager
        #if os(macOS)
        self.usbManager = nil
        #endif

        // Forward BLEManager changes
        bleManager.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &self.cancellables)
    }

    #if os(macOS)
    init(usbManager: USBManager) {
        self.bleManager = nil
        self.usbManager = usbManager
        self.connectionType = .usb
    }
    #endif

    func sendCommand(_ command: String) async throws -> String {
        let response: String

        switch self.connectionType {
        case .ble:
            guard let ble = bleManager else { throw ServiceError.notConnected }
            response = try await ble.sendCommand(command)
        case .usb:
            #if os(macOS)
            guard let usb = usbManager else { throw ServiceError.notConnected }
            response = try await usb.sendCommand(command)
            #else
            throw ServiceError.notConnected
            #endif
        }

        if response.starts(with: "ERROR") {
            throw ServiceError.deviceError(response)
        }

        return response
    }

    // MARK: - API Methods

    func ping() async throws -> String {
        try await self.sendCommand("PING")
    }

    func getDeviceInfo() async throws -> DeviceInfo {
        let response = try await sendCommand("GET_DEVICE_INFO")
        return try JSONDecoder().decode(DeviceInfo.self, from: response.data(using: .utf8)!)
    }

    func getGeneralConfig() async throws -> GeneralConfig {
        let response = try await sendCommand("GET_GENERAL")
        return try JSONDecoder().decode(GeneralConfig.self, from: response.data(using: .utf8)!)
    }

    func setGeneralConfig(_ config: GeneralConfig) async throws {
        let json = try JSONEncoder().encode(config)
        let jsonString = String(data: json, encoding: .utf8)!
        _ = try await self.sendCommand("SET_GENERAL \(jsonString)")
    }

    func getPowerConfig() async throws -> PowerConfig {
        let response = try await sendCommand("GET_POWER_MANAGEMENT")
        return try JSONDecoder().decode(PowerConfig.self, from: response.data(using: .utf8)!)
    }

    func setPowerConfig(_ config: PowerConfig) async throws {
        let json = try JSONEncoder().encode(config)
        let jsonString = String(data: json, encoding: .utf8)!
        _ = try await self.sendCommand("SET_POWER_MANAGEMENT \(jsonString)")
    }

    func getLoRaConfig() async throws -> LoRaConfig {
        let response = try await sendCommand("GET_LORA")
        return try JSONDecoder().decode(LoRaConfig.self, from: response.data(using: .utf8)!)
    }

    func setLoRaConfig(_ config: LoRaConfig) async throws {
        let json = try JSONEncoder().encode(config)
        let jsonString = String(data: json, encoding: .utf8)!
        _ = try await self.sendCommand("SET_LORA \(jsonString)")
    }

    func getLoRaKey() async throws -> LoRaKey {
        let response = try await sendCommand("GET_LORA_KEY")
        return try JSONDecoder().decode(LoRaKey.self, from: response.data(using: .utf8)!)
    }

    func setLoRaKey(_ key: LoRaKey) async throws {
        let json = try JSONEncoder().encode(key)
        let jsonString = String(data: json, encoding: .utf8)!
        _ = try await self.sendCommand("SET_LORA_KEY \(jsonString)")
    }

    func getLoRaBands() async throws -> [LoRaBand] {
        let response = try await sendCommand("GET_LORA_BANDS")
        return try JSONDecoder().decode([LoRaBand].self, from: response.data(using: .utf8)!)
    }

    func getPairedDevices() async throws -> [PairedDevice] {
        let response = try await sendCommand("GET_PAIRED_DEVICES")
        return try JSONDecoder().decode([PairedDevice].self, from: response.data(using: .utf8)!)
    }

    func pairDevice(_ device: PairedDevice) async throws {
        let json = try JSONEncoder().encode(device)
        let jsonString = String(data: json, encoding: .utf8)!
        _ = try await self.sendCommand("PAIR_DEVICE \(jsonString)")
    }

    func updatePairedDevice(_ device: PairedDevice) async throws {
        let json = try JSONEncoder().encode(device)
        let jsonString = String(data: json, encoding: .utf8)!
        _ = try await self.sendCommand("UPDATE_PAIRED_DEVICE \(jsonString)")
    }

    func unpairDevice(mac: String) async throws {
        let request = UnpairRequest(mac: mac)
        let json = try JSONEncoder().encode(request)
        let jsonString = String(data: json, encoding: .utf8)!
        _ = try await self.sendCommand("UNPAIR_DEVICE \(jsonString)")
    }

    func factoryReset() async throws {
        _ = try await self.sendCommand("FACTORY_RESET")
    }

    func startFirmwareUpgrade(firmware: Data) async throws {
        if self.connectionType == .ble {
            // TODO: Integrate Nordic DFU library for BLE
            throw ServiceError.notImplemented
        } else {
            #if os(macOS)
            _ = try await self.sendCommand("FIRMWARE_UPGRADE \(firmware.count)")
            // Wait for "OK Ready"
            // Stream binary data
            // Wait for "OK Complete"
            throw ServiceError.notImplemented
            #else
            throw ServiceError.notImplemented
            #endif
        }
    }
}

enum ServiceError: Error {
    case notConnected
    case deviceError(String)
    case notImplemented
}
