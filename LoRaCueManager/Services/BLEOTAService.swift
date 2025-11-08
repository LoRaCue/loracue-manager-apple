import CoreBluetooth
import Foundation

class BLEOTAService {
    private let bleManager: BLEManager
    private let chunkSize = 512

    init(bleManager: BLEManager) {
        self.bleManager = bleManager
    }

    // MARK: - Upload Firmware

    func uploadFirmware(data: Data, progress: @escaping (Double) -> Void) async throws {
        guard self.bleManager.isConnected else {
            throw OTAError.notConnected
        }

        let totalChunks = (data.count + self.chunkSize - 1) / self.chunkSize
        var sentChunks = 0

        // Send firmware size
        try await sendCommand(.beginTransfer(size: data.count))

        // Send chunks
        for offset in stride(from: 0, to: data.count, by: self.chunkSize) {
            let end = min(offset + self.chunkSize, data.count)
            let chunk = data[offset ..< end]

            try await self.sendChunk(chunk, offset: offset)

            sentChunks += 1
            let progressValue = Double(sentChunks) / Double(totalChunks)
            progress(progressValue)
        }

        // Finalize transfer
        try await self.sendCommand(.endTransfer)

        // Wait for device to apply update
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
    }

    // MARK: - Private Helpers

    private func sendCommand(_ command: OTACommand) async throws {
        let data = try encodeCommand(command)
        let hexString = data.map { String(format: "%02x", $0) }.joined()
        _ = try await self.bleManager.sendCommand("OTA \(hexString)\n")
    }

    private func sendChunk(_ chunk: Data, offset: Int) async throws {
        var packet = Data()
        packet.append(contentsOf: withUnsafeBytes(of: UInt32(offset).littleEndian) { Data($0) })
        packet.append(contentsOf: withUnsafeBytes(of: UInt16(chunk.count).littleEndian) { Data($0) })
        packet.append(chunk)

        let hexString = packet.map { String(format: "%02x", $0) }.joined()
        _ = try await self.bleManager.sendCommand("OTA_DATA \(hexString)\n")

        // Wait for ACK
        let response = try await bleManager.receiveData(timeout: 2.0)
        guard self.isAckResponse(response) else {
            throw OTAError.chunkFailed(offset: offset)
        }
    }

    private func encodeCommand(_ command: OTACommand) throws -> Data {
        var data = Data()

        switch command {
        case let .beginTransfer(size):
            data.append(0x01) // Command ID
            data.append(contentsOf: withUnsafeBytes(of: UInt32(size).littleEndian) { Data($0) })

        case .endTransfer:
            data.append(0x02) // Command ID
        }

        return data
    }

    private func isAckResponse(_ data: Data) -> Bool {
        data.first == 0x06 // ACK byte
    }
}

// MARK: - OTA Command

private enum OTACommand {
    case beginTransfer(size: Int)
    case endTransfer
}

// MARK: - Errors

enum OTAError: LocalizedError {
    case notConnected
    case commandFailed
    case chunkFailed(offset: Int)
    case timeout

    var errorDescription: String? {
        switch self {
        case .notConnected:
            "Device not connected"
        case .commandFailed:
            "OTA command failed"
        case let .chunkFailed(offset):
            "Failed to send chunk at offset \(offset)"
        case .timeout:
            "OTA operation timed out"
        }
    }
}

// MARK: - BLEManager Extension

extension BLEManager {
    func receiveData(timeout: TimeInterval) async throws -> Data {
        // Placeholder - implement based on actual BLE protocol
        try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
        return Data([0x06]) // Mock ACK
    }
}
