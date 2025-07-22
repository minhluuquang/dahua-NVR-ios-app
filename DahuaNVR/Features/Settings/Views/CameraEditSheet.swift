import SwiftUI
import os.log

struct CameraEditSheet: View {
    @Binding var camera: NVRCamera
    @State private var editableCamera: EditableCameraData
    @Environment(\.dismiss) private var dismiss
    @State private var showingCancelAlert = false
    
    private let logger = Logger(subsystem: "com.minhlq.DahuaNVR", category: "CameraEditSheet")
    
    init(camera: Binding<NVRCamera>) {
        self._camera = camera
        self._editableCamera = State(initialValue: EditableCameraData(from: camera.wrappedValue))
    }
    
    var body: some View {
        NavigationView {
            Form {
                deviceSection
                networkSection
                protocolSection
                authenticationsSection
            }
            .navigationTitle("Edit Camera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if hasChanges {
                            showingCancelAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(!isFormValid)
                }
            }
            .alert("Unsaved Changes", isPresented: $showingCancelAlert) {
                Button("Discard Changes", role: .destructive) {
                    dismiss()
                }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
        }
    }
    
    // MARK: - Form Sections
    
    private var deviceSection: some View {
        Section("Device Information") {
            HStack {
                Text("Name")
                Spacer()
                TextField("Device Name", text: $editableCamera.name)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.plain)
            }
            
            HStack {
                Text("Device ID")
                Spacer()
                TextField("Device ID", text: $editableCamera.deviceID)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.plain)
            }
            
            HStack {
                Text("Channel")
                Spacer()
                TextField("Channel", value: $editableCamera.uniqueChannel, format: .number)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.plain)
                    .keyboardType(.numberPad)
            }
            
            Toggle("Enable", isOn: $editableCamera.enable)
        }
    }
    
    private var networkSection: some View {
        Section("Network Settings") {
            HStack {
                Text("IP Address")
                Spacer()
                TextField("192.168.1.100", text: $editableCamera.ipAddress)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.plain)
                    .keyboardType(.decimalPad)
            }
            
            HStack {
                Text("HTTP Port")
                Spacer()
                TextField("Port", value: $editableCamera.httpPort, format: .number)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.plain)
                    .keyboardType(.numberPad)
            }
            
            HStack {
                Text("RTSP Port")
                Spacer()
                TextField("RTSP Port", value: $editableCamera.rtspPort, format: .number)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.plain)
                    .keyboardType(.numberPad)
            }
            
            HStack {
                Text("MAC Address")
                Spacer()
                TextField("00:00:00:00:00:00", text: $editableCamera.macAddress)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.plain)
            }
        }
    }
    
    private var protocolSection: some View {
        Section("Protocol Settings") {
            HStack {
                Text("Protocol Type")
                Spacer()
                TextField("Protocol", text: $editableCamera.protocolType)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.plain)
            }
            
            HStack {
                Text("Device Type")
                Spacer()
                TextField("Device Type", text: $editableCamera.deviceType)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.plain)
            }
            
            HStack {
                Text("Manufacturer")
                Spacer()
                TextField("Manufacturer", text: $editableCamera.manufacturer)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.plain)
            }
        }
    }
    
    private var authenticationsSection: some View {
        Section("Authentication") {
            HStack {
                Text("Username")
                Spacer()
                TextField("Username", text: $editableCamera.username)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            
            HStack {
                Text("Password")
                Spacer()
                SecureField("Password", text: $editableCamera.password)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.plain)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var hasChanges: Bool {
        let original = EditableCameraData(from: camera)
        return editableCamera != original
    }
    
    private var isFormValid: Bool {
        !editableCamera.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !editableCamera.deviceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !editableCamera.ipAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        editableCamera.httpPort >= 0 &&
        editableCamera.httpPort <= 65535 &&
        editableCamera.rtspPort >= 0 &&
        editableCamera.rtspPort <= 65535
    }
    
    // MARK: - Actions
    
    private func saveChanges() {
        Task {
            await saveChangesAsync()
        }
    }
    
    @MainActor
    private func saveChangesAsync() async {
        #if DEBUG
        logger.debug("💾 Saving camera changes via RPC")
        #endif
        
        guard let rpcService = AuthenticationManager.shared.rpcService else {
            #if DEBUG
            logger.error("❌ No RPC service available for camera update")
            #endif
            return
        }
        
        do {
            // Create the camera configuration
            let cameraConfig = createCameraConfigDict()
            
            #if DEBUG
            logger.debug("📤 Sending camera config via RPC ConfigManager")
            #endif
            
            // Update camera configuration using RPC ConfigManager
            let success = try await rpcService.configManager.setConfig(
                name: "LogicDeviceManager", 
                table: cameraConfig, 
                channel: editableCamera.uniqueChannel
            )
            
            if success {
                #if DEBUG
                logger.debug("✅ Camera configuration updated successfully")
                #endif
                
                // Update the binding (for UI consistency)
                updateCameraBinding()
                
                // Dismiss the sheet
                dismiss()
            } else {
                #if DEBUG
                logger.error("❌ Failed to update camera configuration")
                #endif
            }
        } catch {
            #if DEBUG
            logger.error("❌ RPC camera update error: \(error.localizedDescription)")
            #endif
        }
    }
    
    private func createCameraConfigDict() -> [String: Any] {
        return [
            "camera": [
                editableCamera.uniqueChannel: [
                    "Enable": editableCamera.enable,
                    "DeviceID": editableCamera.deviceID,
                    "DeviceInfo": [
                        "Enable": editableCamera.enable,
                        "Address": editableCamera.ipAddress,
                        "HttpPort": editableCamera.httpPort,
                        "RtspPort": editableCamera.rtspPort,
                        "UserName": editableCamera.username,
                        "Password": editableCamera.password,
                        "ProtocolType": editableCamera.protocolType,
                        "DeviceType": editableCamera.deviceType,
                        "Name": editableCamera.name,
                        "Mac": editableCamera.macAddress,
                        "VendorAbbr": editableCamera.manufacturer
                    ]
                ]
            ]
        ]
    }
    
    private func createCameraJSON() -> String {
        let jsonObject: [String: Any] = [
            "action": "updateCamera",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "camera": [
                "controlID": editableCamera.controlID,
                "name": editableCamera.name,
                "enable": editableCamera.enable,
                "deviceID": editableCamera.deviceID,
                "uniqueChannel": editableCamera.uniqueChannel,
                "deviceInfo": [
                    "enable": editableCamera.enable,
                    "address": editableCamera.ipAddress,
                    "httpPort": editableCamera.httpPort,
                    "rtspPort": editableCamera.rtspPort,
                    "userName": editableCamera.username,
                    "password": editableCamera.password,
                    "protocolType": editableCamera.protocolType,
                    "deviceType": editableCamera.deviceType,
                    "name": editableCamera.name,
                    "mac": editableCamera.macAddress,
                    "vendorAbbr": editableCamera.manufacturer,
                    "serialNo": camera.deviceInfo.serialNo,
                    "softwareVersion": camera.deviceInfo.softwareVersion,
                    "port": camera.deviceInfo.port,
                    "encryptStream": camera.deviceInfo.encryptStream,
                    "usePreSecret": camera.deviceInfo.usePreSecret,
                    "videoInputChannels": camera.deviceInfo.videoInputChannels,
                    "audioInputChannels": camera.deviceInfo.audioInputChannels,
                    "deviceClass": camera.deviceInfo.deviceClass,
                    "httpsPort": camera.deviceInfo.httpsPort,
                    "machineAddress": camera.deviceInfo.machineAddress,
                    "hardID": camera.deviceInfo.hardID,
                    "activationTime": camera.deviceInfo.activationTime,
                    "nodeType": camera.deviceInfo.nodeType,
                    "oemVendor": camera.deviceInfo.oemVendor
                ]
            ]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "{\"error\": \"JSON serialization failed\"}"
        } catch {
            #if DEBUG
            logger.error("❌ JSON serialization failed: \(error.localizedDescription)")
            #endif
            return "{\"error\": \"JSON serialization failed: \(error.localizedDescription)\"}"
        }
    }
    
    private func updateCameraBinding() {
        // Create updated NVRCamera with the edited data
        let updatedDeviceInfo = DeviceInfo(
            enable: editableCamera.enable,
            encryptStream: camera.deviceInfo.encryptStream,
            address: editableCamera.ipAddress,
            port: camera.deviceInfo.port,
            usePreSecret: camera.deviceInfo.usePreSecret,
            userName: editableCamera.username,
            password: editableCamera.password,
            protocolType: editableCamera.protocolType,
            videoInputChannels: camera.deviceInfo.videoInputChannels,
            audioInputChannels: camera.deviceInfo.audioInputChannels,
            deviceClass: camera.deviceInfo.deviceClass,
            deviceType: editableCamera.deviceType,
            httpPort: editableCamera.httpPort,
            httpsPort: camera.deviceInfo.httpsPort,
            rtspPort: editableCamera.rtspPort,
            name: editableCamera.name,
            machineAddress: camera.deviceInfo.machineAddress,
            serialNo: camera.deviceInfo.serialNo,
            vendorAbbr: editableCamera.manufacturer,
            hardID: camera.deviceInfo.hardID,
            softwareVersion: camera.deviceInfo.softwareVersion,
            activationTime: camera.deviceInfo.activationTime,
            nodeType: camera.deviceInfo.nodeType,
            mac: editableCamera.macAddress,
            oemVendor: camera.deviceInfo.oemVendor
        )
        
        camera = NVRCamera(
            controlID: editableCamera.controlID,
            name: editableCamera.name,
            enable: editableCamera.enable,
            deviceID: editableCamera.deviceID,
            type: camera.type,
            videoStream: camera.videoStream,
            uniqueChannel: editableCamera.uniqueChannel,
            deviceInfo: updatedDeviceInfo
        )
    }
}

// MARK: - Supporting Data Structure

struct EditableCameraData: Equatable {
    var controlID: String
    var name: String
    var enable: Bool
    var deviceID: String
    var uniqueChannel: Int
    var ipAddress: String
    var httpPort: Int
    var rtspPort: Int
    var username: String
    var password: String
    var protocolType: String
    var deviceType: String
    var macAddress: String
    var manufacturer: String
    
    init(from camera: NVRCamera) {
        self.controlID = camera.controlID
        self.name = camera.name
        self.enable = camera.enable
        self.deviceID = camera.deviceID
        self.uniqueChannel = camera.uniqueChannel
        self.ipAddress = camera.deviceInfo.address
        self.httpPort = camera.deviceInfo.httpPort
        self.rtspPort = camera.deviceInfo.rtspPort
        self.username = camera.deviceInfo.userName
        self.password = camera.deviceInfo.password
        self.protocolType = camera.deviceInfo.protocolType
        self.deviceType = camera.deviceInfo.deviceType
        self.macAddress = camera.deviceInfo.mac
        self.manufacturer = camera.deviceInfo.vendorAbbr
    }
    
    static func == (lhs: EditableCameraData, rhs: EditableCameraData) -> Bool {
        return lhs.controlID == rhs.controlID &&
               lhs.name == rhs.name &&
               lhs.enable == rhs.enable &&
               lhs.deviceID == rhs.deviceID &&
               lhs.uniqueChannel == rhs.uniqueChannel &&
               lhs.ipAddress == rhs.ipAddress &&
               lhs.httpPort == rhs.httpPort &&
               lhs.rtspPort == rhs.rtspPort &&
               lhs.username == rhs.username &&
               lhs.password == rhs.password &&
               lhs.protocolType == rhs.protocolType &&
               lhs.deviceType == rhs.deviceType &&
               lhs.macAddress == rhs.macAddress &&
               lhs.manufacturer == rhs.manufacturer
    }
}

#Preview {
    @Previewable @State var previewCamera = NVRCamera(
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
    )
    
    return CameraEditSheet(camera: $previewCamera)
}
