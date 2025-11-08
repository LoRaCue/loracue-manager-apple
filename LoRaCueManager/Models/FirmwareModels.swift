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

struct FirmwareManifest: Codable {
    let model: String
    let boardId: String
    let boardName: String
    let version: String
    let buildDate: String
    let commit: String
    let target: String
    let flashSize: String
    let firmware: BinaryInfo
    let bootloader: BinaryInfo
    let partitionTable: BinaryInfo
    let webui: BinaryInfo?
    let esptoolArgs: [String]
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

struct BinaryInfo: Codable {
    let file: String
    let size: Int
    let sha256: String
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
