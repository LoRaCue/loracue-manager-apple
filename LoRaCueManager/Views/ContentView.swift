import OSLog
import SwiftUI

struct ContentView: View {
    let service: LoRaCueService

    var body: some View {
        Logger.ui.info(
            """
            ContentView body: service=\(self.service.instanceId) \
            bleManager=\(self.service.bleManager?.instanceId ?? "nil")
            """
        )

        return NavigationSplitView {
            DeviceListView(service: self.service)
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 400)
        } detail: {
            DeviceDetailView(service: self.service)
        }
    }
}
