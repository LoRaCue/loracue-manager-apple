#if targetEnvironment(simulator)
import Foundation

class MockTransport: DeviceTransport {
    var isConnected = true
    var isReady = true

    func sendCommand(_ command: String) async throws -> String {
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms delay

        guard let data = command.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let method = json["method"] as? String,
              let id = json["id"]
        else {
            return """
            {"jsonrpc":"2.0","error":{"code":-32700,"message":"Parse error"},"id":null}
            """
        }

        switch method {
        case "ping":
            return """
            {"jsonrpc":"2.0","result":"pong","id":\(id)}
            """

        case "device:info":
            return """
            {"jsonrpc":"2.0","result":{"model":"LC-Alpha","board_id":"heltec_v3","version":"0.2.0-mock",\
            "commit":"mock123","branch":"simulator","build_date":"2025-01-06","chip_model":"esp32s3",\
            "chip_revision":2,"cpu_cores":2,"flash_size_mb":8,"mac":"10:51:db:52:81:e4","uptime_sec":1234,\
            "free_heap_kb":27,"partition":"factory"},"id":\(id)}
            """

        case "general:get":
            return """
            {"jsonrpc":"2.0","result":{"name":"MockDevice","mode":"PRESENTER","brightness":128,\
            "slot_id":1,"bluetooth":true},"id":\(id)}
            """

        case "power:get":
            return """
            {"jsonrpc":"2.0","result":{"display_sleep_enabled":true,"display_sleep_timeout_ms":30000,\
            "light_sleep_enabled":true,"light_sleep_timeout_ms":60000,"deep_sleep_enabled":false,\
            "deep_sleep_timeout_ms":300000},"id":\(id)}
            """

        case "lora:get":
            return """
            {"jsonrpc":"2.0","result":{"band_id":"HW_433","frequency":433000,"spreading_factor":7,\
            "bandwidth":500,"coding_rate":5,"tx_power":20},"id":\(id)}
            """

        case "lora:bands":
            return """
            {"jsonrpc":"2.0","result":[{"id":"HW_433","name":"433/470 MHz Band","center_khz":433000,\
            "min_khz":430000,"max_khz":440000,"max_power_dbm":10}],"id":\(id)}
            """

        case "lora:key:get":
            return """
            {"jsonrpc":"2.0","result":{"aes_key":\
            "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"},"id":\(id)}
            """

        case "paired:list":
            return """
            {"jsonrpc":"2.0","result":[{"name":"Device-001","mac":"aa:bb:cc:dd:ee:ff",\
            "aes_key":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"},\
            {"name":"Device-002","mac":"11:22:33:44:55:66",\
            "aes_key":"fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210"}],"id":\(id)}
            """

        case "general:set", "power:set", "lora:set", "lora:key:set":
            return """
            {"jsonrpc":"2.0","result":"ok","id":\(id)}
            """

        case "paired:pair":
            return """
            {"jsonrpc":"2.0","result":"Device paired successfully","id":\(id)}
            """

        case "paired:unpair":
            return """
            {"jsonrpc":"2.0","result":"Device unpaired successfully","id":\(id)}
            """

        case "device:reset":
            return """
            {"jsonrpc":"2.0","result":"ok","id":\(id)}
            """

        case "firmware:upgrade":
            return """
            {"jsonrpc":"2.0","result":{"status":"ready","size":1048576},"id":\(id)}
            """

        default:
            return """
            {"jsonrpc":"2.0","error":{"code":-32601,"message":"Method not found"},"id":\(id)}
            """
        }
    }
}
#endif
