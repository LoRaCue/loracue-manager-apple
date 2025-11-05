import SwiftUI

struct GeneralView: View {
    @StateObject private var viewModel: GeneralViewModel

    init(service: LoRaCueService) {
        _viewModel = StateObject(wrappedValue: GeneralViewModel(service: service))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let config = viewModel.config {
                    GroupBox("Device Identity") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Name")
                                    .frame(width: 120, alignment: .leading)
                                TextField("", text: Binding(
                                    get: { config.name },
                                    set: { self.viewModel.config?.name = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 250)
                                Spacer()
                            }
                            
                            HStack {
                                Text("Mode")
                                    .frame(width: 120, alignment: .leading)
                                Picker("", selection: Binding(
                                    get: { config.mode },
                                    set: { self.viewModel.config?.mode = $0 }
                                )) {
                                    Text("Presenter").tag("PRESENTER")
                                    Text("PC").tag("PC")
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 200)
                                Spacer()
                            }
                            
                            HStack {
                                Text("Slot ID")
                                    .frame(width: 120, alignment: .leading)
                                Stepper("\(config.slotId)", value: Binding(
                                    get: { config.slotId },
                                    set: { self.viewModel.config?.slotId = $0 }
                                ), in: 1...16)
                                .frame(width: 100)
                                Spacer()
                            }
                        }
                        .padding()
                    }
                    
                    GroupBox("Display") {
                        HStack {
                            Text("Brightness")
                                .frame(width: 120, alignment: .leading)
                            Slider(value: Binding(
                                get: { Double(config.brightness) },
                                set: { self.viewModel.config?.brightness = Int($0) }
                            ), in: 0...255, step: 1)
                            .frame(width: 200)
                            Text("\(config.brightness)")
                                .frame(width: 40, alignment: .leading)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding()
                    }
                    
                    GroupBox("Connectivity") {
                        HStack {
                            Text("Bluetooth")
                                .frame(width: 120, alignment: .leading)
                            Toggle("", isOn: Binding(
                                get: { config.bluetooth },
                                set: { self.viewModel.config?.bluetooth = $0 }
                            ))
                            .labelsHidden()
                            Spacer()
                        }
                        .padding()
                    }

                    HStack {
                        Spacer()
                            .frame(width: 120)
                        Button("Save Changes") {
                            Task { await self.viewModel.save() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(self.viewModel.isLoading)
                        
                        if viewModel.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Spacer()
                    }
                    .padding(.top, 10)
                } else if viewModel.error != nil {
                    ContentUnavailableView(
                        "Failed to Load",
                        systemImage: "exclamationmark.triangle",
                        description: Text(viewModel.error ?? "Unknown error")
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
            .padding(20)
        }
        .navigationTitle("General")
        .task { await self.viewModel.load() }
    }
}
