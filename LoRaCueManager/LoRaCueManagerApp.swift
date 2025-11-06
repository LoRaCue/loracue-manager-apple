import OSLog
import SwiftUI

@main
struct LoRaCueManagerApp: App {
    @StateObject private var service: LoRaCueService

    init() {
        Logger.ui.info("🚀 App init started")
        let ble = BLEManager()
        Logger.ui.info("✅ BLEManager created in app: \(ble.instanceId)")
        let svc = LoRaCueService(bleManager: ble)
        Logger.ui.info("✅ LoRaCueService created in app")
        _service = StateObject(wrappedValue: svc)
        Logger.ui.info("✅ StateObject initialized")
    }

    var body: some Scene {
        WindowGroup {
            ContentView(service: self.service)
                .frame(minWidth: 900, minHeight: 600)
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
