import OSLog
import SwiftUI

struct DeviceDetailView: View {
    @ObservedObject var service: LoRaCueService

    var body: some View {
        if let bleManager = service.bleManager {
            DetailContent(bleManager: bleManager, service: self.service)
        } else {
            ContentUnavailableView(
                "No Device Connected",
                systemImage: "antenna.radiowaves.left.and.right.slash",
                description: Text("Select a device from the list to connect")
            )
            .onAppear {
                Logger.ui.info("⚠️ No BLEManager in service \(self.service.instanceId)")
            }
        }
    }
}

private struct DetailContent: View {
    @ObservedObject var bleManager: BLEManager
    let service: LoRaCueService
    @State private var selectedTab: String? = "General"

    var body: some View {
        Group {
            if self.bleManager.connectedPeripheral != nil {
                self.configurationView
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
        TabView {
            GeneralView(service: self.service)
                .tabItem { Label("General", systemImage: "gear") }
            PowerView(service: self.service)
                .tabItem { Label("Power", systemImage: "battery.100") }
            LoRaView(service: self.service)
                .tabItem { Label("LoRa", systemImage: "antenna.radiowaves.left.and.right") }
            PairedDevicesView(service: self.service)
                .tabItem { Label("Paired", systemImage: "link") }
            FirmwareUpgradeView(service: self.service)
                .tabItem { Label("Firmware", systemImage: "arrow.down.circle") }
            SystemView(service: self.service)
                .tabItem { Label("System", systemImage: "info.circle") }
        }
        #else
        NavigationSplitView {
            List(selection: self.$selectedTab) {
                NavigationLink(value: "General") {
                    Label("General", systemImage: "gear")
                }
                NavigationLink(value: "Power") {
                    Label("Power", systemImage: "battery.100")
                }
                NavigationLink(value: "LoRa") {
                    Label("LoRa", systemImage: "antenna.radiowaves.left.and.right")
                }
                NavigationLink(value: "Paired") {
                    Label("Paired Devices", systemImage: "link")
                }
                NavigationLink(value: "Firmware") {
                    Label("Firmware", systemImage: "arrow.down.circle")
                }
                NavigationLink(value: "System") {
                    Label("System", systemImage: "info.circle")
                }
            }
            .navigationTitle("Configuration")
        } detail: {
            switch self.selectedTab {
            case "General":
                GeneralView(service: self.service)
            case "Power":
                PowerView(service: self.service)
            case "LoRa":
                LoRaView(service: self.service)
            case "Paired":
                PairedDevicesView(service: self.service)
            case "Firmware":
                FirmwareUpgradeView(service: self.service)
            case "System":
                SystemView(service: self.service)
            default:
                Text("Select a configuration tab")
                    .foregroundColor(.secondary)
            }
        }
        #endif
    }
}
