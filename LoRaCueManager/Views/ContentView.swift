import OSLog
import SwiftUI

struct ContentView: View {
    let service: LoRaCueService

    private enum Constants {
        static let sidebarMinWidth: CGFloat = 220
        static let sidebarIdealWidth: CGFloat = 250
        static let sidebarMaxWidth: CGFloat = 400
    }

    var body: some View {
        Logger.ui.info(
            """
            ContentView body: bleManager=\(self.service.bleManager.instanceId)
            """
        )

        #if os(macOS)
        return NavigationSplitView {
            DeviceListView(service: self.service)
                .navigationSplitViewColumnWidth(
                    min: Constants.sidebarMinWidth,
                    ideal: Constants.sidebarIdealWidth,
                    max: Constants.sidebarMaxWidth
                )
        } detail: {
            DeviceDetailView(service: self.service)
        }
        #else
        return DeviceListView(service: self.service)
        #endif
    }
}
