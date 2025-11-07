import CoreBluetooth
import OSLog
import SwiftUI

struct DeviceListView: View {
    @ObservedObject var service: LoRaCueService
    @StateObject private var viewModel: DeviceListViewModel
    @State private var selectedDevice: String?
    @ObservedObject private var bleManager: BLEManager

    #if os(macOS)
    @StateObject private var usbManager = USBManager()
    #endif

    init(service: LoRaCueService) {
        self.service = service
        self.bleManager = service.bleManager
        _viewModel = StateObject(wrappedValue: DeviceListViewModel(service: service))
    }

    var body: some View {
        #if os(iOS)
        self.iOSDeviceList
        #else
        self.macOSDeviceList
        #endif
    }

    // MARK: - iOS UI

    @ViewBuilder
    private var iOSDeviceList: some View {
        NavigationStack {
            #if targetEnvironment(simulator)
            List {
                NavigationLink(value: "mock") {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("MockDevice")
                                .font(.body)
                                .fontWeight(.medium)
                            Text("Simulator • Connected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Devices")
            .navigationDestination(for: String.self) { _ in
                DeviceDetailView(service: self.service)
            }
            #else
            Group {
                if self.bleManager.bluetoothState != .poweredOn, self.bleManager.bluetoothState != .unknown {
                    ContentUnavailableView {
                        Label("Bluetooth Unavailable", systemImage: "antenna.radiowaves.left.and.right.slash")
                    } description: {
                        Text(self.bluetoothStateMessage)
                    }
                } else {
                    List {
                        ForEach(self.sortedBLEDevices, id: \.identifier) { peripheral in
                            Button {
                                self.bleManager.connect(to: peripheral)
                                self.service.useBLETransport()
                                self.selectedDevice = peripheral.identifier.uuidString
                            } label: {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(self.bleManager.connectedPeripheral?.identifier == peripheral
                                            .identifier ? Color.green : Color.gray.opacity(0.3))
                                        .frame(width: 10, height: 10)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(self.deviceDisplayName(peripheral.name ?? "Unknown"))
                                            .font(.body)
                                            .fontWeight(.medium)
                                        HStack(spacing: 4) {
                                            Text("BLE")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            if self.bleManager.connectedPeripheral?.identifier == peripheral
                                                .identifier
                                            {
                                                Text("• Connected")
                                                    .font(.caption)
                                                    .foregroundColor(.green)
                                            }
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                if self.bleManager.connectedPeripheral?.identifier == peripheral.identifier {
                                    Button(role: .destructive) {
                                        self.bleManager.disconnect()
                                        self.selectedDevice = nil
                                    } label: {
                                        Label("Disconnect", systemImage: "xmark.circle")
                                    }
                                } else {
                                    Button {
                                        self.bleManager.connect(to: peripheral)
                                        self.service.useBLETransport()
                                    } label: {
                                        Label("Connect", systemImage: "link")
                                    }
                                    .tint(.blue)
                                }
                            }
                        }

                        if self.sortedBLEDevices.isEmpty {
                            ContentUnavailableView {
                                Label("No Devices", systemImage: "antenna.radiowaves.left.and.right.slash")
                            } description: {
                                Text("Pull down to scan for nearby LoRaCue devices")
                            }
                        }
                    }
                    .refreshable {
                        self.scan()
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                    }
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            if self.bleManager.connectedPeripheral != nil {
                                Button {
                                    self.bleManager.disconnect()
                                    self.selectedDevice = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                            } else {
                                Button {
                                    self.scan()
                                } label: {
                                    Image(systemName: self.bleManager
                                        .isScanning ? "stop.circle.fill" : "arrow.clockwise")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Devices")
            .navigationDestination(isPresented: Binding(
                get: { self.selectedDevice != nil },
                set: { if !$0 { self.selectedDevice = nil } }
            )) {
                DeviceDetailView(service: self.service)
            }
            #endif
        }
    }

    // MARK: - macOS UI

    @ViewBuilder
    private var macOSDeviceList: some View {
        List(selection: self.$selectedDevice) {
            if !self.sortedBLEDevices.isEmpty {
                Section("BLE Devices") {
                    ForEach(self.sortedBLEDevices, id: \.identifier) { peripheral in
                        self.deviceRowView(for: peripheral)
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
                            isConnected: self.usbManager.isConnected
                        ) {
                            if self.usbManager.isConnected {
                                self.usbManager.disconnect()
                                self.selectedDevice = nil
                            } else {
                                try? self.usbManager.connect(to: path)
                                self.service.useUSBTransport(self.usbManager)
                                self.selectedDevice = path
                            }
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
                    Label(
                        "Scan",
                        systemImage: self.bleManager.isScanning ? "stop.circle.fill" : "arrow.clockwise"
                    )
                }
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            self.scan()
        }
    }

    // MARK: - Helpers

    private var sortedBLEDevices: [CBPeripheral] {
        let all = self.bleManager.discoveredDevices
        return all.filter { ($0.name ?? "").hasPrefix("LoRaCue") }
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
    }

    private var bluetoothStateMessage: String {
        switch self.bleManager.bluetoothState {
        case .poweredOff:
            "Bluetooth is turned off. Please enable it in Settings."
        case .unauthorized:
            "Bluetooth access is not authorized. Please grant permission in Settings → Privacy & Security → Bluetooth."
        case .unsupported:
            "This device does not support Bluetooth."
        case .resetting:
            "Bluetooth is resetting. Please wait."
        default:
            "Bluetooth is not available."
        }
    }

    private func deviceDisplayName(_ name: String) -> String {
        name.replacingOccurrences(of: "LoRaCue-", with: "")
            .replacingOccurrences(of: "LoRaCue", with: "")
    }

    @ViewBuilder
    private func deviceRowView(for peripheral: CBPeripheral) -> some View {
        let isConnected = self.bleManager.connectedPeripheral?.identifier == peripheral.identifier
        DeviceRow(
            name: self.deviceDisplayName(peripheral.name ?? "Unknown"),
            type: "BLE",
            isConnected: isConnected
        ) {
            self.handleDeviceTap(peripheral: peripheral, isConnected: isConnected)
        }
        .tag(peripheral.identifier.uuidString)
    }

    private func handleDeviceTap(peripheral: CBPeripheral, isConnected: Bool) {
        if isConnected {
            self.bleManager.disconnect()
            self.selectedDevice = nil
        } else {
            self.bleManager.connect(to: peripheral)
            self.service.useBLETransport()
            self.selectedDevice = peripheral.identifier.uuidString
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

// MARK: - macOS Device Row

struct DeviceRow: View {
    let name: String
    let type: String
    let isConnected: Bool
    let onTap: () -> Void

    var body: some View {
        HStack {
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

            if self.isConnected {
                Button(action: self.onTap) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Disconnect")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !self.isConnected {
                self.onTap()
            }
        }
    }
}
