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

        // Range calculation (indoor path loss model matching WebUI)
        // SX1262 sensitivity: -148 dBm @ SF12/BW125, improves ~2.5dB per SF step down
        let sensitivity = -148.0 + Double(12 - sf) * 2.5 + (bw > 125_000 ? log2(Double(bw) / 125_000.0) * 3.0 : 0.0)
        let linkBudget = Double(txPower) - sensitivity

        // Indoor path loss model with heavy attenuation
        let fadeMargin = 20.0 // dB - conservative for reliability
        let pathLossExponent = 3.5 // Heavy indoor attenuation (concrete walls, multiple floors)
        let referenceDistance = 1.0 // meters
        let referenceLoss = 50.0 // dB at 1m (realistic for indoor 868 MHz)

        // Solve for distance: d = d0 * 10^((linkBudget - fadeMargin - PL0) / (10*n))
        let range = Int(referenceDistance * pow(
            10.0,
            (linkBudget - fadeMargin - referenceLoss) / (10.0 * pathLossExponent)
        ))

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
