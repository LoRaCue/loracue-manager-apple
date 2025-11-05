import SwiftUI

struct DeviceDetailView: View {
    @ObservedObject var service: LoRaCueService

    private var isConnected: Bool {
        self.service.bleManager?.connectedPeripheral != nil
    }

    var body: some View {
        Group {
            if self.isConnected {
                self.configurationView
            } else {
                ContentUnavailableView(
                    "No Device Connected",
                    systemImage: "antenna.radiowaves.left.and.right.slash",
                    description: Text("Select a device from the list to connect")
                )
            }
        }
        .id(self.service.bleManager?.connectedPeripheral?.identifier)
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
            List {
                NavigationLink("General", destination: GeneralView(service: self.service))
                NavigationLink("Power", destination: PowerView(service: self.service))
                NavigationLink("LoRa", destination: LoRaView(service: self.service))
                NavigationLink("Paired Devices", destination: PairedDevicesView(service: self.service))
                NavigationLink("Firmware", destination: FirmwareUpgradeView(service: self.service))
                NavigationLink("System", destination: SystemView(service: self.service))
            }
            .navigationTitle("Configuration")
        } detail: {
            Text("Select a configuration tab")
                .foregroundColor(.secondary)
        }
        #endif
    }
}
