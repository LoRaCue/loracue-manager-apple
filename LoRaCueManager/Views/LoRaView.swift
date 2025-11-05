import SwiftUI

struct LoRaView: View {
    @StateObject private var viewModel: LoRaViewModel
    @State private var showAESKeyModal = false
    @State private var showBandWarning = false
    @State private var aesKey = ""

    init(service: LoRaCueService) {
        _viewModel = StateObject(wrappedValue: LoRaViewModel(service: service))
    }

    var body: some View {
        Form {
            if let config = viewModel.config {
                Section("Quick Presets") {
                    ForEach(LoRaPreset.presets, id: \.name) { preset in
                        Button(preset.name) {
                            self.viewModel.applyPreset(preset)
                        }
                    }
                }

                Section("Hardware Band") {
                    Picker("Band", selection: Binding(
                        get: { config.bandId },
                        set: { newBand in
                            self.showBandWarning = true
                            self.viewModel.config?.bandId = newBand
                            if let band = viewModel.bands.first(where: { $0.id == newBand }) {
                                self.viewModel.config?.frequency = band.centerKhz
                            }
                        }
                    )) {
                        ForEach(self.viewModel.bands) { band in
                            Text(band.name).tag(band.id)
                        }
                    }
                }

                Section("Parameters") {
                    VStack(alignment: .leading) {
                        Text("Frequency: \(config.frequency / 1000) MHz")
                        Slider(value: Binding(
                            get: { Double(config.frequency) },
                            set: { self.viewModel.config?.frequency = Int($0) }
                        ), in: 860_000 ... 870_000, step: 100)
                    }

                    Stepper("Spreading Factor: \(config.spreadingFactor)", value: Binding(
                        get: { config.spreadingFactor },
                        set: { self.viewModel.config?.spreadingFactor = $0 }
                    ), in: 7 ... 12)

                    Picker("Bandwidth", selection: Binding(
                        get: { config.bandwidth },
                        set: { self.viewModel.config?.bandwidth = $0 }
                    )) {
                        Text("125 kHz").tag(125_000)
                        Text("250 kHz").tag(250_000)
                        Text("500 kHz").tag(500_000)
                    }

                    Picker("Coding Rate", selection: Binding(
                        get: { config.codingRate },
                        set: { self.viewModel.config?.codingRate = $0 }
                    )) {
                        Text("4/5").tag(5)
                        Text("4/6").tag(6)
                        Text("4/7").tag(7)
                        Text("4/8").tag(8)
                    }

                    Stepper("TX Power: \(config.txPower) dBm", value: Binding(
                        get: { config.txPower },
                        set: { self.viewModel.config?.txPower = $0 }
                    ), in: 2 ... 20)
                }

                Section("Performance Estimate") {
                    HStack {
                        Text("Time on Air:")
                        Spacer()
                        Text("\(self.viewModel.performance.latency) ms")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Range:")
                        Spacer()
                        Text("\(self.viewModel.performance.range) m")
                            .foregroundColor(.secondary)
                    }
                }

                Section("Encryption") {
                    Button("Set AES Key") {
                        self.showAESKeyModal = true
                    }
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
        .navigationTitle("LoRa Configuration")
        .task { await self.viewModel.load() }
        .alert("Band Warning", isPresented: self.$showBandWarning) {
            Button("OK") {}
        } message: {
            Text("Changing the hardware band is a hardware-dependent setting. Ensure your device supports this band.")
        }
        .sheet(isPresented: self.$showAESKeyModal) {
            AESKeyModal(aesKey: self.$aesKey, service: self.viewModel.service)
        }
        .alert("Error", isPresented: .constant(self.viewModel.error != nil)) {
            Button("OK") { self.viewModel.error = nil }
        } message: {
            Text(self.viewModel.error ?? "")
        }
    }
}

struct AESKeyModal: View {
    @Binding var aesKey: String
    @Environment(\.dismiss) var dismiss
    let service: LoRaCueService

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("64-character hex key", text: self.$aesKey)
                    #if os(iOS)
                        .textInputAutocapitalization(.never)
                    #endif
                        .autocorrectionDisabled()
                }

                Section {
                    Button("Generate Random Key") {
                        self.aesKey = LoRaCalculator.generateRandomAESKey()
                    }

                    Button("Copy to Clipboard") {
                        #if os(iOS)
                        UIPasteboard.general.string = self.aesKey
                        #else
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(self.aesKey, forType: .string)
                        #endif
                    }
                    .disabled(self.aesKey.count != 64)
                }
            }
            .navigationTitle("Set AES Key")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { self.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            try? await self.service.setLoRaKey(LoRaKey(aesKey: self.aesKey))
                            self.dismiss()
                        }
                    }
                    .disabled(self.aesKey.count != 64)
                }
            }
        }
    }
}
