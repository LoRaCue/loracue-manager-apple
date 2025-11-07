import OSLog
import SwiftUI

@main
struct LoRaCueManagerApp: App {
    @StateObject private var service: LoRaCueService

    init() {
        Logger.ui.info("🚀 App init started")

        #if targetEnvironment(simulator)
        Logger.ui.info("📱 Using MockTransport for simulator")
        let mockTransport = MockTransport()
        let dummyBLE = BLEManager()
        let svc = LoRaCueService(transport: mockTransport, bleManager: dummyBLE)
        #else
        let ble = BLEManager()
        Logger.ui.info("✅ BLEManager created in app: \(ble.instanceId)")
        let svc = LoRaCueService(bleManager: ble)
        #endif

        Logger.ui.info("✅ LoRaCueService created in app")
        _service = StateObject(wrappedValue: svc)
        Logger.ui.info("✅ StateObject initialized")
    }

    var body: some Scene {
        WindowGroup {
            ContentView(service: self.service)
            #if os(macOS)
                .frame(minWidth: 900, minHeight: 600)
            #else
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    Logger.ui.info("📱 App going to background, disconnecting BLE")
                    self.service.bleManager.disconnect()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    Logger.ui.info("📱 App became active, starting BLE scan")
                    self.service.bleManager.startScanning()
                }
            #endif
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}

struct SettingsView: View {
    var body: some View {
        TabView {
            Form {
                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Build", value: "1")
                }
            }
            .tabItem {
                Label("General", systemImage: "gear")
            }
        }
        .frame(width: 400, height: 300)
    }
}
