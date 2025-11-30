import Foundation

enum AppConstants {
    static let macAddressLength = 17
    static let aesKeyLength = 64
    static let taskSleepNanoseconds: UInt64 = 100_000_000

    enum App {
        static let version = "1.0.0"
        static let build = "1"
        static let minMacOSWidth: CGFloat = 900
        static let minMacOSHeight: CGFloat = 600
    }

    enum GitHub {
        static let repoOwner = "LoRaCue"
        static let repoName = "loracue"
        static let baseURL = "https://api.github.com"
    }

    enum Firmware {
        static let minBinarySize = 1024
        static let esp32MagicByte: UInt8 = 0xE9
    }
}
