import Foundation
import OSLog

/// JSON-RPC 2.0 service for LoRaCue device configuration
@MainActor
class LoRaCueService: ObservableObject {
    let bleManager: BLEManager
    private var transport: DeviceTransport
    private var requestId = 0
    private var isProcessingRequest = false
    private let logger = Logger(subsystem: "com.loracue.manager", category: "JSONRPCService")

    var isReady: Bool {
        self.transport.isReady
    }

    init(bleManager: BLEManager) {
        self.bleManager = bleManager
        self.transport = bleManager
    }

    #if targetEnvironment(simulator)
    init(transport: DeviceTransport, bleManager: BLEManager) {
        self.bleManager = bleManager
        self.transport = transport
    }
    #endif

    /// Switch to USB transport
    #if os(macOS)
    func useUSBTransport(_ usbManager: USBManager) {
        self.transport = usbManager
    }
    #endif

    /// Switch to BLE transport
    func useBLETransport() {
        self.transport = self.bleManager
    }

    // MARK: - Core JSON-RPC Methods

    enum RPCMethod: String {
        case ping
        case deviceInfo = "device:info"
        case deviceReset = "device:reset"
        case generalGet = "general:get"
        case generalSet = "general:set"
        case powerGet = "power:get"
        case powerSet = "power:set"
        case loraGet = "lora:get"
        case loraSet = "lora:set"
        case loraBands = "lora:bands"
        case loraPresetsList = "lora:presets:list"
        case loraKeyGet = "lora:key:get"
        case loraKeySet = "lora:key:set"
        case pairedList = "paired:list"
        case pairedAdd = "paired:add"
        case pairedPair = "paired:pair"
        case pairedDelete = "paired:delete"
        case firmwareUpgrade = "firmware:upgrade"
    }

    private func sendRequest<T: Decodable>(
        method: RPCMethod,
        params: (any Encodable)? = nil,
        retryCount: Int = 0
    ) async throws -> T {
        // Fast-fail if transport not ready
        guard self.transport.isReady else {
            throw JSONRPCError.transportError("Device not connected")
        }

        // Serialize requests through a queue
        while self.isProcessingRequest {
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }

        self.isProcessingRequest = true
        defer { isProcessingRequest = false }

        do {
            return try await self.sendRequestInternal(method: method.rawValue, params: params)
        } catch let error as JSONRPCError {
            // Determine if error is retryable
            let isRetryable = self.isRetryableError(error)
            let maxRetries = 2

            if isRetryable, retryCount < maxRetries {
                let delay = UInt64(pow(2.0, Double(retryCount)) * 100_000_000) // 100ms, 200ms
                self.logger
                    .warning(
                        "⚠️ Retrying \(method.rawValue) (attempt \(retryCount + 1)/\(maxRetries)) after \(delay / 1_000_000)ms"
                    )
                try await Task.sleep(nanoseconds: delay)
                return try await self.sendRequest(method: method, params: params, retryCount: retryCount + 1)
            }

            throw error
        }
    }

    private func sendRequestInternal<T: Decodable>(
        method: String,
        params: (any Encodable)? = nil
    ) async throws -> T {
        self.requestId += 1
        let id = self.requestId

        var request: [String: Any] = [
            "jsonrpc": "2.0",
            "method": method,
            "id": id
        ]

        if let params {
            let paramsData = try JSONEncoder().encode(AnyEncodable(params))
            let paramsJSON = try JSONSerialization.jsonObject(with: paramsData)
            request["params"] = paramsJSON
        }

        let requestData = try JSONSerialization.data(withJSONObject: request)
        guard let requestString = String(data: requestData, encoding: .utf8) else {
            throw JSONRPCError.transportError("Failed to encode request")
        }

        self.logger.info("📤 JSON-RPC Request: \(requestString)")

        let responseString = try await transport.sendCommand(requestString)
        self.logger.info("📥 JSON-RPC Response: \(responseString)")

        // Validate response is not empty
        guard !responseString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            self.logger.error("❌ Empty response received")
            throw JSONRPCError.transportError("Empty response from device")
        }

        guard let responseData = responseString.data(using: .utf8) else {
            self.logger.error("❌ Response not valid UTF-8")
            throw JSONRPCError.parseError
        }

        // Attempt to decode JSON-RPC response
        let response: JSONRPCResponse<T>
        do {
            response = try JSONDecoder().decode(JSONRPCResponse<T>.self, from: responseData)
        } catch {
            self.logger.error("❌ JSON decode failed: \(error.localizedDescription)")
            self.logger.error("   Response was: \(responseString.prefix(200))")
            throw JSONRPCError.parseError
        }

        if let error = response.error {
            throw JSONRPCError(code: error.code, message: error.message)
        }

        guard let result = response.result else {
            throw JSONRPCError.invalidRequest
        }

        return result
    }

    private func isRetryableError(_ error: JSONRPCError) -> Bool {
        switch error {
        case .parseError, .timeout, .transportError:
            true
        case .invalidRequest, .methodNotFound, .invalidParams, .internalError, .unknown:
            false
        }
    }

    private func sendRequestVoid(
        method: RPCMethod,
        params: (any Encodable)? = nil
    ) async throws {
        let _: String = try await sendRequest(method: method, params: params)
    }

    // MARK: - Device Methods

    func ping() async throws -> String {
        try await self.sendRequest(method: .ping)
    }

    func getDeviceInfo() async throws -> DeviceInfo {
        try await self.sendRequest(method: .deviceInfo)
    }

    func factoryReset() async throws {
        try await self.sendRequestVoid(method: .deviceReset)
    }

    // MARK: - General Configuration

    func getGeneral() async throws -> GeneralConfig {
        try await self.sendRequest(method: .generalGet)
    }

    func setGeneral(_ config: GeneralConfig) async throws {
        try await self.sendRequestVoid(method: .generalSet, params: config)
    }

    // MARK: - Power Management

    func getPowerManagement() async throws -> PowerConfig {
        try await self.sendRequest(method: .powerGet)
    }

    func setPowerManagement(_ config: PowerConfig) async throws {
        try await self.sendRequestVoid(method: .powerSet, params: config)
    }

    // MARK: - LoRa Configuration

    func getLoRa() async throws -> LoRaConfig {
        try await self.sendRequest(method: .loraGet)
    }

    func setLoRa(_ config: LoRaConfig) async throws {
        try await self.sendRequestVoid(method: .loraSet, params: config)
    }

    func getLoRaBands() async throws -> [LoRaBand] {
        try await self.sendRequest(method: .loraBands)
    }

    func getLoRaPresets() async throws -> [LoRaPreset] {
        try await self.sendRequest(method: .loraPresetsList)
    }

    func getLoRaKey() async throws -> LoRaKey {
        try await self.sendRequest(method: .loraKeyGet)
    }

    func setLoRaKey(_ key: LoRaKey) async throws {
        try await self.sendRequestVoid(method: .loraKeySet, params: key)
    }

    // MARK: - Device Pairing

    func getPairedDevices() async throws -> [PairedDevice] {
        try await self.sendRequest(method: .pairedList)
    }

    func addPairedDevice(_ device: PairedDevice) async throws {
        try await self.sendRequestVoid(method: .pairedAdd, params: device)
    }

    func updatePairedDevice(_ device: PairedDevice) async throws {
        try await self.sendRequestVoid(method: .pairedPair, params: device)
    }

    func deletePairedDevice(mac: String) async throws {
        try await self.sendRequestVoid(method: .pairedDelete, params: ["mac": mac])
    }

    // MARK: - Firmware

    func upgradeFirmware(size: Int) async throws {
        try await self.sendRequestVoid(method: .firmwareUpgrade, params: ["size": size])
    }
}

// MARK: - Helper Types

private struct JSONRPCResponse<T: Decodable>: Decodable {
    let jsonrpc: String
    let result: T?
    let error: JSONRPCErrorResponse?
    let id: Int
}

private struct JSONRPCErrorResponse: Decodable {
    let code: Int
    let message: String
}

private struct AnyEncodable: Encodable {
    private let encode: (Encoder) throws -> Void

    init(_ encodable: any Encodable) {
        self.encode = encodable.encode
    }

    func encode(to encoder: Encoder) throws {
        try self.encode(encoder)
    }
}
