import OSLog

extension Logger {
    private static let subsystem = "com.loracue.manager"

    static let ble = Logger(subsystem: subsystem, category: "BLE")
    static let usb = Logger(subsystem: subsystem, category: "USB")
    static let service = Logger(subsystem: subsystem, category: "Service")
    static let ui = Logger(subsystem: subsystem, category: "UI")
    static let performance = Logger(subsystem: subsystem, category: "Performance")
}
