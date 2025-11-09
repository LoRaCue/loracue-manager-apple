import OSLog
import SwiftUI

struct ContentView: View {
    let service: LoRaCueService

    var body: some View {
        Logger.ui.info(
            """
            ContentView body: bleManager=\(self.service.bleManager.instanceId)
            """
        )

        #if os(macOS)
        return NavigationSplitView {
            DeviceListView(service: self.service)
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 400)
        } detail: {
            DeviceDetailView(service: self.service)
        }
        #else
        return DeviceListView(service: self.service)
        #endif
    }
}
