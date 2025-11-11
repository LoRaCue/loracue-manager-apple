import SwiftUI

struct GeneralView: View {
    @ObservedObject var viewModel: GeneralViewModel
    @State private var showResetConfirmation = false
    @State private var showFinalConfirmation = false
    @State private var showBluetoothWarning = false

    var body: some View {
        VStack(spacing: 0) {
            Form {
                if let config = viewModel.config {
                    Section("Device Name") {
                        TextField("Enter device name", text: Binding(
                            get: { config.name },
                            set: { self.viewModel.config?.name = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }

                    Section("Operation Mode") {
                        HStack(spacing: 16) {
                            ModeButton(
                                title: "Presenter",
                                description: "Send commands",
                                isSelected: config.mode == "PRESENTER",
                                action: { self.viewModel.config?.mode = "PRESENTER" }
                            )
                            ModeButton(
                                title: "PC Receiver",
                                description: "Receive commands",
                                isSelected: config.mode == "PC",
                                action: { self.viewModel.config?.mode = "PC" }
                            )
                        }
                    }

                    Section("Display Brightness") {
                        HStack {
                            Text("\(config.brightness)")
                            Spacer()
                            Slider(value: Binding(
                                get: { Double(config.brightness) },
                                set: { self.viewModel.config?.brightness = Int($0) }
                            ), in: 0 ... 255, step: 1)
                            #if os(macOS)
                                .controlSize(.large)
                            #endif
                        }
                    }

                    Section {
                        HStack {
                            Text("Slot ID\n(Multi-PC Routing)")
                            Spacer()
                            Picker("", selection: Binding(
                                get: { config.slotId },
                                set: { self.viewModel.config?.slotId = $0 }
                            )) {
                                ForEach(1 ... 16, id: \.self) { slot in
                                    Text("Slot \(slot)").tag(slot)
                                }
                            }
                            .labelsHidden()
                        }
                    } footer: {
                        Text("Select which PC is controlled or events are received for")
                    }

                    Section {
                        Toggle("Bluetooth", isOn: Binding(
                            get: { config.bluetooth },
                            set: { newValue in
                                if !newValue, self.viewModel.service.bleManager.connectedPeripheral != nil {
                                    self.showBluetoothWarning = true
                                } else {
                                    self.viewModel.config?.bluetooth = newValue
                                }
                            }
                        ))
                    } footer: {
                        Text("Enable Bluetooth for wireless configuration")
                    }

                } else if self.viewModel.error != nil {
                    ContentUnavailableView(
                        "Failed to Load",
                        systemImage: "exclamationmark.triangle",
                        description: Text(self.viewModel.error ?? "Unknown error")
                    )
                } else {
                    HStack {
                        Spacer()
                        ProgressView("Loading...")
                        Spacer()
                    }
                }
            }
            .formStyle(.grouped)

            if self.viewModel.config != nil {
                VStack {
                    Divider()
                        .padding(.top, 32)
                        .padding(.bottom, 32)

                    Button(role: .destructive) {
                        self.showResetConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                            Text("Factory Reset")
                        }
                        .font(.system(size: 24))
                        .foregroundColor(Color(red: 0.6, green: 0, blue: 0))
                        .frame(maxWidth: .infinity)
                        .frame(height: 62)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                    #if os(macOS)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(red: 0.6, green: 0, blue: 0), lineWidth: 1)
                        )
                    #endif
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationTitle("General Settings")
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
            // Wait for BLE device to be ready
            while !self.viewModel.service.isReady {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
            await self.viewModel.load()
        }
        .confirmationDialog("Factory Reset", isPresented: self.$showResetConfirmation, titleVisibility: .visible) {
            Button("Reset to Factory Defaults", role: .destructive) {
                self.showFinalConfirmation = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will erase all device settings and reboot. This action cannot be undone.")
        }
        .confirmationDialog("Final Confirmation", isPresented: self.$showFinalConfirmation, titleVisibility: .visible) {
            Button("Reset Now", role: .destructive) {
                Task { await self.viewModel.factoryReset() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. All settings will be permanently erased.")
        }
        .alert("Disable Bluetooth?", isPresented: self.$showBluetoothWarning) {
            Button("Cancel", role: .cancel) {}
            Button("Disable", role: .destructive) {
                self.viewModel.config?.bluetooth = false
            }
        } message: {
            Text(
                """
                Disabling Bluetooth will disconnect the device. You can only re-enable Bluetooth \
                from the device settings menu.
                """
            )
        }
    }
}

// Mode Button Component
private struct ModeButton: View {
    let title: String
    let description: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(self.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(self.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(self.isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(self.isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
