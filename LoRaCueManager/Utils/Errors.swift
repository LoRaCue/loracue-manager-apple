import Foundation

enum AppError: LocalizedError {
    case bluetoothUnavailable
    case bluetoothUnauthorized
    case deviceNotConnected
    case connectionFailed(String)
    case connectionTimeout
    case commandTimeout
    case invalidResponse
    case invalidData
    case sendFailed(String)
    case unsupportedOperation

    var errorDescription: String? {
        switch self {
        case .bluetoothUnavailable: "Bluetooth is not available"
        case .bluetoothUnauthorized: "Bluetooth access not authorized"
        case .deviceNotConnected: "Device not connected"
        case let .connectionFailed(reason): "Connection failed: \(reason)"
        case .connectionTimeout: "Connection timed out"
        case .commandTimeout: "Command timed out"
        case .invalidResponse: "Invalid response from device"
        case .invalidData: "Invalid data received"
        case let .sendFailed(reason): "Send failed: \(reason)"
        case .unsupportedOperation: "Operation not supported"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .bluetoothUnavailable: "Enable Bluetooth in System Settings"
        case .bluetoothUnauthorized: "Grant Bluetooth permission in System Settings"
        case .deviceNotConnected: "Connect to a device first"
        case .connectionFailed, .connectionTimeout: "Try connecting again"
        case .commandTimeout: "Check device connection and try again"
        case .invalidResponse, .invalidData: "Device may need firmware update"
        case .sendFailed: "Check connection and retry"
        case .unsupportedOperation: "Update app or device firmware"
        }
    }
}
