import Foundation

enum LoRaCalculator {
    /// Calculate Time on Air (latency in ms) and Range (in meters) based on LoRa parameters
    static func calculatePerformance(sf: Int, bw: Int, cr: Int, txPower: Int) -> (latency: Int, range: Int) {
        // Time on Air calculation (simplified)
        let symbolDuration = Double(1 << sf) / Double(bw) * 1000.0
        let preambleTime = (8.0 + 4.25) * symbolDuration

        let payloadSymbols = 8.0 + max(
            ceil((8.0 * 20.0 - 4.0 * Double(sf) + 28.0 + 16.0) / (4.0 * Double(sf))) * Double(cr),
            0.0
        )
        let payloadTime = payloadSymbols * symbolDuration

        let timeOnAir = Int(preambleTime + payloadTime)

        // Range calculation (Friis transmission equation approximation)
        let frequency = 868.0 // MHz (default EU868)
        let pathLossExponent = 3.5 // Indoor/urban environment (realistic for stadiums/auditoriums)
        let receiverSensitivity = -137.0 - Double(sf - 7) * 2.5

        let pathLoss = Double(txPower) - receiverSensitivity
        let range = Int(pow(10.0, (pathLoss - 20.0 * log10(frequency) - 32.44) / (10.0 * pathLossExponent)))

        return (latency: timeOnAir, range: range)
    }

    /// Format timeout in milliseconds to human-readable string
    static func formatTimeout(_ ms: Int) -> String {
        if ms < 1000 {
            "\(ms)ms"
        } else if ms < 60000 {
            "\(ms / 1000)s"
        } else {
            "\(ms / 60000)min"
        }
    }

    /// Generate random 64-character hex AES key
    static func generateRandomAESKey() -> String {
        let bytes = (0 ..< 32).map { _ in UInt8.random(in: 0 ... 255) }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    /// Format MAC address with colons (e.g., "AA:BB:CC:DD:EE:FF")
    static func formatMACAddress(_ input: String) -> String {
        let cleaned = input.replacingOccurrences(of: ":", with: "").uppercased()
        var formatted = ""
        for (index, char) in cleaned.enumerated() {
            if index > 0, index % 2 == 0 {
                formatted += ":"
            }
            formatted.append(char)
        }
        return formatted
    }
}
