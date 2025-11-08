import Foundation

/// Protocol for device communication transport (BLE or USB)
protocol DeviceTransport {
    var isConnected: Bool { get }
    var isReady: Bool { get }
    func sendCommand(_ command: String) async throws -> String
}
