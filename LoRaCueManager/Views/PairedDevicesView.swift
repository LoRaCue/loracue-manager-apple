import OSLog
import SwiftUI

struct PairedDevicesView: View {
    @StateObject private var viewModel: PairedDevicesViewModel
    @State private var editingDevice: PairedDevice?
    @State private var hoveredDevice: String?
    @State private var deviceToDelete: PairedDevice?

    init(service: LoRaCueService) {
        _viewModel = StateObject(wrappedValue: PairedDevicesViewModel(service: service))
    }

    var body: some View {
        Form {
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

                        #if os(macOS)
                        if self.hoveredDevice == device.mac {
                            HStack(spacing: 12) {
                                Button {
                                    self.editingDevice = device
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 16))
                                }
                                .buttonStyle(.borderless)
                                .help("Edit")

                                Button {
                                    self.deviceToDelete = device
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.borderless)
                                .help("Unpair")
                            }
                        }
                        #else
                        Button {
                            self.editingDevice = device
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        #endif
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    #if os(macOS)
                        .onHover { isHovered in
                            self.hoveredDevice = isHovered ? device.mac : nil
                        }
                        .contextMenu {
                            Button {
                                self.editingDevice = device
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Divider()
                            Button(role: .destructive) {
                                self.deviceToDelete = device
                            } label: {
                                Label("Unpair", systemImage: "trash")
                            }
                        }
                    #else
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await self.viewModel.delete(mac: device.mac) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    #endif
                }
            }
        }
        .formStyle(.grouped)
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
        .sheet(
            item: self.$editingDevice,
            onDismiss: {
                self.editingDevice = nil
            },
            content: { device in
                PairedDeviceModal(device: device.mac.isEmpty ? nil : device, viewModel: self.viewModel)
                    .presentationDetents([.medium, .large])
            }
        )
        .confirmationDialog(
            "Delete Device",
            isPresented: Binding(
                get: { self.deviceToDelete != nil },
                set: { if !$0 { self.deviceToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let device = self.deviceToDelete {
                    Task {
                        await self.viewModel.delete(mac: device.mac)
                        self.deviceToDelete = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                self.deviceToDelete = nil
            }
        } message: {
            if let device = self.deviceToDelete {
                Text("Are you sure you want to delete \"\(device.name)\"? This action cannot be undone.")
            }
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
        let isValid = !self.name.isEmpty && self.mac.count == 17 && self.aesKey.count == 64
        let hasChanges = self.name != self.originalName || self.mac != self.originalMac || self.aesKey != self
            .originalKey
        return isValid && hasChanges
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Device Name", text: self.$name)

                if self.device == nil {
                    TextField("MAC Address", text: self.$mac)
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

                Section("AES-256 Encryption Key") {
                    HStack {
                        if self.showKey {
                            TextField("", text: self.$aesKey)
                                .font(.system(.body, design: .monospaced))
                            #if os(iOS)
                                .textInputAutocapitalization(.never)
                            #endif
                                .autocorrectionDisabled()
                                .onChange(of: self.aesKey) { _, newValue in
                                    let filtered = newValue.filter(\.isHexDigit).lowercased()
                                    self.aesKey = String(filtered.prefix(64))
                                }
                        } else {
                            TextField("", text: .constant(String(repeating: "•", count: max(self.aesKey.count, 64))))
                                .disabled(true)
                                .font(.system(.body, design: .monospaced))
                        }

                        Button {
                            self.showKey.toggle()
                        } label: {
                            Image(systemName: self.showKey ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.plain)
                    }

                    HStack {
                        Button {
                            self.aesKey = LoRaCalculator.generateRandomAESKey()
                            self.showKey = true
                        } label: {
                            Label("Generate", systemImage: "dice")
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
                }
            }
            .formStyle(.grouped)
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
                        .disabled(!self.isDirty)
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
            self.originalName = self.name
            self.originalMac = self.mac
            self.originalKey = self.aesKey
        }
    }
}
