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

    private func sendRequest<T: Decodable>(
        method: String,
        params: (any Encodable)? = nil
    ) async throws -> T {
        // Serialize requests through a queue
        while self.isProcessingRequest {
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }

        self.isProcessingRequest = true
        defer { isProcessingRequest = false }

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

        guard let responseData = responseString.data(using: .utf8) else {
            throw JSONRPCError.parseError
        }

        let response = try JSONDecoder().decode(JSONRPCResponse<T>.self, from: responseData)

        if let error = response.error {
            throw JSONRPCError(code: error.code, message: error.message)
        }

        guard let result = response.result else {
            throw JSONRPCError.invalidRequest
        }

        return result
    }

    private func sendRequestVoid(
        method: String,
        params: (any Encodable)? = nil
    ) async throws {
        let _: String = try await sendRequest(method: method, params: params)
    }

    // MARK: - Device Methods

    func ping() async throws -> String {
        try await self.sendRequest(method: "ping")
    }

    func getDeviceInfo() async throws -> DeviceInfo {
        try await self.sendRequest(method: "device:info")
    }

    func factoryReset() async throws {
        try await self.sendRequestVoid(method: "device:reset")
    }

    // MARK: - General Configuration

    func getGeneral() async throws -> GeneralConfig {
        try await self.sendRequest(method: "general:get")
    }

    func setGeneral(_ config: GeneralConfig) async throws {
        try await self.sendRequestVoid(method: "general:set", params: config)
    }

    // MARK: - Power Management

    func getPowerManagement() async throws -> PowerConfig {
        try await self.sendRequest(method: "power:get")
    }

    func setPowerManagement(_ config: PowerConfig) async throws {
        try await self.sendRequestVoid(method: "power:set", params: config)
    }

    // MARK: - LoRa Configuration

    func getLoRa() async throws -> LoRaConfig {
        try await self.sendRequest(method: "lora:get")
    }

    func setLoRa(_ config: LoRaConfig) async throws {
        try await self.sendRequestVoid(method: "lora:set", params: config)
    }

    func getLoRaBands() async throws -> [LoRaBand] {
        try await self.sendRequest(method: "lora:bands")
    }

    func getLoRaKey() async throws -> LoRaKey {
        try await self.sendRequest(method: "lora:key:get")
    }

    func setLoRaKey(_ key: LoRaKey) async throws {
        try await self.sendRequestVoid(method: "lora:key:set", params: key)
    }

    // MARK: - Device Pairing

    func getPairedDevices() async throws -> [PairedDevice] {
        try await self.sendRequest(method: "paired:list")
    }

    func addPairedDevice(_ device: PairedDevice) async throws {
        try await self.sendRequestVoid(method: "paired:add", params: device)
    }

    func updatePairedDevice(_ device: PairedDevice) async throws {
        try await self.sendRequestVoid(method: "paired:pair", params: device)
    }

    func deletePairedDevice(mac: String) async throws {
        try await self.sendRequestVoid(method: "paired:delete", params: ["mac": mac])
    }

    // MARK: - Firmware

    func upgradeFirmware(size: Int) async throws {
        try await self.sendRequestVoid(method: "firmware:upgrade", params: ["size": size])
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
