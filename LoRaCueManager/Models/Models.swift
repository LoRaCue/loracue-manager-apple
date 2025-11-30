import Foundation

// MARK: - Device Info

/// System information for a LoRaCue device.
///
/// Contains hardware details, firmware version, and runtime statistics.
struct DeviceInfo: Codable {
    let model: String
    let boardId: String
    let version: String
    let commit: String
    let branch: String
    let buildDate: String
    let chipModel: String
    let chipRevision: Int
    let cpuCores: Int
    let flashSizeMb: Int
    let mac: String
    let uptimeSec: Int
    let freeHeapKb: Int
    let partition: String

    enum CodingKeys: String, CodingKey {
        case model
        case boardId = "board_id"
        case version
        case commit
        case branch
        case buildDate = "build_date"
        case chipModel = "chip_model"
        case chipRevision = "chip_revision"
        case cpuCores = "cpu_cores"
        case flashSizeMb = "flash_size_mb"
        case mac
        case uptimeSec = "uptime_sec"
        case freeHeapKb = "free_heap_kb"
        case partition
    }
}

// MARK: - General Config

enum DeviceMode: String, Codable, CaseIterable, Identifiable {
    case presenter = "PRESENTER"
    case pc = "PC"

    var id: String { self.rawValue }
}

struct GeneralConfig: Codable, Equatable {
    var name: String
    var mode: DeviceMode
    var contrast: Int
    var bluetooth: Bool
    var slotId: Int

    enum CodingKeys: String, CodingKey {
        case name
        case mode
        case contrast
        case bluetooth
        case slotId = "slot_id"
    }
}

// MARK: - Power Config

struct PowerConfig: Codable, Equatable {
    var displaySleepEnabled: Bool
    var displaySleepTimeoutMs: Int
    var lightSleepEnabled: Bool
    var lightSleepTimeoutMs: Int
    var deepSleepEnabled: Bool
    var deepSleepTimeoutMs: Int

    enum CodingKeys: String, CodingKey {
        case displaySleepEnabled = "display_sleep_enabled"
        case displaySleepTimeoutMs = "display_sleep_timeout_ms"
        case lightSleepEnabled = "light_sleep_enabled"
        case lightSleepTimeoutMs = "light_sleep_timeout_ms"
        case deepSleepEnabled = "deep_sleep_enabled"
        case deepSleepTimeoutMs = "deep_sleep_timeout_ms"
    }
}

// MARK: - LoRa Config

struct LoRaConfig: Codable, Equatable {
    var bandId: String
    var frequency: Int
    var spreadingFactor: Int
    var bandwidth: Int
    var codingRate: Int
    var txPower: Int

    enum CodingKeys: String, CodingKey {
        case bandId = "band_id"
        case frequency = "frequency_khz"
        case spreadingFactor = "spreading_factor"
        case bandwidth = "bandwidth_khz"
        case codingRate = "coding_rate"
        case txPower = "tx_power_dbm"
    }
}

// MARK: - LoRa Key

struct LoRaKey: Codable {
    var aesKey: String

    enum CodingKeys: String, CodingKey {
        case aesKey = "aes_key"
    }
}

// MARK: - Paired Device

struct PairedDevice: Codable, Identifiable, Hashable {
    var id: String { self.mac }
    var name: String
    var mac: String
    var aesKey: String

    enum CodingKeys: String, CodingKey {
        case name
        case mac
        case aesKey = "aes_key"
    }
}

// MARK: - LoRa Band

struct LoRaBand: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let centerKhz: Int
    let minKhz: Int
    let maxKhz: Int
    let maxPowerDbm: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case centerKhz = "center_khz"
        case minKhz = "min_khz"
        case maxKhz = "max_khz"
        case maxPowerDbm = "max_power_dbm"
    }
}

// MARK: - Unpair Request

struct UnpairRequest: Codable {
    let mac: String
}

// MARK: - JSON-RPC Error

/// JSON-RPC 2.0 error codes and user-friendly messages
enum JSONRPCError: Error, LocalizedError {
    case parseError
    case invalidRequest
    case methodNotFound
    case invalidParams(String)
    case internalError(String)
    case transportError(String)
    case timeout
    case unknown(Int, String)

    init(code: Int, message: String) {
        switch code {
        case -32700:
            self = .parseError
        case -32600:
            self = .invalidRequest
        case -32601:
            self = .methodNotFound
        case -32602:
            self = .invalidParams(message)
        case -32603:
            self = .internalError(message)
        default:
            self = .unknown(code, message)
        }
    }

    var errorDescription: String? {
        switch self {
        case .parseError:
            "error.json_parse".localized
        case .invalidRequest:
            "error.invalid_request".localized
        case .methodNotFound:
            "error.method_not_found".localized
        case let .invalidParams(detail):
            "error.invalid_params".localized(detail)
        case let .internalError(detail):
            "error.internal_error".localized(detail)
        case let .transportError(detail):
            "error.transport_error".localized(detail)
        case .timeout:
            "error.request_timeout".localized
        case let .unknown(code, message):
            "error.unknown".localized(code, message)
        }
    }
}
