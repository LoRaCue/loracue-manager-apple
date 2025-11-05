import CoreBluetooth
import SwiftUI

struct DeviceListView: View {
    @StateObject private var bleManager = BLEManager()
    #if os(macOS)
    @StateObject private var usbManager = USBManager()
    #endif
    @StateObject private var viewModel: DeviceListViewModel
    @State private var selectedDevice: String?

    init(service: LoRaCueService) {
        _viewModel = StateObject(wrappedValue: DeviceListViewModel(service: service))
    }

    var body: some View {
        List(selection: self.$selectedDevice) {
            if !self.sortedBLEDevices.isEmpty {
                Section("BLE Devices") {
                    ForEach(self.sortedBLEDevices, id: \.identifier) { peripheral in
                        DeviceRow(
                            name: peripheral.name ?? "Unknown",
                            type: "BLE",
                            isFavorite: self.viewModel.favorites.contains(peripheral.identifier.uuidString),
                            isConnected: self.bleManager.connectedPeripheral?.identifier == peripheral.identifier
                        ) {
                            self.bleManager.connect(to: peripheral)
                            self.selectedDevice = peripheral.identifier.uuidString
                        } onFavorite: {
                            self.viewModel.toggleFavorite(peripheral.identifier.uuidString)
                        }
                        .tag(peripheral.identifier.uuidString)
                    }
                }
            }

            #if os(macOS)
            if !self.usbManager.discoveredDevices.isEmpty {
                Section("USB Devices") {
                    ForEach(self.usbManager.discoveredDevices, id: \.self) { path in
                        DeviceRow(
                            name: path.components(separatedBy: "/").last ?? "Unknown",
                            type: "USB",
                            isFavorite: self.viewModel.favorites.contains(path),
                            isConnected: self.usbManager.isConnected
                        ) {
                            try? self.usbManager.connect(to: path)
                            self.selectedDevice = path
                        } onFavorite: {
                            self.viewModel.toggleFavorite(path)
                        }
                        .tag(path)
                    }
                }
            }
            #endif

            if self.sortedBLEDevices.isEmpty {
                #if os(macOS)
                if self.usbManager.discoveredDevices.isEmpty {
                    ContentUnavailableView(
                        "No Devices Found",
                        systemImage: "antenna.radiowaves.left.and.right.slash",
                        description: Text("Tap Scan to search for devices")
                    )
                }
                #else
                ContentUnavailableView(
                    "No Devices Found",
                    systemImage: "antenna.radiowaves.left.and.right.slash",
                    description: Text("Tap Scan to search for devices")
                )
                #endif
            }
        }
        .navigationTitle("Devices")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: self.scan) {
                    Label("Scan", systemImage: self.bleManager.isScanning ? "stop.circle.fill" : "arrow.clockwise")
                }
                .accessibilityLabel(self.bleManager.isScanning ? "Stop scanning" : "Scan for devices")
                .accessibilityHint(self.bleManager
                    .isScanning ? "Stops searching for devices" : "Searches for nearby LoRaCue devices")
            }
        }
        .task {
            // Auto-scan on appear
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
            self.scan()
        }
    }

    private var sortedBLEDevices: [CBPeripheral] {
        self.bleManager.discoveredDevices
            .filter { peripheral in
                guard let name = peripheral.name else { return false }
                return name.hasPrefix("LoRaCue")
            }
            .sorted { lhs, rhs in
                let lhsFav = self.viewModel.favorites.contains(lhs.identifier.uuidString)
                let rhsFav = self.viewModel.favorites.contains(rhs.identifier.uuidString)
                if lhsFav != rhsFav { return lhsFav }
                return (lhs.name ?? "") < (rhs.name ?? "")
            }
    }

    private func scan() {
        if self.bleManager.isScanning {
            self.bleManager.stopScanning()
        } else {
            self.bleManager.startScanning()
            #if os(macOS)
            self.usbManager.scanForDevices()
            #endif
        }
    }
}

struct DeviceRow: View {
    let name: String
    let type: String
    let isFavorite: Bool
    let isConnected: Bool
    let onTap: () -> Void
    let onFavorite: () -> Void

    var body: some View {
        HStack {
            // Connection indicator
            Circle()
                .fill(self.isConnected ? Color.green : Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(self.name)
                    .font(.headline)
                HStack(spacing: 4) {
                    Text(self.type)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if self.isConnected {
                        Text("• Connected")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }

            Spacer()

            Button(action: self.onFavorite) {
                Image(systemName: self.isFavorite ? "star.fill" : "star")
                    .foregroundColor(self.isFavorite ? .yellow : .gray)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(self.isFavorite ? "Remove from favorites" : "Add to favorites")
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: self.onTap)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(self.name), \(self.type)\(self.isConnected ? ", connected" : "")")
        .accessibilityHint("Double tap to connect")
    }
}
