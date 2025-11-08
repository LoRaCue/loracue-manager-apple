import OSLog
import SwiftUI

struct DeviceDetailView: View {
    @ObservedObject var service: LoRaCueService

    var body: some View {
        DetailContent(bleManager: self.service.bleManager, service: self.service)
    }
}

// MARK: - Tab Enum

private enum ConfigTab: String, CaseIterable {
    case general = "General"
    case power = "Power"
    case lora = "LoRa"
    case paired = "Paired"
    case firmware = "Firmware"
    case system = "System"
}

private struct DetailContent: View {
    @ObservedObject var bleManager: BLEManager
    let service: LoRaCueService
    @State private var selectedTab: ConfigTab = .general
    @State private var selectedTabIndex = 0
    @State private var showSystemInfo = false
    @State private var showAddDevice = false
    @State private var deviceName = "Device"

    @StateObject private var generalVM: GeneralViewModel
    @StateObject private var powerVM: PowerViewModel
    @StateObject private var loraVM: LoRaViewModel
    @StateObject private var pairedVM: PairedDevicesViewModel

    init(bleManager: BLEManager, service: LoRaCueService) {
        self.bleManager = bleManager
        self.service = service
        _generalVM = StateObject(wrappedValue: GeneralViewModel(service: service))
        _powerVM = StateObject(wrappedValue: PowerViewModel(service: service))
        _loraVM = StateObject(wrappedValue: LoRaViewModel(service: service))
        _pairedVM = StateObject(wrappedValue: PairedDevicesViewModel(service: service))
    }

    private var isConnected: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return self.bleManager.connectedPeripheral != nil && self.bleManager.connectionState == .connected
        #endif
    }

    private var isConnecting: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return self.bleManager.connectionState == .connecting
        #endif
    }

    private var currentIsDirty: Bool {
        switch self.selectedTabIndex {
        case 0: self.generalVM.isDirty
        case 1: self.powerVM.isDirty
        case 2: self.loraVM.isDirty
        default: false
        }
    }

    private var currentIsLoading: Bool {
        switch self.selectedTabIndex {
        case 0: self.generalVM.isLoading
        case 1: self.powerVM.isLoading
        case 2: self.loraVM.isLoading
        default: false
        }
    }

    var body: some View {
        Group {
            if self.isConnected {
                self.configurationView
            } else if self.isConnecting {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Connecting...")
                        .foregroundColor(.secondary)
                }
            } else {
                ContentUnavailableView(
                    "No Device Connected",
                    systemImage: "antenna.radiowaves.left.and.right.slash",
                    description: Text("Select a device from the list to connect")
                )
            }
        }
        .onChange(of: self.bleManager.connectedPeripheral?.identifier) { _, newValue in
            Logger.ui.info(
                """
                Peripheral changed: \(newValue?.uuidString ?? "nil") \
                BLEManager: \(self.bleManager.instanceId)
                """
            )
        }
        .onAppear {
            Logger.ui.info(
                """
                DetailContent appeared: BLEManager=\(self.bleManager.instanceId) \
                peripheral=\(self.bleManager.connectedPeripheral?.identifier.uuidString ?? "nil")
                """
            )
        }
    }

    @ViewBuilder
    private var configurationView: some View {
        #if os(iOS)
        TabView(selection: self.$selectedTabIndex) {
            GeneralView(viewModel: self.generalVM)
                .tag(0)
                .tabItem { Label("General", systemImage: "gear") }

            PowerView(viewModel: self.powerVM)
                .tag(1)
                .tabItem { Label("Power", systemImage: "battery.100") }

            LoRaView(viewModel: self.loraVM)
                .tag(2)
                .tabItem { Label("LoRa", systemImage: "antenna.radiowaves.left.and.right") }

            PairedDevicesView(service: self.service)
                .tag(3)
                .tabItem { Label("Paired", systemImage: "link") }

            FirmwareUpgradeView(service: self.service)
                .tag(4)
                .tabItem { Label("Firmware", systemImage: "arrow.down.circle") }
        }
        .navigationTitle(self.deviceName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 4) {
                    Text(self.deviceName)
                        .font(.headline)
                    Button {
                        self.showSystemInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.blue)
                    }
                }
            }

            ToolbarItem(placement: .primaryAction) {
                if self.selectedTabIndex < 3 {
                    Button("Save") {
                        Logger.ui.info("💾 Save button tapped on tab \(self.selectedTabIndex)")
                        Task {
                            switch self.selectedTabIndex {
                            case 0: await self.generalVM.save()
                            case 1: await self.powerVM.save()
                            case 2: await self.loraVM.save()
                            default: break
                            }
                        }
                    }
                    .foregroundStyle(.blue)
                    .fontWeight(self.currentIsDirty ? .semibold : .regular)
                    .opacity(self.currentIsDirty && !self.currentIsLoading ? 1.0 : 0.4)
                    .disabled(!self.currentIsDirty || self.currentIsLoading)
                } else if self.selectedTabIndex == 3 {
                    Button {
                        self.showAddDevice = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: self.$showSystemInfo) {
            NavigationStack {
                SystemView(service: self.service)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                self.showSystemInfo = false
                            }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(
            isPresented: self.$showAddDevice,
            onDismiss: {
                Task {
                    await self.pairedVM.load()
                }
            },
            content: {
                PairedDeviceModal(device: nil, viewModel: self.pairedVM)
                    .presentationDetents([.medium, .large])
            }
        )
        .onChange(of: self.generalVM.config?.name) { _, newName in
            if let newName {
                self.deviceName = newName
            }
        }
        #else
        VStack(spacing: 0) {
            // Cards grid
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 16) {
                CategoryCard(title: "General", icon: "gear", isSelected: self.selectedTab == .general) {
                    self.selectedTab = .general
                }
                CategoryCard(title: "Power", icon: "battery.100", isSelected: self.selectedTab == .power) {
                    self.selectedTab = .power
                }
                CategoryCard(
                    title: "LoRa",
                    icon: "antenna.radiowaves.left.and.right",
                    isSelected: self.selectedTab == .lora
                ) {
                    self.selectedTab = .lora
                }
                CategoryCard(title: "Paired Devices", icon: "link", isSelected: self.selectedTab == .paired) {
                    self.selectedTab = .paired
                }
                CategoryCard(title: "Firmware", icon: "arrow.down.circle", isSelected: self.selectedTab == .firmware) {
                    self.selectedTab = .firmware
                }
                CategoryCard(title: "System", icon: "info.circle", isSelected: self.selectedTab == .system) {
                    self.selectedTab = .system
                }
            }
            .padding()

            Divider()

            // Detail view
            Group {
                switch self.selectedTab {
                case .general:
                    GeneralView(viewModel: self.generalVM)
                case .power:
                    PowerView(viewModel: self.powerVM)
                case .lora:
                    LoRaView(viewModel: self.loraVM)
                case .paired:
                    PairedDevicesView(service: self.service)
                case .firmware:
                    FirmwareUpgradeView(service: self.service)
                case .system:
                    SystemView(service: self.service)
                }
            }
        }
        .navigationTitle(self.deviceName)
        #endif
    }
}

// MARK: - Category Card (macOS only)

#if os(macOS)
private struct CategoryCard: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            VStack(spacing: 8) {
                Image(systemName: self.icon)
                    .font(.system(size: 24))
                    .foregroundColor(self.isSelected ? .white : .blue)

                Text(self.title)
                    .font(.subheadline)
                    .foregroundColor(self.isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(self.isSelected ? Color.blue : Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}
#endif
