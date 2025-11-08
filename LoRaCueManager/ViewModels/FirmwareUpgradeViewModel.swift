import Foundation
import OSLog
import SwiftUI

@MainActor
class FirmwareUpgradeViewModel: ObservableObject {
    @Published var releases: [GitHubRelease] = []
    @Published var selectedRelease: GitHubRelease?
    @Published var manifests: [FirmwareManifest] = []
    @Published var selectedManifest: FirmwareManifest?
    @Published var includePrerelease = false

    @Published var uploadProgress: UploadProgress?
    @Published var isLoading = false
    @Published var error: String?

    @Published var selectedZipUrl: URL?
    @Published var selectedBinUrl: URL?

    private let githubService = GitHubReleaseService()
    private let downloader = FirmwareDownloader()
    private let otaService: BLEOTAService

    init(service: LoRaCueService) {
        self.otaService = BLEOTAService(bleManager: service.bleManager)
    }

    // MARK: - GitHub Release Flow

    func loadReleases() async {
        self.isLoading = true
        self.error = nil

        do {
            Logger.firmware.info("📦 Loading releases (includePrerelease: \(self.includePrerelease))")
            self.releases = try await self.githubService.fetchReleases(includePrerelease: self.includePrerelease)
            Logger.firmware.info("✅ Loaded \(self.releases.count) releases")

            if self.releases.isEmpty, !self.includePrerelease {
                Logger.firmware.info("💡 No releases found, enabling pre-releases")
                self.includePrerelease = true
                await self.loadReleases()
            }
        } catch {
            Logger.firmware.error("❌ Failed to load releases: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }

        self.isLoading = false
    }

    func selectRelease(_ release: GitHubRelease) async {
        self.selectedRelease = release
        self.isLoading = true
        self.error = nil

        do {
            Logger.firmware.info("📦 Fetching manifests for release: \(release.tagName)")
            let allManifests = try await githubService.fetchManifests(for: release)
            Logger.firmware.info("✅ Found \(allManifests.count) manifests")
            // Filter by current device model/board if available
            self.manifests = allManifests
        } catch {
            Logger.firmware.error("❌ Failed to fetch manifests: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }

        self.isLoading = false
    }

    func upgradeFromGitHub() async {
        guard let manifest = selectedManifest,
              let downloadUrl = manifest.downloadUrl else { return }

        do {
            Logger.firmware.info("🚀 Starting GitHub firmware upgrade")
            Logger.firmware.info("📥 Download URL: \(downloadUrl)")

            // Download
            self.uploadProgress = UploadProgress(stage: .downloading, progress: 0, message: "Downloading firmware...")

            let zipUrl = try await githubService.downloadFirmware(from: URL(string: downloadUrl)!) { progress in
                Task { @MainActor in
                    self.uploadProgress = UploadProgress(
                        stage: .downloading,
                        progress: progress,
                        message: "Downloading firmware..."
                    )
                }
            }
            Logger.firmware.info("✅ Downloaded to: \(zipUrl.path)")

            // Verify
            self.uploadProgress = UploadProgress(stage: .verifying, progress: 0, message: "Verifying firmware...")
            Logger.firmware.info("🔍 Extracting and validating ZIP...")
            let package = try await downloader.extractAndValidate(zipUrl: zipUrl)
            Logger.firmware.info("✅ Validated firmware package: \(package.firmwareData.count) bytes")

            // Upload
            self.uploadProgress = UploadProgress(stage: .uploading, progress: 0, message: "Uploading to device...")
            Logger.firmware.info("📤 Uploading to device...")
            try await self.otaService.uploadFirmware(data: package.firmwareData) { progress in
                Task { @MainActor in
                    self.uploadProgress = UploadProgress(
                        stage: .uploading,
                        progress: progress,
                        message: "Uploading to device..."
                    )
                }
            }

            self.uploadProgress = UploadProgress(stage: .complete, progress: 1.0, message: "Upgrade complete!")
            Logger.firmware.info("✅ Firmware upgrade complete!")

        } catch {
            Logger.firmware.error("❌ Firmware upgrade failed: \(error.localizedDescription)")
            self.error = error.localizedDescription
            self.uploadProgress = nil
        }
    }

    // MARK: - ZIP File Flow

    func upgradeFromZip() async {
        guard let zipUrl = selectedZipUrl else { return }

        do {
            Logger.firmware.info("🚀 Starting ZIP firmware upgrade from: \(zipUrl.path)")
            self.uploadProgress = UploadProgress(stage: .verifying, progress: 0, message: "Extracting and verifying...")
            let package = try await downloader.extractAndValidate(zipUrl: zipUrl)
            Logger.firmware.info("✅ Validated firmware package: \(package.firmwareData.count) bytes")

            self.uploadProgress = UploadProgress(stage: .uploading, progress: 0, message: "Uploading to device...")
            try await self.otaService.uploadFirmware(data: package.firmwareData) { progress in
                Task { @MainActor in
                    self.uploadProgress = UploadProgress(
                        stage: .uploading,
                        progress: progress,
                        message: "Uploading to device..."
                    )
                }
            }

            self.uploadProgress = UploadProgress(stage: .complete, progress: 1.0, message: "Upgrade complete!")

        } catch {
            self.error = error.localizedDescription
            self.uploadProgress = nil
        }
    }

    // MARK: - BIN File Flow

    func upgradeFromBin() async {
        guard let binUrl = selectedBinUrl else { return }

        do {
            self.uploadProgress = UploadProgress(stage: .verifying, progress: 0, message: "Validating binary...")
            let data = try await downloader.validateRawBinary(url: binUrl)

            self.uploadProgress = UploadProgress(stage: .uploading, progress: 0, message: "Uploading to device...")
            try await self.otaService.uploadFirmware(data: data) { progress in
                Task { @MainActor in
                    self.uploadProgress = UploadProgress(
                        stage: .uploading,
                        progress: progress,
                        message: "Uploading to device..."
                    )
                }
            }

            self.uploadProgress = UploadProgress(stage: .complete, progress: 1.0, message: "Upgrade complete!")

        } catch {
            self.error = error.localizedDescription
            self.uploadProgress = nil
        }
    }

    // MARK: - Helpers

    func reset() {
        self.uploadProgress = nil
        self.error = nil
    }
}
