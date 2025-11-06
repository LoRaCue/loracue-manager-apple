import Foundation

/// Protocol for device communication transport (BLE or USB)
protocol DeviceTransport {
    func sendCommand(_ command: String) async throws -> String
}
