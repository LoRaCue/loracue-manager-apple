import Foundation
import OSLog

class GitHubReleaseService {
    private let repoOwner = AppConstants.GitHub.repoOwner
    private let repoName = AppConstants.GitHub.repoName
    private let baseURL = AppConstants.GitHub.baseURL

    // MARK: - Fetch Releases

    func fetchReleases(includePrerelease: Bool = false) async throws -> [GitHubRelease] {
        let url = URL(string: "\(baseURL)/repos/\(repoOwner)/\(repoName)/releases")!

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode)
        else {
            throw GitHubError.requestFailed
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let releases = try decoder.decode([GitHubRelease].self, from: data)

        return includePrerelease ? releases : releases.filter { !$0.prerelease }
    }

    // MARK: - Fetch Manifests

    func fetchManifests(for release: GitHubRelease) async throws -> [FirmwareManifest] {
        Logger.firmware.info("🔍 Looking for manifests.json in \(release.assets.count) assets")

        guard let manifestAsset = release.assets.first(where: { $0.name == "manifests.json" }) else {
            Logger.firmware.error("❌ manifests.json not found in release assets")
            throw GitHubError.manifestNotFound
        }

        guard let signatureAsset = release.assets.first(where: { $0.name == "manifests.json.sig" }) else {
            Logger.firmware.error("❌ manifests.json.sig not found in release assets")
            throw GitHubError.signatureNotFound
        }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manifestUrl = tempDir.appendingPathComponent("manifests.json")
        let signatureUrl = tempDir.appendingPathComponent("manifests.json.sig")

        Logger.firmware.info("📥 Downloading manifests.json...")
        let (data, _) = try await URLSession.shared.data(from: URL(string: manifestAsset.browserDownloadUrl)!)
        try data.write(to: manifestUrl)

        Logger.firmware.info("📥 Downloading manifests.json.sig...")
        let (sigData, _) = try await URLSession.shared.data(from: URL(string: signatureAsset.browserDownloadUrl)!)
        try sigData.write(to: signatureUrl)

        Logger.firmware.info("🔐 Verifying manifests.json signature...")
        let verifier = FirmwareVerifier()
        let result = verifier.verifyJSONSignature(fileUrl: manifestUrl, signatureUrl: signatureUrl)
        guard result.isValid else {
            Logger.firmware.error("❌ manifests.json signature verification failed")
            throw GitHubError.signatureVerificationFailed
        }
        Logger.firmware.info("✅ manifests.json signature verified")

        let decoder = JSONDecoder()
        let manifests = try decoder.decode([FirmwareManifest].self, from: data)
        Logger.firmware.info("✅ Decoded \(manifests.count) manifests")
        return manifests
    }

    // MARK: - Filter Manifests

    func filterManifests(_ manifests: [FirmwareManifest], model: String, boardId: String) -> [FirmwareManifest] {
        manifests.filter { manifest in
            manifest.model.lowercased() == model.lowercased() &&
                manifest.boardId.lowercased() == boardId.lowercased()
        }
    }

    // MARK: - Download Firmware

    func downloadFirmware(from url: URL, progress: @escaping (Double) -> Void) async throws -> URL {
        Logger.firmware.info("📥 Starting download from: \(url.absoluteString)")

        do {
            let (tempURL, response) = try await URLSession.shared.download(
                from: url,
                delegate: DownloadDelegate(progress: progress)
            )

            guard let httpResponse = response as? HTTPURLResponse else {
                Logger.firmware.error("❌ Invalid response type")
                throw GitHubError.downloadFailed
            }

            Logger.firmware.info("📡 Download HTTP Status: \(httpResponse.statusCode)")

            guard (200 ... 299).contains(httpResponse.statusCode) else {
                Logger.firmware.error("❌ Download failed with status: \(httpResponse.statusCode)")
                throw GitHubError.downloadFailed
            }

            Logger.firmware.info("✅ Downloaded to: \(tempURL.path)")
            return tempURL
        } catch {
            Logger.firmware.error("❌ Download error: \(error)")
            throw GitHubError.downloadFailed
        }
    }
}

// MARK: - Download Delegate

private class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let progress: (Double) -> Void

    init(progress: @escaping (Double) -> Void) {
        self.progress = progress
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let progressValue = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            self.progress(progressValue)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Handled by async/await
    }
}

// MARK: - Errors

enum GitHubError: LocalizedError {
    case requestFailed
    case manifestNotFound
    case signatureNotFound
    case signatureVerificationFailed
    case downloadFailed
    case noCompatibleFirmware

    var errorDescription: String? {
        switch self {
        case .requestFailed:
            "Failed to fetch releases from GitHub"
        case .manifestNotFound:
            "No manifests.json found in release"
        case .signatureNotFound:
            "No manifests.json.sig found in release"
        case .signatureVerificationFailed:
            "manifests.json signature verification failed"
        case .downloadFailed:
            "Failed to download firmware"
        case .noCompatibleFirmware:
            "No compatible firmware found for your device"
        }
    }
}
