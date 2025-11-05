import SwiftUI

@main
struct LoRaCueManagerApp: App {
    @StateObject private var bleManager = BLEManager()
    @StateObject private var service: LoRaCueService

    init() {
        let ble = BLEManager()
        let svc = LoRaCueService(bleManager: ble)
        _bleManager = StateObject(wrappedValue: ble)
        _service = StateObject(wrappedValue: svc)
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
