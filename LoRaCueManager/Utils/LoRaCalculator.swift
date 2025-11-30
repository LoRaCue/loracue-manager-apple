import Foundation

enum LoRaCalculator {
    private enum Constants {
        // Time on Air Constants
        static let preambleSymbols = 8.0
        static let syncWordSymbols = 4.25
        static let payloadLength = 20.0 // Assumed payload length in bytes
        static let headerOverhead = 28.0
        static let crcOverhead = 16.0

        // Sensitivity Constants
        static let sensitivityBase = -148.0
        static let sensitivitySlope = 2.5
        static let bwReference = 125.0
        static let bwSlope = 3.0

        // Path Loss Constants
        static let fadeMargin = 20.0
        static let pathLossExponent = 3.5
        static let referenceDistance = 1.0
        static let referenceLoss = 50.0
    }

    /// Calculate Time on Air (latency in ms) and Range (in meters) based on LoRa parameters
    static func calculatePerformance(sf: Int, bw: Int, cr: Int, txPower: Int) -> (latency: Int, range: Int) {
        // Time on Air calculation (bw is in kHz, convert to Hz)
        let bwHz = Double(bw) * 1000.0
        let symbolDuration = Double(1 << sf) / bwHz * 1000.0
        let preambleTime = (Constants.preambleSymbols + Constants.syncWordSymbols) * symbolDuration

        // Payload symbol calculation:
        // (8 * payload + 28 + 16 - 4 * SF) / (4 * SF)
        // Simplified from LoRa datasheet formula
        let payloadBits = 8.0 * Constants.payloadLength
        let overhead = Constants.headerOverhead + Constants.crcOverhead
        let dividend = payloadBits - 4.0 * Double(sf) + overhead
        let divisor = 4.0 * Double(sf)

        let payloadSymbols = 8.0 + max(
            ceil(dividend / divisor) * Double(cr),
            0.0
        )
        let payloadTime = payloadSymbols * symbolDuration

        let timeOnAir = Int(preambleTime + payloadTime)

        // Range calculation (indoor path loss model matching WebUI)
        // SX1262 sensitivity: -148 dBm @ SF12/BW125, improves ~2.5dB per SF step down
        let sensitivity = Constants.sensitivityBase + Double(12 - sf) * Constants.sensitivitySlope +
            (bw > Int(Constants.bwReference) ? log2(Double(bw) / Constants.bwReference) * Constants.bwSlope : 0.0)
        let linkBudget = Double(txPower) - sensitivity

        // Indoor path loss model with heavy attenuation
        // Solve for distance: d = d0 * 10^((linkBudget - fadeMargin - PL0) / (10*n))
        let range = Int(Constants.referenceDistance * pow(
            10.0,
            (linkBudget - Constants.fadeMargin - Constants.referenceLoss) / (10.0 * Constants.pathLossExponent)
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
