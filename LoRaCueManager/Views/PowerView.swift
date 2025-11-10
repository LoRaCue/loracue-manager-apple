import SwiftUI

struct PowerView: View {
    @ObservedObject var viewModel: PowerViewModel

    var body: some View {
        List {
            if let config = viewModel.config {
                Section("Display Sleep") {
                    Toggle("Enabled", isOn: Binding(
                        get: { config.displaySleepEnabled },
                        set: { self.viewModel.config?.displaySleepEnabled = $0 }
                    ))

                    LabeledContent("Timeout: \(LoRaCalculator.formatTimeout(config.displaySleepTimeoutMs))") {
                        Slider(value: Binding(
                            get: { Double(config.displaySleepTimeoutMs) },
                            set: { self.viewModel.config?.displaySleepTimeoutMs = Int($0) }
                        ), in: 1000 ... 300_000, step: 1000)
                            .frame(width: 200)
                        #if os(macOS)
                            .controlSize(.large)
                        #endif
                    }
                }

                Section("Light Sleep") {
                    Toggle("Enabled", isOn: Binding(
                        get: { config.lightSleepEnabled },
                        set: { self.viewModel.config?.lightSleepEnabled = $0 }
                    ))

                    LabeledContent("Timeout: \(LoRaCalculator.formatTimeout(config.lightSleepTimeoutMs))") {
                        Slider(value: Binding(
                            get: { Double(config.lightSleepTimeoutMs) },
                            set: { self.viewModel.config?.lightSleepTimeoutMs = Int($0) }
                        ), in: 1000 ... 300_000, step: 1000)
                            .frame(width: 200)
                        #if os(macOS)
                            .controlSize(.large)
                        #endif
                    }
                }

                Section("Deep Sleep") {
                    Toggle("Enabled", isOn: Binding(
                        get: { config.deepSleepEnabled },
                        set: { self.viewModel.config?.deepSleepEnabled = $0 }
                    ))

                    LabeledContent("Timeout: \(LoRaCalculator.formatTimeout(config.deepSleepTimeoutMs))") {
                        Slider(value: Binding(
                            get: { Double(config.deepSleepTimeoutMs) },
                            set: { self.viewModel.config?.deepSleepTimeoutMs = Int($0) }
                        ), in: 1000 ... 600_000, step: 1000)
                            .frame(width: 200)
                        #if os(macOS)
                            .controlSize(.large)
                        #endif
                    }
                }
            } else {
                ProgressView()
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Power Management")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Save") {
                    Task { await self.viewModel.save() }
                }
                .disabled(self.viewModel.isLoading)
                .frame(minWidth: 60)
            }
        }
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
}
