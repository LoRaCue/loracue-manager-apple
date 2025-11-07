import SwiftUI

struct SystemView: View {
    @StateObject private var viewModel: SystemViewModel

    init(service: LoRaCueService) {
        _viewModel = StateObject(wrappedValue: SystemViewModel(service: service))
    }

    var body: some View {
        Form {
            if let info = viewModel.deviceInfo {
                Section("Device Information") {
                    InfoRow(label: "Model", value: info.model)
                    InfoRow(label: "Board ID", value: info.boardId)
                    InfoRow(label: "Version", value: info.version)
                    InfoRow(label: "Commit", value: info.commit)
                    InfoRow(label: "Branch", value: info.branch)
                    InfoRow(label: "Build Date", value: info.buildDate)
                }

                Section("Hardware") {
                    InfoRow(label: "Chip", value: info.chipModel)
                    InfoRow(label: "Chip Revision", value: "\(info.chipRevision)")
                    InfoRow(label: "CPU Cores", value: "\(info.cpuCores)")
                    InfoRow(label: "Flash Size", value: "\(info.flashSizeMb) MB")
                    InfoRow(label: "MAC Address", value: info.mac)
                }

                Section("Runtime") {
                    InfoRow(label: "Uptime", value: self.formatUptime(info.uptimeSec))
                    InfoRow(label: "Free Heap", value: "\(info.freeHeapKb) KB")
                    InfoRow(label: "Partition", value: info.partition)
                }
            } else {
                ProgressView()
            }
        }
        .formStyle(.grouped)
        #if os(macOS)
        .padding(32)
        #endif
        .navigationTitle("System")
        .task {
            while !self.viewModel.service.isReady {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            await self.viewModel.load()
        }
        .alert("Error", isPresented: .constant(self.viewModel.error != nil)) {
            Button("OK") { self.viewModel.error = nil }
        } message: {
            Text(self.viewModel.error ?? "")
        }
    }

    private func formatUptime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(self.label)
            Spacer()
            Text(self.value)
                .foregroundColor(.secondary)
        }
    }
}
