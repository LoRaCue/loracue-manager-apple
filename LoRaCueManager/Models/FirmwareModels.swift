import Foundation

// MARK: - GitHub Release Models

struct GitHubRelease: Codable, Identifiable {
    let id: Int
    let tagName: String
    let name: String
    let prerelease: Bool
    let createdAt: Date
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case id, name, prerelease, assets
        case tagName = "tag_name"
        case createdAt = "created_at"
    }
}

struct GitHubAsset: Codable, Identifiable {
    let id: Int
    let name: String
    let browserDownloadUrl: String
    let size: Int

    enum CodingKeys: String, CodingKey {
        case id, name, size
        case browserDownloadUrl = "browser_download_url"
    }
}

// MARK: - Firmware Manifest Models

/// Defines the structure of the firmware update manifest (manifest.json).
///
/// This manifest describes the contents of a firmware release package, including
/// hardware compatibility, versioning, and the layout of binary files for flashing.
struct FirmwareManifest: Codable {
    /// The device model identifier (e.g., "loracue-v2").
    let model: String
    /// The unique hardware board identifier.
    let boardId: String
    /// The human-readable name of the board.
    let boardName: String
    /// The semantic version string of the firmware.
    let version: String
    /// The date the firmware was built.
    let buildDate: String
    /// The git commit hash of the source code.
    let commit: String
    /// The target platform/chipset (e.g., "esp32s3").
    let target: String
    /// The required flash memory size (e.g., "4MB").
    let flashSize: String
    /// Information about the main application firmware binary.
    let firmware: BinaryInfo
    /// Information about the bootloader binary.
    let bootloader: BinaryInfo
    /// Information about the partition table binary.
    let partitionTable: BinaryInfo
    /// Optional information about the Web UI resources binary.
    let webui: BinaryInfo?
    /// Arguments passed to esptool during flashing (e.g., baud rate, flash mode).
    /// These configure the SPI flash interface parameters.
    let esptoolArgs: [String]
    /// The URL where the full package can be downloaded (optional).
    let downloadUrl: String?

    enum CodingKeys: String, CodingKey {
        case model, version, commit, target, firmware, bootloader, webui
        case boardId = "board_id"
        case boardName = "board_name"
        case buildDate = "build_date"
        case flashSize = "flash_size"
        case partitionTable = "partition_table"
        case esptoolArgs = "esptool_args"
        case downloadUrl = "download_url"
    }
}

/// Information about a binary file within the firmware package.
struct BinaryInfo: Codable {
    /// The filename of the binary.
    let file: String
    /// The size of the file in bytes.
    let size: Int
    /// The SHA-256 hash of the file for verification.
    let sha256: String
    /// The flash memory offset address where this binary should be written (e.g., "0x1000").
    /// This is typically provided as a hex string.
    let offset: String
}

// MARK: - Firmware Package

struct FirmwarePackage {
    let manifest: FirmwareManifest
    let firmwareData: Data
    let bootloaderData: Data
    let partitionTableData: Data
    let sourceUrl: URL
}

// MARK: - Verification Result

enum VerificationResult {
    case success
    case hashMismatch(expected: String, actual: String)
    case signatureInvalid
    case error(Error)

    var isValid: Bool {
        if case .success = self { return true }
        return false
    }
}

// MARK: - Firmware Source

enum FirmwareSource {
    case github(release: GitHubRelease, manifest: FirmwareManifest)
    case localZip(url: URL)
    case localBin(url: URL)
}

// MARK: - Upload Progress

struct UploadProgress {
    enum Stage {
        case downloading
        case verifying
        case uploading
        case complete
    }

    let stage: Stage
    let progress: Double
    let message: String
}
