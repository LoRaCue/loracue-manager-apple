import SwiftUI

struct GitHubSection: View {
    let releases: [GitHubRelease]
    let manifests: [FirmwareManifest]
    let isLoading: Bool
    let onSelectRelease: (GitHubRelease) async -> Void
    let onSelectManifest: (FirmwareManifest) -> Void

    var body: some View {
        Section {
            if self.isLoading {
                ProgressView()
            } else if self.releases.isEmpty {
                Text("No releases found")
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(self.releases) { release in
                        Button {
                            Task { await self.onSelectRelease(release) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.blue)
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(release.name)
                                        .font(.headline)
                                    Text(release.tagName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if release.prerelease {
                                    Text("PRE")
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }
                            .padding(12)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }

        if !self.manifests.isEmpty {
            Section {
                VStack(spacing: 8) {
                    ForEach(self.manifests, id: \.model) { manifest in
                        Button {
                            self.onSelectManifest(manifest)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "cpu.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.green)
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(manifest.model)
                                        .font(.headline)
                                    Text("\(manifest.boardName) • \(manifest.version)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                            .padding(12)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
