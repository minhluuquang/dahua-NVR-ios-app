import SwiftUI

struct CameraTabView: View {
    @EnvironmentObject var store: CameraStore

    var body: some View {
        NavigationView {
            Group {
                if store.isLoading {
                    ProgressView("Loading cameras...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = store.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)

                        Text("Error Loading Cameras")
                            .font(.title2)
                            .fontWeight(.medium)

                        Text(errorMessage)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Retry") {
                            Task {
                                await store.fetchCamerasRPC()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if store.cameras.filter({ $0.enable }).isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)

                        Text("No Active Cameras")
                            .font(.title2)
                            .fontWeight(.medium)

                        Text("No enabled cameras found in this NVR system.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Refresh") {
                            Task {
                                await store.fetchCamerasRPC()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    List(store.cameras.filter { $0.enable }) { camera in
                        NavigationLink(destination: CameraDetailsView(camera: camera)) {
                            CameraRowView(camera: camera)
                        }
                    }
                    .refreshable {
                        await store.fetchCamerasRPC()
                    }
                }
            }
            .navigationTitle("Cameras")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            Task {
                await store.fetchCamerasRPC()  
            }
        }
    }
}

struct CameraRowView: View {
    let camera: NVRCamera

    private func statusColor(for status: String?) -> Color {
        switch status {
        case "Connected":
            return .green
        case "Unconnect":
            return .red
        default:
            return .gray
        }
    }

    var body: some View {
        HStack {
            Image(systemName: camera.showStatus == "Connected" ? "camera.fill" : "camera")
                .foregroundColor(statusColor(for: camera.showStatus))
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text(camera.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(camera.deviceInfo.address)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("Channel \(camera.uniqueChannel)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(camera.showStatus ?? "Unknown")
                    .font(.caption)
                    .foregroundColor(statusColor(for: camera.showStatus))

                Text(camera.deviceInfo.deviceType.isEmpty ? "Unknown Device" : camera.deviceInfo.deviceType)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}


#Preview {
    CameraTabView()
}
