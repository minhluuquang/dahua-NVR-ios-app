import SwiftUI

struct CameraDetailIdentifier: Identifiable {
    let id: String
    let camera: NVRCamera
    
    init(camera: NVRCamera) {
        self.id = camera.deviceID
        self.camera = camera
    }
}

struct CameraTabView: View {
    @State private var cameras: [NVRCamera] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedCameraDeviceID: String?

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading cameras...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = errorMessage {
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
                                await fetchCamerasRPC()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if cameras.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)

                        Text("No Cameras Found")
                            .font(.title2)
                            .fontWeight(.medium)

                        Text("No cameras are connected to this NVR system.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Refresh") {
                            Task {
                                await fetchCamerasRPC()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    List(cameras) { camera in
                        CameraRowView(camera: camera)
                            .onTapGesture {
                                selectedCameraDeviceID = camera.deviceID
                            }
                    }
                    .refreshable {
                        await fetchCamerasRPC()
                    }
                }
            }
            .navigationTitle("Cameras")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: Binding<CameraDetailIdentifier?>(
                get: {
                    guard let deviceID = selectedCameraDeviceID,
                          let camera = cameras.first(where: { $0.deviceID == deviceID }) else {
                        return nil
                    }
                    return CameraDetailIdentifier(camera: camera)
                },
                set: { _ in
                    selectedCameraDeviceID = nil
                }
            )) { identifier in
                CameraInfoView(camera: identifier.camera)
            }
        }
        .onAppear {
            Task {
                await fetchCamerasRPC()
            }
        }
    }
    
    private func fetchCamerasRPC() async {
        // Prevent concurrent requests
        await MainActor.run {
            guard !isLoading else { return }
            isLoading = true
            errorMessage = nil
        }
        
        // Check if we're still supposed to be loading (might have been cancelled)
        let shouldProceed = await MainActor.run { isLoading }
        guard shouldProceed else { return }
        
        guard let rpcService = AuthenticationManager.shared.rpcService,
              rpcService.hasActiveSession else {
            await MainActor.run {
                isLoading = false
                errorMessage = "No active RPC connection to NVR system."
            }
            return
        }
        
        do {
            let fetchedCameras = try await rpcService.camera.getAllCameras()
            await MainActor.run {
                // Only update if we're still in loading state (not cancelled by another call)
                guard isLoading else { return }
                cameras = fetchedCameras
                isLoading = false
            }
        } catch {
            await MainActor.run {
                guard isLoading else { return }
                isLoading = false
                errorMessage = "Failed to load cameras: \(error.localizedDescription)"
            }
        }
    }
}

struct CameraRowView: View {
    let camera: NVRCamera

    var body: some View {
        HStack {
            Image(systemName: camera.enable ? "camera.fill" : "camera")
                .foregroundColor(camera.enable ? .green : .gray)
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
                Text(camera.enable ? "Online" : "Offline")
                    .font(.caption)
                    .foregroundColor(camera.enable ? .green : .red)

                Text(camera.deviceInfo.deviceType.isEmpty ? "Unknown Device" : camera.deviceInfo.deviceType)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CameraInfoView: View {
    @State private var camera: NVRCamera
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditSheet = false
    
    init(camera: NVRCamera) {
        self._camera = State(initialValue: camera)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Camera Information") {
                    DetailRow(label: "Name", value: camera.name)
                    DetailRow(label: "Device ID", value: camera.deviceID)
                    DetailRow(label: "Channel", value: "\(camera.uniqueChannel)")
                    DetailRow(label: "Status", value: camera.enable ? "Online" : "Offline")
                }

                Section("Device Details") {
                    DetailRow(label: "IP Address", value: camera.deviceInfo.address)
                    DetailRow(label: "HTTP Port", value: "\(camera.deviceInfo.httpPort)")
                    DetailRow(label: "RTSP Port", value: "\(camera.deviceInfo.rtspPort)")
                    DetailRow(label: "Protocol", value: camera.deviceInfo.protocolType)
                    DetailRow(label: "Device Type", value: camera.deviceInfo.deviceType.isEmpty ? "Unknown" : camera.deviceInfo.deviceType)
                    DetailRow(label: "Serial Number", value: camera.deviceInfo.serialNo.isEmpty ? "N/A" : camera.deviceInfo.serialNo)
                    DetailRow(label: "MAC Address", value: camera.deviceInfo.mac.isEmpty ? "N/A" : camera.deviceInfo.mac)
                    DetailRow(label: "Software Version", value: camera.deviceInfo.softwareVersion.isEmpty ? "N/A" : camera.deviceInfo.softwareVersion)
                }
            }
            .navigationTitle("Camera Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showingEditSheet = true
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                CameraEditSheet(camera: $camera)
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    CameraTabView()
}
