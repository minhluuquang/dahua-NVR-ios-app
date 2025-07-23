import SwiftUI

struct CameraDetailsView: View {
    let cameraId: UUID
    @EnvironmentObject var store: CameraStore
    @State private var showingEditSheet = false
    
    init(camera: NVRCamera) {
        self.cameraId = camera.id
    }
    
    private var camera: NVRCamera? {
        store.findCamera(by: cameraId)
    }

    var body: some View {
        Group {
            if let camera = camera {
                Form {
                    Section("Camera Information") {
                        DetailRow(label: "Channel", value: "\(camera.uniqueChannel)")
                        DetailRow(label: "Status", value: camera.showStatus ?? "Unknown")
                        DetailRow(label: "IP Address", value: camera.deviceInfo.address)
                        DetailRow(label: "Port", value: "\(camera.deviceInfo.port)")
                        DetailRow(label: "Device Name", value: camera.deviceInfo.name)
                        DetailRow(label: "Remote CH No.", value: "\(camera.deviceInfo.videoInputChannels)")
                        DetailRow(label: "Manufacturer", value: camera.deviceInfo.protocolType.isEmpty ? "N/A" : camera.deviceInfo.protocolType)
                        DetailRow(label: "Camera Name", value: camera.name)
                        DetailRow(label: "Type", value: camera.deviceInfo.deviceType.isEmpty ? "Unknown" : camera.deviceInfo.deviceType)
                        DetailRow(label: "SN", value: camera.deviceInfo.serialNo.isEmpty ? "N/A" : camera.deviceInfo.serialNo)
                    }
                }
                .navigationTitle("Camera Details")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Edit") {
                            showingEditSheet = true
                        }
                    }
                }
                .sheet(isPresented: $showingEditSheet) {
                    if let currentCamera = self.camera {
                        CameraEditSheet(camera: .constant(currentCamera))
                    }
                }
            } else {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    Text("Camera not found")
                        .font(.title2)
                        .fontWeight(.medium)
                    Text("This camera may have been removed or is no longer available.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .navigationTitle("Camera Details")
                .navigationBarTitleDisplayMode(.large)
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
    NavigationView {
        CameraDetailsView(camera: NVRCamera(
            controlID: "1",
            name: "Front Door Camera",
            enable: true,
            deviceID: "CAM_001",
            type: "IPC",
            videoStream: "Main",
            uniqueChannel: 1,
            deviceInfo: DeviceInfo(
                enable: true,
                encryptStream: 0,
                address: "192.168.1.100",
                port: 37777,
                usePreSecret: 0,
                userName: "admin",
                password: "password123",
                protocolType: "DAHUA-TCP",
                videoInputChannels: 1,
                audioInputChannels: 1,
                deviceClass: "IPC",
                deviceType: "IPC-HFW4431R-Z",
                httpPort: 80,
                httpsPort: 443,
                rtspPort: 554,
                name: "Front Door Camera",
                machineAddress: "",
                serialNo: "ABC123456",
                vendorAbbr: "Dahua",
                hardID: "12345",
                softwareVersion: "2.800.0000000.25.R",
                activationTime: "2023-01-01 00:00:00",
                nodeType: "camera",
                mac: "00:11:22:33:44:55",
                oemVendor: "Dahua"
            )
        ))
    }
}