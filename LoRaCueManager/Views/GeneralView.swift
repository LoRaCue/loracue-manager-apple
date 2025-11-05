import SwiftUI

struct GeneralView: View {
    @StateObject private var viewModel: GeneralViewModel

    init(service: LoRaCueService) {
        _viewModel = StateObject(wrappedValue: GeneralViewModel(service: service))
    }

    var body: some View {
        Form {
            if let config = viewModel.config {
                Section("Device Settings") {
                    TextField("Name", text: Binding(
                        get: { config.name },
                        set: { self.viewModel.config?.name = $0 }
                    ))

                    Picker("Mode", selection: Binding(
                        get: { config.mode },
                        set: { self.viewModel.config?.mode = $0 }
                    )) {
                        Text("Presenter").tag("PRESENTER")
                        Text("PC").tag("PC")
                    }

                    VStack(alignment: .leading) {
                        Text("Brightness: \(config.brightness)")
                        Slider(value: Binding(
                            get: { Double(config.brightness) },
                            set: { self.viewModel.config?.brightness = Int($0) }
                        ), in: 0 ... 255, step: 1)
                    }

                    Toggle("Bluetooth", isOn: Binding(
                        get: { config.bluetooth },
                        set: { self.viewModel.config?.bluetooth = $0 }
                    ))

                    Stepper("Slot ID: \(config.slotId)", value: Binding(
                        get: { config.slotId },
                        set: { self.viewModel.config?.slotId = $0 }
                    ), in: 1 ... 16)
                }

                Section {
                    Button("Save") {
                        Task { await self.viewModel.save() }
                    }
                    .disabled(self.viewModel.isLoading)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("General")
        .task { await self.viewModel.load() }
        .alert("Error", isPresented: .constant(self.viewModel.error != nil)) {
            Button("OK") { self.viewModel.error = nil }
        } message: {
            Text(self.viewModel.error ?? "")
        }
    }
}
