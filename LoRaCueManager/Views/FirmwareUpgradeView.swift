import SwiftUI
import UniformTypeIdentifiers

struct FirmwareUpgradeView: View {
    @StateObject private var viewModel: FirmwareUpgradeViewModel
    @State private var selectedTab = 0
    @State private var showZipPicker = false
    @State private var showBinPicker = false
    @State private var showBinWarning = false
    @State private var showUpgradeConfirmation = false
    @State private var pendingUpgradeAction: (() -> Void)?
    @State private var showError = false

    init(service: LoRaCueService) {
        _viewModel = StateObject(wrappedValue: FirmwareUpgradeViewModel(service: service))
    }

    var body: some View {
        Form {
            Section {
                #if os(iOS)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FirmwareSourceCard(
                            icon: "arrow.down.circle.fill",
                            title: "Release",
                            subtitle: "GitHub release",
                            tag: 0,
                            selectedTab: self.$selectedTab
                        )

                        FirmwareSourceCard(
                            icon: "archivebox.fill",
                            title: "ZIP",
                            subtitle: "Firmware archive file",
                            tag: 1,
                            selectedTab: self.$selectedTab
                        )

                        FirmwareSourceCard(
                            icon: "doc.fill",
                            title: "BIN",
                            subtitle: "Firmware binary file",
                            tag: 2,
                            selectedTab: self.$selectedTab
                        )
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                }
                .frame(height: 80)
                #else
                HStack(spacing: 12) {
                    FirmwareSourceCard(
                        icon: "arrow.down.circle.fill",
                        title: "Release",
                        subtitle: "GitHub release",
                        tag: 0,
                        selectedTab: self.$selectedTab
                    )

                    FirmwareSourceCard(
                        icon: "archivebox.fill",
                        title: "ZIP",
                        subtitle: "Firmware archive file",
                        tag: 1,
                        selectedTab: self.$selectedTab
                    )

                    FirmwareSourceCard(
                        icon: "doc.fill",
                        title: "BIN",
                        subtitle: "Firmware binary file",
                        tag: 2,
                        selectedTab: self.$selectedTab
                    )
                }
                .frame(height: 80)
                #endif

                if self.selectedTab == 0 {
                    Toggle("Include Pre-releases", isOn: self.$viewModel.includePrerelease)
                        .onChange(of: self.viewModel.includePrerelease) {
                            Task { await self.viewModel.loadReleases() }
                        }
                }
            }

            switch self.selectedTab {
            case 0:
                self.githubSections
            case 1:
                self.zipSections
            case 2:
                self.binSections
            default:
                EmptyView()
            }

            if let progress = viewModel.uploadProgress {
                self.progressSection(progress)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Firmware Upgrade")
        .task {
            if self.viewModel.releases.isEmpty {
                await self.viewModel.loadReleases()
            }
        }
        .alert("Error", isPresented: self.$showError) {
            Button("OK") {
                self.viewModel.error = nil
            }
        } message: {
            Text(self.viewModel.error ?? "An error occurred")
        }
        .onChange(of: self.viewModel.error) {
            self.showError = self.viewModel.error != nil
        }
        .alert("⚠️ Unsafe Operation", isPresented: self.$showBinWarning) {
            Button("Cancel", role: .cancel) {
                self.viewModel.selectedBinUrl = nil
            }
            Button("I Understand", role: .destructive) {
                self.showUpgradeConfirmation = true
            }
        } message: {
            Text(
                """
                Installing raw .bin files bypasses all security checks and could brick your device. \
                Only proceed if you know what you're doing.
                """
            )
        }
        .alert("Confirm Upgrade", isPresented: self.$showUpgradeConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Start Upgrade") {
                self.pendingUpgradeAction?()
            }
        } message: {
            Text("This will update your device firmware. The device will restart after the upgrade.")
        }
    }

    // MARK: - GitHub Sections

    @ViewBuilder
    private var githubSections: some View {
        GitHubSection(
            releases: self.viewModel.releases,
            manifests: self.viewModel.manifests,
            isLoading: self.viewModel.isLoading,
            onSelectRelease: { await self.viewModel.selectRelease($0) },
            onSelectManifest: { manifest in
                self.viewModel.selectedManifest = manifest
                self.pendingUpgradeAction = {
                    Task { await self.viewModel.upgradeFromGitHub() }
                }
                self.showUpgradeConfirmation = true
            }
        )
    }

    // MARK: - ZIP Sections

    @ViewBuilder
    private var zipSections: some View {
        ZIPSection(
            selectedURL: self.viewModel.selectedZipUrl,
            showPicker: self.$showZipPicker,
            onUpgrade: {
                self.pendingUpgradeAction = {
                    Task { await self.viewModel.upgradeFromZip() }
                }
                self.showUpgradeConfirmation = true
            }
        )
        .fileImporter(
            isPresented: self.$showZipPicker,
            allowedContentTypes: [UTType(filenameExtension: "zip")!]
        ) { result in
            if case let .success(url) = result {
                self.viewModel.selectedZipUrl = url
            }
        }
    }

    // MARK: - BIN Sections

    @ViewBuilder
    private var binSections: some View {
        BINSection(
            selectedURL: self.viewModel.selectedBinUrl,
            showPicker: self.$showBinPicker,
            onUpgrade: {
                self.pendingUpgradeAction = {
                    Task { await self.viewModel.upgradeFromBin() }
                }
                self.showBinWarning = true
            }
        )
        .fileImporter(
            isPresented: self.$showBinPicker,
            allowedContentTypes: [UTType(filenameExtension: "bin")!]
        ) { result in
            if case let .success(url) = result {
                self.viewModel.selectedBinUrl = url
            }
        }
    }

    // MARK: - Progress Section

    @ViewBuilder
    private func progressSection(_ progress: UploadProgress) -> some View {
        Section {
            HStack {
                self.stageIcon(progress.stage)
                Text(progress.message)
                    .font(.headline)
            }

            ProgressView(value: progress.progress)

            HStack {
                Text("\(Int(progress.progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if progress.stage == .complete {
                    Button("Done") {
                        self.viewModel.reset()
                    }
                }
            }
        }
    }

    private func stageIcon(_ stage: UploadProgress.Stage) -> some View {
        Group {
            switch stage {
            case .downloading:
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.blue)
            case .verifying:
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.green)
            case .uploading:
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(.orange)
            case .complete:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .font(.title2)
    }
}
