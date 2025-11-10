import SwiftUI

struct FirmwareSourceCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let tag: Int
    @Binding var selectedTab: Int

    var body: some View {
        Button {
            self.selectedTab = self.tag
        } label: {
            VStack(spacing: 8) {
                Image(systemName: self.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(self.selectedTab == self.tag ? .white : .blue)

                VStack(spacing: 2) {
                    Text(self.title)
                        .font(.headline)
                        .foregroundStyle(self.selectedTab == self.tag ? .white : .primary)

                    Text(self.subtitle)
                        .font(.caption)
                        .foregroundStyle(self.selectedTab == self.tag ? .white.opacity(0.8) : .secondary)
                }
            }
            #if os(iOS)
            .frame(width: 200)
            #else
            .frame(maxWidth: .infinity)
            #endif
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(self.selectedTab == self.tag ? Color.accentColor : Color.gray.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(self.selectedTab == self.tag ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
