import SwiftUI

struct CameraTabView: View {
    @StateObject private var cameraService = CameraAPIService()
    @State private var selectedCamera: NVRCamera?
    @State private var showingCameraDetail = false

    var body: some View {
        NavigationView {
            Group {
                if cameraService.isLoading {
                    ProgressView("Loading cameras...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = cameraService.errorMessage {
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
                                await cameraService.fetchCameras()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if cameraService.cameras.isEmpty {
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
                                await cameraService.fetchCameras()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    List(cameraService.cameras) { camera in
                        CameraRowView(camera: camera)
                            .onTapGesture {
                                selectedCamera = camera
                                showingCameraDetail = true
                            }
                    }
                    .refreshable {
                        await cameraService.fetchCameras()
                    }
                }
            }
            .navigationTitle("Cameras")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        Task {
                            await cameraService.fetchCameras()
                        }
                    }
                    .disabled(cameraService.isLoading)
                }
            }
            .sheet(isPresented: $showingCameraDetail) {
                if let camera = selectedCamera {
                    CameraInfoView(camera: camera)
                }
            }
        }
        .onAppear {
            Task {
                await cameraService.fetchCameras()
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

                Text(camera.deviceInfo.deviceType)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CameraInfoView: View {
    let camera: NVRCamera
    @Environment(\.dismiss) private var dismiss
    @State private var editingIPAddress = false
    @State private var newIPAddress = ""
    @State private var isUpdating = false
    @State private var updateError: String?
    @StateObject private var cameraService = CameraAPIService()

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
                    if editingIPAddress {
                        HStack {
                            Text("IP Address")
                            Spacer()
                            TextField("IP Address", text: $newIPAddress)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numbersAndPunctuation)
                                .disabled(isUpdating)
                        }
                    } else {
                        DetailRow(label: "IP Address", value: camera.deviceInfo.address)
                    }

                    DetailRow(label: "HTTP Port", value: "\(camera.deviceInfo.httpPort)")
                    DetailRow(label: "Protocol", value: camera.deviceInfo.protocolType)
                    DetailRow(label: "Device Type", value: camera.deviceInfo.deviceType)
                    DetailRow(label: "Serial Number", value: camera.deviceInfo.serialNo)
                    DetailRow(label: "MAC Address", value: camera.deviceInfo.mac)
                    DetailRow(label: "Software Version", value: camera.deviceInfo.softwareVersion)
                }

                if isUpdating {
                    Section {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Updating camera information...")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if let error = updateError {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
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
                    if editingIPAddress {
                        HStack {
                            Button("Cancel") {
                                cancelEditingIPAddress()
                            }
                            .disabled(isUpdating)

                            Button("Save") {
                                saveIPAddress()
                            }
                            .disabled(
                                isUpdating || newIPAddress.isEmpty
                                    || newIPAddress == camera.deviceInfo.address)
                        }
                    } else {
                        Button("Edit") {
                            startEditingIPAddress()
                        }
                        .disabled(isUpdating)
                    }
                }
            }
        }
    }

    private func startEditingIPAddress() {
        newIPAddress = camera.deviceInfo.address
        editingIPAddress = true
        updateError = nil
    }

    private func cancelEditingIPAddress() {
        editingIPAddress = false
        newIPAddress = ""
        updateError = nil
    }

    private func saveIPAddress() {
        guard !newIPAddress.isEmpty else { return }

        Task {
            await MainActor.run {
                isUpdating = true
                updateError = nil
            }

            do {
                try await cameraService.updateCameraIP(camera: camera, newIPAddress: newIPAddress)

                await MainActor.run {
                    isUpdating = false
                    editingIPAddress = false
                }
            } catch {
                await MainActor.run {
                    isUpdating = false
                    updateError = "Failed to update camera IP: \(error.localizedDescription)"
                }
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
