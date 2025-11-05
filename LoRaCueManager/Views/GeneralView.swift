import SwiftUI

struct GeneralView: View {
    @StateObject private var viewModel: GeneralViewModel

    init(service: LoRaCueService) {
        _viewModel = StateObject(wrappedValue: GeneralViewModel(service: service))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let config = viewModel.config {
                    // Device Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Device Name")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("Enter device name", text: Binding(
                            get: { config.name },
                            set: { self.viewModel.config?.name = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }

                    // Operation Mode
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Operation Mode")
                            .font(.subheadline)
                            .fontWeight(.medium)
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

                    // Display Brightness
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Display Brightness: \(config.brightness)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Slider(value: Binding(
                            get: { Double(config.brightness) },
                            set: { self.viewModel.config?.brightness = Int($0) }
                        ), in: 0 ... 255, step: 1)
                    }

                    // Slot ID and Bluetooth (2 columns)
                    HStack(alignment: .top, spacing: 24) {
                        // Slot ID
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Slot ID (Multi-PC Routing)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Picker("", selection: Binding(
                                get: { config.slotId },
                                set: { self.viewModel.config?.slotId = $0 }
                            )) {
                                ForEach(1 ... 16, id: \.self) { slot in
                                    Text("Slot \(slot)").tag(slot)
                                }
                            }
                            .labelsHidden()
                            Text("Select which PC is controlled or events are received for")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)

                        // Bluetooth
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Bluetooth Configuration")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { config.bluetooth },
                                    set: { self.viewModel.config?.bluetooth = $0 }
                                ))
                                .labelsHidden()
                            }
                            Text("Enable Bluetooth for wireless configuration")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Save Button
                    Divider()
                        .padding(.top, 8)

                    HStack {
                        Spacer()
                        Button(action: {
                            Task { await self.viewModel.save() }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.down")
                                Text("Save")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(self.viewModel.isLoading)

                        if self.viewModel.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
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
                    .padding()
                }
            }
            .padding(32)
        }
        .navigationTitle("General Settings")
        .task { await self.viewModel.load() }
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
        }
        .buttonStyle(.plain)
    }
}
