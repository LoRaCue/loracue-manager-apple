#if targetEnvironment(simulator)
import Foundation

class MockTransport: DeviceTransport {
    var isConnected = true
    var isReady = true

    private let mockResponses: [String: String] = [
        "ping": #"{"jsonrpc":"2.0","result":"pong","id":ID}"#,

        "device:info": """
        {"jsonrpc":"2.0","result":{"model":"LC-Alpha","board_id":"heltec_v3","version":"0.2.0-mock",\
        "commit":"mock123","branch":"simulator","build_date":"2025-01-06","chip_model":"esp32s3",\
        "chip_revision":2,"cpu_cores":2,"flash_size_mb":8,"mac":"10:51:db:52:81:e4","uptime_sec":1234,\
        "free_heap_kb":27,"partition":"factory"},"id":ID}
        """,

        "general:get": """
        {"jsonrpc":"2.0","result":{"name":"MockDevice","mode":"PRESENTER","brightness":128,\
        "slot_id":1,"bluetooth":true},"id":ID}
        """,

        "power:get": """
        {"jsonrpc":"2.0","result":{"display_sleep_enabled":true,"display_sleep_timeout_ms":30000,\
        "light_sleep_enabled":true,"light_sleep_timeout_ms":60000,"deep_sleep_enabled":false,\
        "deep_sleep_timeout_ms":300000},"id":ID}
        """,

        "lora:get": """
        {"jsonrpc":"2.0","result":{"band_id":"HW_433","frequency_khz":433000,"spreading_factor":7,\
        "bandwidth_khz":500,"coding_rate":5,"tx_power_dbm":20},"id":ID}
        """,

        "lora:bands": """
        {"jsonrpc":"2.0","result":[{"id":"HW_433","name":"433/470 MHz Band","center_khz":433000,\
        "min_khz":430000,"max_khz":440000,"max_power_dbm":10}],"id":ID}
        """,

        "lora:key:get": """
        {"jsonrpc":"2.0","result":{"aes_key":\
        "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"},"id":ID}
        """,

        "paired:list": """
        {"jsonrpc":"2.0","result":[{"name":"Device-001","mac":"aa:bb:cc:dd:ee:ff",\
        "aes_key":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"},\
        {"name":"Device-002","mac":"11:22:33:44:55:66",\
        "aes_key":"fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210"}],"id":ID}
        """
    ]

    private let simpleOkMethods = [
        "general:set", "power:set", "lora:set", "lora:key:set",
        "paired:pair", "paired:unpair", "device:reset"
    ]

    func sendCommand(_ command: String) async throws -> String {
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms delay

        guard let data = command.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let method = json["method"] as? String,
              let id = json["id"]
        else {
            return #"{"jsonrpc":"2.0","error":{"code":-32700,"message":"Parse error"},"id":null}"#
        }

        // Check dictionary responses
        if let response = mockResponses[method] {
            return response.replacingOccurrences(of: "ID", with: "\(id)")
        }

        // Check simple OK responses
        if self.simpleOkMethods.contains(method) {
            return #"{"jsonrpc":"2.0","result":"ok","id":ID}"#.replacingOccurrences(of: "ID", with: "\(id)")
        }

        // Method not found
        return """
        {"jsonrpc":"2.0","error":{"code":-32601,"message":"Method not found"},"id":\(id)}
        """
    }
}
#endif
