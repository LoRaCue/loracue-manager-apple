import SwiftUI

struct PairedDevicesView: View {
    @StateObject private var viewModel: PairedDevicesViewModel
    @State private var showAddEdit = false
    @State private var editingDevice: PairedDevice?

    init(service: LoRaCueService) {
        _viewModel = StateObject(wrappedValue: PairedDevicesViewModel(service: service))
    }

    var body: some View {
        List {
            ForEach(self.viewModel.devices) { device in
                VStack(alignment: .leading) {
                    Text(device.name)
                        .font(.headline)
                    Text(device.mac)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .swipeActions {
                    Button(role: .destructive) {
                        Task { await self.viewModel.delete(mac: device.mac) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }

                    Button {
                        self.editingDevice = device
                        self.showAddEdit = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
        }
        .navigationTitle("Paired Devices")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    self.editingDevice = nil
                    self.showAddEdit = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .task { await self.viewModel.load() }
        .sheet(isPresented: self.$showAddEdit) {
            PairedDeviceModal(device: self.editingDevice, viewModel: self.viewModel)
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
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: self.$name)

                    TextField("MAC Address", text: self.$mac)
                    #if os(iOS)
                        .textInputAutocapitalization(.characters)
                    #endif
                        .autocorrectionDisabled()
                        .disabled(self.device != nil)
                        .onChange(of: self.mac) { _, newValue in
                            self.mac = LoRaCalculator.formatMACAddress(newValue)
                        }

                    TextField("AES Key (64 hex chars)", text: self.$aesKey)
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
            .navigationTitle(self.device == nil ? "Add Device" : "Edit Device")
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
                    .disabled(self.name.isEmpty || self.mac.count != 17 || self.aesKey.count != 64)
                }
            }
        }
        .onAppear {
            if let device {
                self.name = device.name
                self.mac = device.mac
                self.aesKey = ""
            }
        }
    }
}
