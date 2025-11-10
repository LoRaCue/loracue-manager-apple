import SwiftUI
import UniformTypeIdentifiers

struct BINSection: View {
    let selectedURL: URL?
    @Binding var showPicker: Bool
    let onUpgrade: () -> Void

    var body: some View {
        Section("Firmware File") {
            Label {
                Text("Advanced Users Only")
                    .font(.headline)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            }

            Text(
                """
                Raw .bin files bypass all security checks. This could brick your device if the \
                firmware is incompatible or corrupted.
                """
            )
            .font(.caption)
            .foregroundColor(.secondary)

            if let url = selectedURL {
                LabeledContent {
                    HStack {
                        Button("Change") {
                            self.showPicker = true
                        }

                        Button("Start Upgrade", role: .destructive, action: self.onUpgrade)
                    }
                } label: {
                    VStack(alignment: .leading) {
                        Text(url.lastPathComponent)
                            .font(.headline)
                        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                            Text("\(size / 1024) KB")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                Button("Select binary file...") {
                    self.showPicker = true
                }
            }
        }
    }
}
