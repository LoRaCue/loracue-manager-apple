import CoreBluetooth
import OSLog
import SwiftUI
#if os(macOS)
import AppKit
#endif

// swiftlint:disable:next type_body_length
struct DeviceListView: View {
    @ObservedObject var service: LoRaCueService
    @StateObject private var viewModel: DeviceListViewModel
    @State private var selectedDevice: String?
    @State private var hasScanned = false
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
            .navigationTitle("LoRaCue Manager")
            .navigationBarTitleDisplayMode(.large)
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
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                        .font(.title2)
                                        .foregroundStyle(self.bleManager.connectedPeripheral?.identifier == peripheral
                                            .identifier ? .green : .blue)
                                        .frame(width: 32)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(self.deviceDisplayName(peripheral.name ?? "Unknown"))
                                            .font(.headline)

                                        if let advData = self.bleManager.getAdvertisementData(for: peripheral) {
                                            (Text(advData.model ?? "")
                                                .foregroundStyle(.secondary) +
                                                Text(advData.version.map { " \($0)" } ?? "")
                                                .foregroundStyle(.tertiary))
                                                .font(.caption)
                                        }

                                        if self.bleManager.connectedPeripheral?.identifier == peripheral.identifier {
                                            HStack(spacing: 4) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.caption2)
                                                Text("Connected")
                                                    .font(.caption2)
                                            }
                                            .foregroundStyle(.green)
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
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
                                VStack(spacing: 16) {
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                        .font(.system(size: 48))
                                        .foregroundColor(.secondary)

                                    if self.hasScanned {
                                        Text("No Devices Found")
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                    }
                                }
                            } description: {
                                Text("Pull down to scan for nearby devices")
                                    .font(.body)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .refreshable {
                        self.scan()
                        self.hasScanned = true
                        try? await Task.sleep(nanoseconds: 10_000_000_000) // 10s scan
                        self.bleManager.stopScanning()
                    }
                    #if !os(iOS)
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
                    #endif
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image("ToolbarIcon")
                            .resizable()
                            .frame(width: 28, height: 28)
                            .cornerRadius(6)
                        Text("LoRaCue Manager")
                            .font(.headline)
                    }
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { self.selectedDevice != nil },
                set: { if !$0 { self.selectedDevice = nil } }
            )) {
                DeviceDetailView(service: self.service)
            }
            .onReceive(self.bleManager.$connectionState) { state in
                if state == .disconnected {
                    self.selectedDevice = nil
                }
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
                            detail: path,
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
                    ContentUnavailableView {
                        VStack(spacing: 16) {
                            #if os(macOS)
                            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                                .resizable()
                                .frame(width: 80, height: 80)
                                .cornerRadius(18)
                            #else
                            Image(uiImage: UIImage(named: "AppIcon") ?? UIImage())
                                .resizable()
                                .frame(width: 80, height: 80)
                                .cornerRadius(18)
                            #endif

                            Text("LoRaCue Manager")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                    } description: {
                        Text("No devices found\nClick Scan to search for LoRaCue devices")
                            .multilineTextAlignment(.center)
                    }
                }
                #else
                ContentUnavailableView {
                    VStack(spacing: 16) {
                        #if os(macOS)
                        Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                            .resizable()
                            .frame(width: 80, height: 80)
                            .cornerRadius(18)
                        #else
                        Image(uiImage: UIImage(named: "AppIcon") ?? UIImage())
                            .resizable()
                            .frame(width: 80, height: 80)
                            .cornerRadius(18)
                        #endif

                        Text("LoRaCue Manager")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                } description: {
                    Text("No devices found\nClick Scan to search for LoRaCue devices")
                        .multilineTextAlignment(.center)
                }
                #endif
            }
        }
        .navigationTitle("LoRaCue Manager")
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
        var all = self.bleManager.discoveredDevices

        // Always include connected device even if not advertising
        if let connected = self.bleManager.connectedPeripheral,
           !all.contains(where: { $0.identifier == connected.identifier })
        {
            all.append(connected)
        }

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
            .replacingOccurrences(of: "LoRaCue ", with: "")
    }

    @ViewBuilder
    private func deviceRowView(for peripheral: CBPeripheral) -> some View {
        let isConnected = self.bleManager.connectedPeripheral?.identifier == peripheral.identifier
        let advData = self.bleManager.getAdvertisementData(for: peripheral)

        DeviceRow(
            name: advData?.model ?? self.deviceDisplayName(peripheral.name ?? "Unknown"),
            type: "BLE",
            detail: advData?.version ?? "",
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
            self.hasScanned = true
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
    let detail: String
    let isConnected: Bool
    let onTap: () -> Void

    private var icon: String {
        switch self.type {
        case "BLE": "antenna.radiowaves.left.and.right"
        case "USB": "cable.connector"
        case "Mock": "cpu"
        default: "questionmark"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: self.icon)
                .font(.title2)
                .foregroundStyle(self.isConnected ? .green : .blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(self.name)
                    .font(.headline)

                Text(self.detail)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)

                if self.isConnected {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                        Text("Connected")
                            .font(.caption2)
                    }
                    .foregroundStyle(.green)
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
