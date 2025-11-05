import CoreBluetooth
import Foundation

/// Protocol for BLE manager functionality
protocol BLEManagerProtocol: AnyObject {
    var isScanning: Bool { get }
    var discoveredDevices: [DiscoveredDevice] { get }
    var connectedDevice: CBPeripheral? { get }
    var isDeviceConnected: Bool { get }

    func startScanning()
    func stopScanning()
    func connect(to device: DiscoveredDevice) async throws
    func disconnect()
    func sendCommand(_ command: String) async throws -> String
}

/// Protocol for USB manager functionality
protocol USBManagerProtocol: AnyObject {
    var discoveredDevices: [DiscoveredDevice] { get }
    var connectedDevice: io_object_t { get }
    var isDeviceConnected: Bool { get }

    func startScanning()
    func stopScanning()
    func connect(to device: DiscoveredDevice) async throws
    func disconnect()
    func sendCommand(_ command: String) async throws -> String
}

/// Protocol for LoRaCue service functionality
protocol LoRaCueServiceProtocol: AnyObject {
    func getGeneralConfig() async throws -> GeneralConfig
    func setGeneralConfig(_ config: GeneralConfig) async throws
    func getPowerConfig() async throws -> PowerConfig
    func getLoRaConfig() async throws -> LoRaConfig
    func factoryReset() async throws
}

/// Discovered device representation
struct DiscoveredDevice: Identifiable, Hashable {
    let id: String
    let name: String
    let type: DeviceType
    let rssi: Int?

    enum DeviceType {
        case ble
        case usb
    }
}
