import SwiftUI
import os.log

struct CameraEditSheet: View {
    @Binding var camera: NVRCamera
    @State private var editableCamera: EditableCameraData
    @EnvironmentObject var store: CameraStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingCancelAlert = false
    @State private var availableChannels: [Int] = []
    @State private var isLoadingChannels = false
    @State private var isPasswordFieldFocused = false
    @State private var temporaryPassword = ""
    @State private var isSaving = false
    @State private var saveError: String?
    @FocusState private var focusedField: Field?
    
    private let logger = Logger(subsystem: "com.minhlq.DahuaNVR", category: "CameraEditSheet")
    
    enum Field: Hashable {
        case password
    }
    
    init(camera: Binding<NVRCamera>) {
        self._camera = camera
        self._editableCamera = State(initialValue: EditableCameraData(from: camera.wrappedValue))
    }
    
    var body: some View {
        NavigationView {
            Form {
                channelSection
                manufacturerSection
                networkSection
                authenticationSection
                channelConfigSection
                decodeStrategySection
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
                    Button(action: saveChanges) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text("Save")
                        }
                    }
                    .disabled(!isFormValid || isSaving)
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
            .alert("Save Error", isPresented: .constant(saveError != nil)) {
                Button("OK") {
                    saveError = nil
                }
            } message: {
                Text(saveError ?? "An unknown error occurred")
            }
        }
        .onAppear {
            Task {
                await loadAvailableChannels()
            }
        }
    }
    
    // MARK: - Form Sections
    
    private var channelSection: some View {
        Section("Channel") {
            if isLoadingChannels {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading available channels...")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            } else if availableChannels.isEmpty {
                Text("No available channels")
                    .foregroundColor(.secondary)
            } else {
                Picker("Channel", selection: $editableCamera.uniqueChannel) {
                    ForEach(availableChannels, id: \.self) { channel in
                        Text("Channel \(channel)").tag(channel)
                    }
                }
            }
        }
    }
    
    private var manufacturerSection: some View {
        Section("Manufacturer") {
            Picker("Manufacturer", selection: $editableCamera.manufacturer) {
                Text("Private").tag("Private")
                Text("ONVIF").tag("ONVIF")
                Text("Custom").tag("Custom")
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var networkSection: some View {
        Section("Network") {
            HStack {
                Text("IP Address")
                Spacer()
                TextField("192.168.1.100", text: $editableCamera.ipAddress)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.plain)
                    .keyboardType(.decimalPad)
            }
            
            HStack {
                Text("TCP Port")
                Spacer()
                TextField("Port", value: $editableCamera.httpPort, format: .number)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.plain)
                    .keyboardType(.numberPad)
            }
        }
    }
    
    private var authenticationSection: some View {
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
                if focusedField == .password {
                    SecureField("", text: $temporaryPassword)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .password)
                        .onChange(of: temporaryPassword) { _, newValue in
                            editableCamera.password = newValue
                        }
                } else {
                    SecureField("", text: .constant("••••••••"))
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.plain)
                        .disabled(true)
                        .onTapGesture {
                            temporaryPassword = ""
                            focusedField = .password
                        }
                }
            }
        }
    }
    
    private var channelConfigSection: some View {
        Section("Channel Configuration") {
            HStack {
                Text("Total Channels")
                Spacer()
                TextField("Channels", value: $editableCamera.totalChannels, format: .number)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.plain)
                    .keyboardType(.numberPad)
            }
            
            HStack {
                Text("Remote CH No.")
                Spacer()
                TextField("Remote Channel", value: $editableCamera.remoteChannelNo, format: .number)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.plain)
                    .keyboardType(.numberPad)
            }
        }
    }
    
    private var decodeStrategySection: some View {
        Section("Decode Strategy") {
            Picker("Decode Strategy", selection: $editableCamera.decodeStrategy) {
                Text("General").tag("General")
                Text("Realtime").tag("Realtime")
                Text("Fluent").tag("Fluent")
            }
            .pickerStyle(.segmented)
        }
    }
    
    // MARK: - Computed Properties
    
    private var hasChanges: Bool {
        let original = EditableCameraData(from: camera)
        // Compare all fields except password
        return original.controlID != editableCamera.controlID ||
               original.name != editableCamera.name ||
               original.enable != editableCamera.enable ||
               original.deviceID != editableCamera.deviceID ||
               original.uniqueChannel != editableCamera.uniqueChannel ||
               original.ipAddress != editableCamera.ipAddress ||
               original.httpPort != editableCamera.httpPort ||
               original.rtspPort != editableCamera.rtspPort ||
               original.username != editableCamera.username ||
               original.protocolType != editableCamera.protocolType ||
               original.deviceType != editableCamera.deviceType ||
               original.macAddress != editableCamera.macAddress ||
               original.manufacturer != editableCamera.manufacturer ||
               original.totalChannels != editableCamera.totalChannels ||
               original.remoteChannelNo != editableCamera.remoteChannelNo ||
               original.decodeStrategy != editableCamera.decodeStrategy ||
               !editableCamera.password.isEmpty // Only consider password changed if user entered something
    }
    
    private var isFormValid: Bool {
        !editableCamera.ipAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        editableCamera.httpPort >= 0 &&
        editableCamera.httpPort <= 65535 &&
        editableCamera.totalChannels > 0 &&
        editableCamera.remoteChannelNo >= 0
    }
    
    // MARK: - Actions
    
    private func loadAvailableChannels() async {
        await MainActor.run {
            isLoadingChannels = true
        }
        
        // Use cameras from the store if available, otherwise fetch them
        let cameras: [NVRCamera]
        if store.cameras.isEmpty {
            await store.refresh()
            cameras = store.cameras
        } else {
            cameras = store.cameras
        }
        
        let onlineChannels = cameras
            .filter { $0.enable } // Only online cameras
            .map { $0.uniqueChannel }
            .sorted()
        
        await MainActor.run {
            availableChannels = onlineChannels
            // If current channel is not in available channels, select the first one
            if !onlineChannels.contains(editableCamera.uniqueChannel) && !onlineChannels.isEmpty {
                editableCamera.uniqueChannel = onlineChannels[0]
            }
            isLoadingChannels = false
        }
    }
    
    private func saveChanges() {
        Task {
            await saveChangesAsync()
        }
    }
    
    @MainActor
    private func saveChangesAsync() async {
        // Set saving state
        isSaving = true
        saveError = nil
        
        #if DEBUG
        logger.debug("💾 Preparing camera changes for save")
        #endif
        
        do {
            #if DEBUG
            logger.debug("💾 [CameraEditSheet] Starting camera save process")
            logger.debug("💾 [CameraEditSheet] Original camera: \(camera.name) (ID: \(camera.deviceID))")
            logger.debug("💾 [CameraEditSheet] Changes detected: \(hasChanges)")
            #endif
            
            // Create the merged camera data
            let mergedCameraData = createMergedCameraData()
            
            // Convert to JSON and print for debugging
            let jsonData = try JSONSerialization.data(withJSONObject: mergedCameraData, options: .prettyPrinted)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                #if DEBUG
                print("💾 [CameraEditSheet] MERGED CAMERA DATA:")
                print(jsonString)
                #endif
            }
            
            // Update camera through the store
            #if DEBUG
            logger.debug("💾 [CameraEditSheet] Calling store.updateCamera...")
            #endif
            
            try await store.updateCamera(cameraData: mergedCameraData)
            
            #if DEBUG
            logger.debug("💾 [CameraEditSheet] ✅ Store update successful, camera data refreshed")
            #endif
            
            // Dismiss the sheet
            dismiss()
            
            #if DEBUG
            logger.debug("💾 [CameraEditSheet] Sheet dismissed successfully")
            #endif
            
        } catch {
            #if DEBUG
            logger.error("💾 [CameraEditSheet] ❌ Save failed with error: \(error)")
            logger.error("💾 [CameraEditSheet] Error description: \(error.localizedDescription)")
            let nsError = error as NSError
            logger.error("💾 [CameraEditSheet] Error domain: \(nsError.domain)")
            logger.error("💾 [CameraEditSheet] Error code: \(nsError.code)")
            logger.error("💾 [CameraEditSheet] Error userInfo: \(nsError.userInfo)")
            #endif
            
            saveError = error.localizedDescription
        }
        
        // Reset saving state
        isSaving = false
    }
    
    private func createMergedCameraData() -> [String: Any] {
        #if DEBUG
        logger.debug("💾 [createMergedCameraData] Building camera data for secSetCamera")
        logger.debug("💾 [createMergedCameraData] Original camera name: \(camera.name)")
        logger.debug("💾 [createMergedCameraData] Edited camera name: \(editableCamera.name)")
        logger.debug("💾 [createMergedCameraData] Edited IP: \(editableCamera.ipAddress)")
        logger.debug("💾 [createMergedCameraData] Edited Username: \(editableCamera.username)")
        logger.debug("💾 [createMergedCameraData] Edited HTTP Port: \(editableCamera.httpPort)")
        logger.debug("💾 [createMergedCameraData] Edited Manufacturer: \(editableCamera.manufacturer)")
        #endif
        
        // Create the merged camera object with all fields from the original camera
        // but with edited values replacing the original ones
        let mergedCamera: [String: Any] = [
            "Channel": editableCamera.uniqueChannel,
            "DeviceID": camera.deviceID,
            "DeviceInfo": [
                "Address": editableCamera.ipAddress,
                "AudioInputChannels": camera.deviceInfo.audioInputChannels,
                "DeviceClass": camera.deviceInfo.deviceClass,
                "DeviceType": camera.deviceInfo.deviceType,
                "Enable": camera.enable,
                "Encryption": camera.deviceInfo.encryptStream,
                "HttpPort": editableCamera.httpPort,
                "HttpsPort": camera.deviceInfo.httpsPort,
                "Mac": camera.deviceInfo.mac,
                "Name": camera.deviceInfo.name,
                "PoE": false, // Default value as not in our model
                "PoEPort": 0, // Default value as not in our model
                "Port": camera.deviceInfo.port,
                "ProtocolType": editableCamera.manufacturer, // This is the edited protocol type
                "RtspPort": camera.deviceInfo.rtspPort,
                "SerialNo": "",
                "UserName": editableCamera.username,
                "VideoInputChannels": editableCamera.totalChannels,
                "VideoInputs": [
                    [
                        "BufDelay": 160, // Default value
                        "Enable": true,
                        "ExtraStreamUrl": "",
                        "MainStreamUrl": "",
                        "Name": "",
                        "ServiceType": "AUTO"
                    ]
                ],
                "Password": editableCamera.password,
                "LoginType": 0, // Default value
                "b_isMultiVideoSensor": false // Default value
            ],
            "Enable": camera.enable,
            "Type": camera.type,
            "UniqueChannel": editableCamera.uniqueChannel,
            "VideoStandard": "PAL", // Default value as not in our model
            "VideoStream": camera.videoStream,
            "showStatus": camera.showStatus ?? "Unknown"
        ]
        
        // Return in the expected format with cameras array
        return [
            "cameras": [mergedCamera]
        ]
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
                        "Password": editableCamera.password, // Empty string if user didn't change it
                        "ProtocolType": editableCamera.protocolType,
                        "DeviceType": editableCamera.deviceType,
                        "Name": editableCamera.name,
                        "Mac": editableCamera.macAddress,
                        "VendorAbbr": editableCamera.manufacturer,
                        "VideoInputChannels": editableCamera.totalChannels,
                        "RemoteChannel": editableCamera.remoteChannelNo,
                        "DecodeStrategy": editableCamera.decodeStrategy
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
    var totalChannels: Int
    var remoteChannelNo: Int
    var decodeStrategy: String
    
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
        self.password = "" // Always start with empty password since we can't retrieve it
        self.protocolType = camera.deviceInfo.protocolType
        self.deviceType = camera.deviceInfo.deviceType
        self.macAddress = camera.deviceInfo.mac
        self.manufacturer = camera.deviceInfo.protocolType
        self.totalChannels = camera.deviceInfo.videoInputChannels
        self.remoteChannelNo = camera.deviceInfo.videoInputChannels
        self.decodeStrategy = "General" // Default value
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
               lhs.manufacturer == rhs.manufacturer &&
               lhs.totalChannels == rhs.totalChannels &&
               lhs.remoteChannelNo == rhs.remoteChannelNo &&
               lhs.decodeStrategy == rhs.decodeStrategy
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
