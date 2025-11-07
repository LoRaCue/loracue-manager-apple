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
        VStack(spacing: 0) {
            // Tab Picker
            Picker("Source", selection: self.$selectedTab) {
                Text("Releases").tag(0)
                Text("Zip Archive").tag(1)
                Text("Binary File").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            // Content
            TabView(selection: self.$selectedTab) {
                self.githubTab.tag(0)
                self.zipTab.tag(1)
                self.binTab.tag(2)
            }
            .tabViewStyle(.automatic)

            // Progress Section
            if let progress = viewModel.uploadProgress {
                self.progressSection(progress)
            }
        }
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
                "Installing raw .bin files bypasses all security checks and could brick your device. Only proceed if you know what you're doing."
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
        #if os(macOS)
        .padding(32)
        #endif
    }

    // MARK: - GitHub Tab

    private var githubTab: some View {
        Form {
            Section {
                Toggle("Include Pre-releases", isOn: self.$viewModel.includePrerelease)
                    .onChange(of: self.viewModel.includePrerelease) {
                        Task { await self.viewModel.loadReleases() }
                    }
            }

            Section("Available Releases") {
                if self.viewModel.isLoading {
                    ProgressView()
                } else if self.viewModel.releases.isEmpty {
                    Text("No releases found")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(self.viewModel.releases) { release in
                        Button {
                            Task { await self.viewModel.selectRelease(release) }
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(release.name)
                                        .font(.headline)
                                    Text(release.tagName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if release.prerelease {
                                    Text("PRE")
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
            }

            if !self.viewModel.manifests.isEmpty {
                Section("Select Firmware") {
                    ForEach(self.viewModel.manifests, id: \.model) { manifest in
                        Button {
                            self.viewModel.selectedManifest = manifest
                            self.pendingUpgradeAction = {
                                Task { await self.viewModel.upgradeFromGitHub() }
                            }
                            self.showUpgradeConfirmation = true
                        } label: {
                            VStack(alignment: .leading) {
                                Text(manifest.model)
                                    .font(.headline)
                                Text("\(manifest.boardName) • \(manifest.version)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - ZIP Tab

    private var zipTab: some View {
        Form {
            Section("Firmware File") {
                if let url = viewModel.selectedZipUrl {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(url.lastPathComponent)
                                .font(.headline)
                            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                                Text("\(size / 1024) KB")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Button("Change") {
                            self.showZipPicker = true
                        }
                    }
                } else {
                    Button("Select ZIP file...") {
                        self.showZipPicker = true
                    }
                }
            }

            Section {
                Button("Start Upgrade") {
                    self.pendingUpgradeAction = {
                        Task { await self.viewModel.upgradeFromZip() }
                    }
                    self.showUpgradeConfirmation = true
                }
                .disabled(self.viewModel.selectedZipUrl == nil)
            }

            Section {
                Text("ZIP files must contain manifest.json with firmware metadata and signature.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .fileImporter(
            isPresented: self.$showZipPicker,
            allowedContentTypes: [UTType(filenameExtension: "zip")!]
        ) { result in
            if case let .success(url) = result {
                self.viewModel.selectedZipUrl = url
            }
        }
    }

    // MARK: - BIN Tab

    private var binTab: some View {
        Form {
            Section {
                Label {
                    Text("Advanced Users Only")
                        .font(.headline)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                }

                Text(
                    "Raw .bin files bypass all security checks. This could brick your device if the firmware is incompatible or corrupted."
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Section("Firmware File") {
                if let url = viewModel.selectedBinUrl {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(url.lastPathComponent)
                                .font(.headline)
                            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                                Text("\(size / 1024) KB")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Button("Change") {
                            self.showBinPicker = true
                        }
                    }
                } else {
                    Button("Select binary file...") {
                        self.showBinPicker = true
                    }
                }
            }

            Section {
                Button("Start Upgrade") {
                    self.pendingUpgradeAction = {
                        Task { await self.viewModel.upgradeFromBin() }
                    }
                    self.showBinWarning = true
                }
                .disabled(self.viewModel.selectedBinUrl == nil)
            }
        }
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

    private func progressSection(_ progress: UploadProgress) -> some View {
        VStack(spacing: 12) {
            Divider()

            HStack {
                self.stageIcon(progress.stage)
                Text(progress.message)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)

            ProgressView(value: progress.progress)
                .padding(.horizontal)

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
            .padding(.horizontal)
            .padding(.bottom)
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
