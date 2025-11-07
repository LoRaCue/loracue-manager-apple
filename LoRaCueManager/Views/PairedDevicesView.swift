import SwiftUI
import OSLog

struct PairedDevicesView: View {
    @StateObject private var viewModel: PairedDevicesViewModel
    @State private var editingDevice: PairedDevice?

    init(service: LoRaCueService) {
        _viewModel = StateObject(wrappedValue: PairedDevicesViewModel(service: service))
    }

    var body: some View {
        List {
            if self.viewModel.devices.isEmpty {
                ContentUnavailableView(
                    "No Paired Devices",
                    systemImage: "link.badge.plus",
                    description: Text("Add devices to pair with this LoRaCue")
                )
            } else {
                ForEach(self.viewModel.devices) { device in
                    HStack(spacing: 12) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.title2)
                            .foregroundStyle(.blue)
                            .frame(width: 40)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.name)
                                .font(.headline)
                            
                            Text(device.mac)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "key.fill")
                                    .font(.caption2)
                                Text("AES-256")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.green)
                        }
                        
                        Spacer()
                        
                        Button {
                            self.editingDevice = device
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await self.viewModel.delete(mac: device.mac) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Paired Devices")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    self.editingDevice = PairedDevice(name: "", mac: "", aesKey: "")
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .task {
            while !self.viewModel.service.isReady {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            await self.viewModel.load()
        }
        .sheet(item: self.$editingDevice, onDismiss: {
            self.editingDevice = nil
        }) { device in
            PairedDeviceModal(device: device.mac.isEmpty ? nil : device, viewModel: self.viewModel)
                .presentationDetents([.medium, .large])
        }
        .alert("Error", isPresented: .constant(self.viewModel.error != nil)) {
            Button("OK") { self.viewModel.error = nil }
        } message: {
            Text(self.viewModel.error ?? "")
        }
    }
}

struct PairedDeviceModal: View {
    let device: PairedDevice?
    let viewModel: PairedDevicesViewModel

    @State private var name = ""
    @State private var mac = ""
    @State private var aesKey = ""
    @State private var showKey = false
    @State private var originalName = ""
    @State private var originalMac = ""
    @State private var originalKey = ""
    @Environment(\.dismiss) var dismiss
    
    private var isDirty: Bool {
        let isValid = !name.isEmpty && mac.count == 17 && aesKey.count == 64
        let hasChanges = name != originalName || mac != originalMac || aesKey != originalKey
        return isValid && hasChanges
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Device Information") {
                    TextField("Device Name", text: self.$name)
                        .textFieldStyle(.roundedBorder)

                    if self.device == nil {
                        TextField("MAC Address", text: self.$mac)
                            .textFieldStyle(.roundedBorder)
                        #if os(iOS)
                            .textInputAutocapitalization(.characters)
                        #endif
                            .autocorrectionDisabled()
                            .onChange(of: self.mac) { _, newValue in
                                let formatted = LoRaCalculator.formatMACAddress(newValue)
                                self.mac = String(formatted.prefix(17))
                            }
                    } else {
                        LabeledContent("MAC Address") {
                            Text(self.mac)
                                .foregroundStyle(.secondary)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }

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
                
                if self.aesKey.count > 0 && self.aesKey.count != 64 {
                    Section {
                        Label("Key must be exactly 64 hex characters", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
            }
            #if os(macOS)
            .formStyle(.grouped)
            .padding(20)
            #else
            .formStyle(.grouped)
            #endif
            .navigationTitle(self.device == nil ? "Add Device" : "Device Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { self.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            let pairedDevice = PairedDevice(name: name, mac: mac, aesKey: aesKey)
                            if self.device == nil {
                                await self.viewModel.add(pairedDevice)
                            } else {
                                await self.viewModel.update(pairedDevice)
                            }
                            self.dismiss()
                        }
                    }
                    .foregroundStyle(.blue)
                    .fontWeight(isDirty ? .semibold : .regular)
                    .opacity(isDirty ? 1.0 : 0.4)
                    .disabled(!isDirty)
                }
            }
        }
        .onAppear {
            Logger.ui.info("📝 PairedDeviceModal appeared - device: \(self.device?.name ?? "nil")")
            if let device {
                self.name = device.name
                self.mac = device.mac
                self.aesKey = device.aesKey
                Logger.ui.info("📝 Loaded device data: name=\(device.name), mac=\(device.mac)")
            }
            originalName = name
            originalMac = mac
            originalKey = aesKey
        }
    }
}
