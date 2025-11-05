import SwiftUI
import UniformTypeIdentifiers

struct FirmwareUpgradeView: View {
    @StateObject private var viewModel: FirmwareViewModel
    @State private var showFilePicker = false

    init(service: LoRaCueService) {
        _viewModel = StateObject(wrappedValue: FirmwareViewModel(service: service))
    }

    var body: some View {
        Form {
            Section("Firmware File") {
                if let url = viewModel.selectedFile {
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
                            self.showFilePicker = true
                        }
                    }
                } else {
                    Button("Select Firmware File") {
                        self.showFilePicker = true
                    }
                }
            }

            if self.viewModel.isUploading {
                Section("Upload Progress") {
                    ProgressView(value: self.viewModel.uploadProgress)
                    Text("\(Int(self.viewModel.uploadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Button("Start Upgrade") {
                    Task { await self.viewModel.startUpgrade() }
                }
                .disabled(self.viewModel.selectedFile == nil || self.viewModel.isUploading)
            }
        }
        .navigationTitle("Firmware Upgrade")
        .fileImporter(
            isPresented: self.$showFilePicker,
            allowedContentTypes: [UTType(filenameExtension: "bin")!],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                self.viewModel.selectedFile = url
            }
        }
        .alert("Error", isPresented: .constant(self.viewModel.error != nil)) {
            Button("OK") { self.viewModel.error = nil }
        } message: {
            Text(self.viewModel.error ?? "")
        }
    }
}
