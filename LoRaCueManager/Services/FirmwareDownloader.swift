import Foundation
import OSLog
import ZIPFoundation

class FirmwareDownloader {
    private let verifier = FirmwareVerifier()
    private let fileManager = FileManager.default

    // MARK: - Extract and Validate ZIP

    func extractAndValidate(zipUrl: URL) async throws -> FirmwarePackage {
        Logger.firmware.info("📦 Extracting ZIP from: \(zipUrl.path)")
        let tempDir = self.fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try self.fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        // Extract ZIP
        try self.fileManager.unzipItem(at: zipUrl, to: tempDir)
        Logger.firmware.info("✅ Extracted to: \(tempDir.path)")

        // List contents
        if let contents = try? fileManager.contentsOfDirectory(atPath: tempDir.path) {
            Logger.firmware.info("📂 ZIP contents (\(contents.count) items):")
            for item in contents {
                Logger.firmware.info("  - \(item)")
            }
        }

        // Handle nested directory
        let baseDir = try resolveBaseDirectory(tempDir)

        // Parse and validate manifest
        let manifest = try parseManifest(from: baseDir)

        // Verify and load binaries
        let binaries = try verifyBinaries(
            manifest: manifest,
            baseDir: baseDir
        )

        return FirmwarePackage(
            manifest: manifest,
            firmwareData: binaries.firmware,
            bootloaderData: binaries.bootloader,
            partitionTableData: binaries.partitionTable,
            sourceUrl: zipUrl
        )
    }

    private func resolveBaseDirectory(_ tempDir: URL) throws -> URL {
        var baseDir = tempDir
        if let contents = try? fileManager.contentsOfDirectory(atPath: tempDir.path),
           contents.count == 1,
           let firstItem = contents.first
        {
            let potentialDir = tempDir.appendingPathComponent(firstItem)
            var isDirectory: ObjCBool = false
            if self.fileManager.fileExists(atPath: potentialDir.path, isDirectory: &isDirectory),
               isDirectory.boolValue
            {
                baseDir = potentialDir
                Logger.firmware.info("📁 Using nested directory: \(firstItem)")
            }
        }
        return baseDir
    }

    private func parseManifest(from baseDir: URL) throws -> FirmwareManifest {
        let manifestUrl = baseDir.appendingPathComponent("manifest.json")
        guard self.fileManager.fileExists(atPath: manifestUrl.path) else {
            Logger.firmware.error("❌ manifest.json not found at: \(manifestUrl.path)")
            throw DownloadError.manifestNotFound
        }

        Logger.firmware.info("✅ Found manifest.json")
        let manifestData = try Data(contentsOf: manifestUrl)
        Logger.firmware.info("📦 Manifest size: \(manifestData.count) bytes")

        if let jsonString = String(data: manifestData, encoding: .utf8) {
            Logger.firmware.info("📄 Manifest preview: \(jsonString.prefix(300))...")
        }

        let decoder = JSONDecoder()
        let manifest: FirmwareManifest
        do {
            manifest = try decoder.decode(FirmwareManifest.self, from: manifestData)
            Logger.firmware.info("✅ Decoded manifest for: \(manifest.model) \(manifest.version)")
        } catch {
            Logger.firmware.error("❌ Manifest decode error: \(error)")
            throw error
        }

        // Verify signature
        try self.verifyManifestSignature(baseDir: baseDir, manifestData: manifestData)

        return manifest
    }

    private func verifyManifestSignature(baseDir: URL, manifestData: Data) throws {
        Logger.firmware.info("🔐 Verifying manifest signature...")
        let manifestUrl = baseDir.appendingPathComponent("manifest.json")
        let signatureUrl = baseDir.appendingPathComponent("manifest.json.sig")

        guard self.fileManager.fileExists(atPath: signatureUrl.path) else {
            Logger.firmware.error("❌ manifest.json.sig not found")
            throw DownloadError.signatureVerificationFailed
        }

        let result = self.verifier.verifyJSONSignature(fileUrl: manifestUrl, signatureUrl: signatureUrl)
        guard result.isValid else {
            Logger.firmware.error("❌ Manifest signature verification failed")
            throw DownloadError.signatureVerificationFailed
        }
        Logger.firmware.info("✅ Manifest signature verified")
    }

    private struct BinaryData {
        let firmware: Data
        let bootloader: Data
        let partitionTable: Data
    }

    private func verifyBinaries(manifest: FirmwareManifest, baseDir: URL) throws -> BinaryData {
        let binaries = [
            (manifest.firmware.file, manifest.firmware.sha256),
            (manifest.bootloader.file, manifest.bootloader.sha256),
            (manifest.partitionTable.file, manifest.partitionTable.sha256)
        ]

        var loadedData: [Data] = []

        for (file, expectedHash) in binaries {
            // Verify SHA256 and load data
            let data = try loadAndVerify(file: file, expectedHash: expectedHash, from: baseDir)
            loadedData.append(data)

            // Verify signature
            Logger.firmware.info("🔐 Verifying \(file) signature...")
            let fileUrl = baseDir.appendingPathComponent(file)
            let sigUrl = baseDir.appendingPathComponent(file + ".sig")

            guard self.fileManager.fileExists(atPath: sigUrl.path) else {
                Logger.firmware.error("❌ Signature not found: \(file).sig")
                throw DownloadError.signatureVerificationFailed
            }

            let result = self.verifier.verifyBinarySignature(fileUrl: fileUrl, signatureUrl: sigUrl)
            guard result.isValid else {
                Logger.firmware.error("❌ Signature verification failed: \(file)")
                throw DownloadError.signatureVerificationFailed
            }
            Logger.firmware.info("✅ \(file) signature verified")
        }

        // Verify webui if present
        if let webui = manifest.webui {
            _ = try self.loadAndVerify(file: webui.file, expectedHash: webui.sha256, from: baseDir)

            Logger.firmware.info("🔐 Verifying \(webui.file) signature...")
            let webuiUrl = baseDir.appendingPathComponent(webui.file)
            let webuiSigUrl = baseDir.appendingPathComponent(webui.file + ".sig")

            if self.fileManager.fileExists(atPath: webuiSigUrl.path) {
                let result = self.verifier.verifyBinarySignature(fileUrl: webuiUrl, signatureUrl: webuiSigUrl)
                guard result.isValid else {
                    Logger.firmware.error("❌ WebUI signature verification failed")
                    throw DownloadError.signatureVerificationFailed
                }
                Logger.firmware.info("✅ WebUI signature verified")
            }
        }

        return BinaryData(
            firmware: loadedData[0],
            bootloader: loadedData[1],
            partitionTable: loadedData[2]
        )
    }

    // MARK: - Validate Raw Binary

    func validateRawBinary(url: URL) async throws -> Data {
        let data = try Data(contentsOf: url)

        // Basic sanity checks
        guard data.count > AppConstants.Firmware.minBinarySize else {
            throw DownloadError.invalidBinarySize
        }

        // Check for ESP32 magic bytes (0xE9 at offset 0)
        guard data.first == AppConstants.Firmware.esp32MagicByte else {
            throw DownloadError.invalidBinaryFormat
        }

        return data
    }

    // MARK: - Private Helpers

    private func loadAndVerify(file: String, expectedHash: String, from directory: URL) throws -> Data {
        let fileUrl = directory.appendingPathComponent(file)

        guard self.fileManager.fileExists(atPath: fileUrl.path) else {
            throw DownloadError.fileNotFound(file)
        }

        let data = try Data(contentsOf: fileUrl)
        let result = self.verifier.verifySHA256(data: data, expectedHash: expectedHash)

        guard result.isValid else {
            if case let .hashMismatch(expected, actual) = result {
                throw DownloadError.hashMismatch(file: file, expected: expected, actual: actual)
            }
            throw DownloadError.verificationFailed(file)
        }

        return data
    }
}

// MARK: - Errors

enum DownloadError: LocalizedError {
    case manifestNotFound
    case signatureNotFound
    case fileNotFound(String)
    case hashMismatch(file: String, expected: String, actual: String)
    case verificationFailed(String)
    case signatureVerificationFailed
    case invalidBinarySize
    case invalidBinaryFormat

    var errorDescription: String? {
        switch self {
        case .manifestNotFound:
            "manifest.json not found in ZIP file"
        case .signatureNotFound:
            "manifest.json.sig not found in ZIP file"
        case let .fileNotFound(file):
            "File not found: \(file)"
        case let .hashMismatch(file, expected, actual):
            "Hash mismatch for \(file)\nExpected: \(expected)\nActual: \(actual)"
        case let .verificationFailed(file):
            "Verification failed for \(file)"
        case .signatureVerificationFailed:
            "Firmware signature verification failed"
        case .invalidBinarySize:
            "Binary file is too small to be valid firmware"
        case .invalidBinaryFormat:
            "Binary file does not appear to be valid ESP32 firmware"
        }
    }
}
