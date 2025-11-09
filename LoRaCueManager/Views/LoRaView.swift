import SwiftUI

struct LoRaView: View {
    @ObservedObject var viewModel: LoRaViewModel
    @State private var showAESKeyModal = false
    @State private var showBandWarning = false
    @State private var aesKey = ""

    var body: some View {
        Form {
            if let config = viewModel.config {
                self.presetsSection(config: config)

                Section("Hardware Band") {
                    Picker("Band", selection: Binding(
                        get: { config.bandId },
                        set: { newBand in
                            self.showBandWarning = true
                            if let band = viewModel.bands.first(where: { $0.id == newBand }) {
                                var updatedConfig = config
                                updatedConfig.bandId = newBand
                                updatedConfig.frequency = band.centerKhz
                                self.viewModel.config = updatedConfig
                            }
                        }
                    )) {
                        ForEach(self.viewModel.bands) { band in
                            Text(band.name).tag(band.id)
                        }
                    }
                }

                Section("Parameters") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Frequency: \(Double(config.frequency) / 1000.0, specifier: "%.1f") MHz")
                        if let band = viewModel.bands.first(where: { $0.id == config.bandId }) {
                            Slider(value: Binding(
                                get: {
                                    let rounded = (config.frequency / 100) * 100
                                    return Double(rounded)
                                },
                                set: { newValue in
                                    let rounded = (Int(newValue) / 100) * 100
                                    self.viewModel.config?.frequency = rounded
                                }
                            ), in: Double(band.minKhz) ... Double(band.maxKhz), step: 100)
                        }
                    }

                    Stepper("Spreading Factor: \(config.spreadingFactor)", value: Binding(
                        get: { config.spreadingFactor },
                        set: { self.viewModel.config?.spreadingFactor = $0 }
                    ), in: 7 ... 12)

                    Picker("Bandwidth", selection: Binding(
                        get: { config.bandwidth },
                        set: { self.viewModel.config?.bandwidth = $0 }
                    )) {
                        Text("125 kHz").tag(125)
                        Text("250 kHz").tag(250)
                        Text("500 kHz").tag(500)
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

                    HStack {
                        if let band = viewModel.bands.first(where: { $0.id == config.bandId }),
                           config.txPower > band.maxPowerDbm
                        {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                        }
                        Stepper("TX Power: \(config.txPower) dBm", value: Binding(
                            get: { config.txPower },
                            set: { self.viewModel.config?.txPower = $0 }
                        ), in: 2 ... 20)
                    }
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
                    Button {
                        Task {
                            if let key = try? await self.viewModel.service.getLoRaKey() {
                                self.aesKey = key.aesKey
                            }
                            self.showAESKeyModal = true
                        }
                    } label: {
                        HStack {
                            Text("AES-256 Key")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("LoRa Configuration")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Save") {
                    Task { await self.viewModel.save() }
                }
                .disabled(self.viewModel.isLoading)
            }
        }
        .task {
            while !self.viewModel.service.isReady {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            await self.viewModel.load()
        }
        .alert("Band Warning", isPresented: self.$showBandWarning) {
            Button("OK") {}
        } message: {
            Text("Changing the hardware band is a hardware-dependent setting. Ensure your device supports this band.")
        }
        .sheet(isPresented: self.$showAESKeyModal) {
            AESKeyModal(aesKey: self.$aesKey, service: self.viewModel.service)
                .presentationDetents([.medium])
        }
        .alert("Error", isPresented: .constant(self.viewModel.error != nil)) {
            Button("OK") { self.viewModel.error = nil }
        } message: {
            Text(self.viewModel.error ?? "")
        }
        #if os(iOS)
        .formStyle(.grouped)
        #endif
        #if os(macOS)
        .padding(.horizontal, 32)
        .padding(.top, 0)
        .padding(.bottom, 32)
        #endif
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func presetsSection(config: LoRaConfig) -> some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(LoRaPreset.presets, id: \.name) { preset in
                        PresetCard(
                            preset: preset,
                            isSelected: config.spreadingFactor == preset.sf &&
                                config.bandwidth == preset.bw &&
                                config.codingRate == preset.cr &&
                                config.txPower == preset.power
                        ) {
                            self.viewModel.applyPreset(preset)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
        } header: {
            Text("Quick Presets")
        }
    }
}

struct AESKeyModal: View {
    @Binding var aesKey: String
    @Environment(\.dismiss) var dismiss
    let service: LoRaCueService
    @State private var originalKey = ""
    @State private var showKey = false

    private var isDirty: Bool {
        self.aesKey != self.originalKey && self.aesKey.count == 64
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("AES-256 Encryption Key") {
                    HStack {
                        if self.showKey {
                            TextField("64 hex characters", text: self.$aesKey, axis: .horizontal)
                            #if os(iOS)
                                .textInputAutocapitalization(.never)
                            #endif
                                .autocorrectionDisabled()
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)
                        } else {
                            Text(String(repeating: "•", count: 64))
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                        }

                        Button {
                            self.showKey.toggle()
                        } label: {
                            Image(systemName: self.showKey ? "eye.slash" : "eye")
                        }
                    }

                    HStack {
                        Button {
                            self.aesKey = LoRaCalculator.generateRandomAESKey()
                            self.showKey = true
                        } label: {
                            Label("Generate Random", systemImage: "dice")
                        }

                        Spacer()

                        Button {
                            #if os(iOS)
                            UIPasteboard.general.string = self.aesKey
                            #else
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(self.aesKey, forType: .string)
                            #endif
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        .disabled(self.aesKey.count != 64)
                    }
                    .buttonStyle(.borderless)
                }

                if !self.aesKey.isEmpty, self.aesKey.count != 64 {
                    Section {
                        Label("Key must be exactly 64 hex characters", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
            }
            #if os(macOS)
            .padding(20)
            #endif
            .navigationTitle("AES-256 Key")
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
                    .foregroundStyle(.blue)
                    .fontWeight(self.isDirty ? .semibold : .regular)
                    .opacity(self.isDirty ? 1.0 : 0.4)
                    .disabled(!self.isDirty)
                }
            }
            .onAppear {
                self.originalKey = self.aesKey
            }
        }
    }
}

// MARK: - Preset Card Component

private struct PresetCard: View {
    let preset: LoRaPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(self.preset.name)
                    .font(.headline)
                    .foregroundColor(self.isSelected ? .white : .primary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("SF\(self.preset.sf)")
                        .font(.caption)
                    Text("\(self.preset.bw) kHz")
                        .font(.caption)
                }
                .foregroundColor(self.isSelected ? .white.opacity(0.9) : .secondary)
            }
            .frame(width: 130, height: 80)
            .background(self.isSelected ? Color.blue : Color.gray.opacity(0.2))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
