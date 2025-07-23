import SwiftUI

struct MainAppView: View {
    @ObservedObject private var authManager = AuthenticationManager.shared
    @StateObject private var cameraStore = CameraStore()
    @State private var showingNVRList = false
    @State private var isProcessing = false
    
    var body: some View {
        NavigationView {
            TabView {
                CameraTabView()
                    .environmentObject(cameraStore)
                    .tabItem {
                        Image(systemName: "camera")
                        Text("Camera")
                    }
                
                PlaceholderTabView(title: "Storage")
                    .tabItem {
                        Image(systemName: "externaldrive")
                        Text("Storage")
                    }
                
                PlaceholderTabView(title: "Network")
                    .tabItem {
                        Image(systemName: "network")
                        Text("Network")
                    }
                
                PlaceholderTabView(title: "Account")
                    .tabItem {
                        Image(systemName: "person")
                        Text("Account")
                    }
                
                PlaceholderTabView(title: "System")
                    .tabItem {
                        Image(systemName: "gear")
                        Text("System")
                    }
            }
            .navigationTitle(currentNVRName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("NVR List", systemImage: "list.bullet") {
                            showingNVRList = true
                        }
                        
                        Button("Scramble IPs", systemImage: "shuffle") {
                            Task {
                                await scrambleCameraIPs()
                            }
                        }
                        .disabled(isProcessing)
                        
                        Button("Reset IPs", systemImage: "arrow.clockwise") {
                            Task {
                                await resetCameraIPs()
                            }
                        }
                        .disabled(isProcessing)
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .disabled(isProcessing)
                }
            }
            .sheet(isPresented: $showingNVRList) {
                NavigationView {
                    NVRListView()
                }
            }
        }
    }
    
    private var currentNVRName: String {
        let currentNVR = authManager.nvrManager.currentNVR
        let nvrCount = authManager.nvrManager.nvrSystems.count
        
        #if DEBUG
        print("🔍 [MainAppView] Current NVR: \(currentNVR?.name ?? "nil"), NVR Systems Count: \(nvrCount)")
        if nvrCount > 0 {
            print("🔍 [MainAppView] NVR Systems: \(authManager.nvrManager.nvrSystems.map { $0.name })")
        }
        #endif
        
        return currentNVR?.name ?? "No NVR Selected"
    }
    
    @MainActor
    private func scrambleCameraIPs() async {
        guard let rpcService = authManager.rpcService else {
            print("❌ [MainAppView] No RPC service available")
            return
        }
        
        isProcessing = true
        
        do {
            // Get all cameras from the camera store (already fetched data)
            let allCameras = cameraStore.cameras
            
            // Filter for online cameras only
            let onlineCameras = allCameras.filter { camera in
                camera.enable && camera.showStatus == "Connected"
            }
            
            guard !onlineCameras.isEmpty else {
                print("ℹ️ [MainAppView] No online cameras found to scramble")
                isProcessing = false
                return
            }
            
            // Create camera payload with scrambled IP addresses
            let cameraPayloads = onlineCameras.compactMap { camera -> [String: Any]? in
                let scrambledIP = camera.deviceInfo.address + "1"
                
                return [
                    "Channel": camera.uniqueChannel,
                    "DeviceID": camera.deviceID,
                    "DeviceInfo": [
                        "Address": scrambledIP,
                        "AudioInputChannels": camera.deviceInfo.audioInputChannels,
                        "DeviceClass": camera.deviceInfo.deviceClass,
                        "DeviceType": camera.deviceInfo.deviceType,
                        "Enable": camera.deviceInfo.enable,
                        "Encryption": camera.deviceInfo.encryptStream,
                        "HttpPort": camera.deviceInfo.httpPort,
                        "HttpsPort": camera.deviceInfo.httpsPort,
                        "Mac": camera.deviceInfo.mac,
                        "Name": camera.deviceInfo.name,
                        "PoE": false,
                        "PoEPort": 0,
                        "Port": camera.deviceInfo.port,
                        "ProtocolType": camera.deviceInfo.protocolType,
                        "RtspPort": camera.deviceInfo.rtspPort,
                        "SerialNo": camera.deviceInfo.serialNo,
                        "UserName": camera.deviceInfo.userName,
                        "VideoInputChannels": camera.deviceInfo.videoInputChannels,
                        "VideoInputs": [
                            [
                                "BufDelay": 160,
                                "Enable": true,
                                "ExtraStreamUrl": "",
                                "MainStreamUrl": "",
                                "Name": "",
                                "ServiceType": "AUTO"
                            ]
                        ],
                        "Password": "",
                        "LoginType": 0,
                        "b_isMultiVideoSensor": false
                    ],
                    "Enable": camera.enable,
                    "Type": camera.type,
                    "UniqueChannel": camera.uniqueChannel,
                    "VideoStandard": "PAL",
                    "VideoStream": camera.videoStream,
                    "showStatus": camera.showStatus ?? "Unknown"
                ]
            }
            
            let cameraData = ["cameras": cameraPayloads]
            
            // Call secSetCamera with all modified cameras
            _ = try await rpcService.camera.secSetCamera(cameraData: cameraData)
            
            // Refresh camera data to reflect changes
            await cameraStore.fetchCamerasRPC()
            
            print("✅ [MainAppView] Successfully scrambled \(cameraPayloads.count) camera IP addresses")
            
        } catch {
            print("❌ [MainAppView] Failed to scramble camera IPs: \(error)")
        }
        
        isProcessing = false
    }
    
    @MainActor
    private func resetCameraIPs() async {
        guard let rpcService = authManager.rpcService else {
            print("❌ [MainAppView] No RPC service available")
            return
        }
        
        isProcessing = true
        
        do {
            // Get all cameras from the camera store (already fetched data)
            let allCameras = cameraStore.cameras
            
            // Filter for cameras with scrambled IPs (those ending with extra characters)
            let scrambledCameras = allCameras.filter { camera in
                camera.enable && camera.deviceInfo.address.count > 11 // Standard IP is typically shorter
            }
            
            guard !scrambledCameras.isEmpty else {
                print("ℹ️ [MainAppView] No scrambled cameras found to reset")
                isProcessing = false
                return
            }
            
            // Create camera payload with reset IP addresses
            let cameraPayloads = scrambledCameras.compactMap { camera -> [String: Any]? in
                let resetIP = String(camera.deviceInfo.address.dropLast())
                
                return [
                    "Channel": camera.uniqueChannel,
                    "DeviceID": camera.deviceID,
                    "DeviceInfo": [
                        "Address": resetIP,
                        "AudioInputChannels": camera.deviceInfo.audioInputChannels,
                        "DeviceClass": camera.deviceInfo.deviceClass,
                        "DeviceType": camera.deviceInfo.deviceType,
                        "Enable": camera.deviceInfo.enable,
                        "Encryption": camera.deviceInfo.encryptStream,
                        "HttpPort": camera.deviceInfo.httpPort,
                        "HttpsPort": camera.deviceInfo.httpsPort,
                        "Mac": camera.deviceInfo.mac,
                        "Name": camera.deviceInfo.name,
                        "PoE": false,
                        "PoEPort": 0,
                        "Port": camera.deviceInfo.port,
                        "ProtocolType": camera.deviceInfo.protocolType,
                        "RtspPort": camera.deviceInfo.rtspPort,
                        "SerialNo": camera.deviceInfo.serialNo,
                        "UserName": camera.deviceInfo.userName,
                        "VideoInputChannels": camera.deviceInfo.videoInputChannels,
                        "VideoInputs": [
                            [
                                "BufDelay": 160,
                                "Enable": true,
                                "ExtraStreamUrl": "",
                                "MainStreamUrl": "",
                                "Name": "",
                                "ServiceType": "AUTO"
                            ]
                        ],
                        "Password": "",
                        "LoginType": 0,
                        "b_isMultiVideoSensor": false
                    ],
                    "Enable": camera.enable,
                    "Type": camera.type,
                    "UniqueChannel": camera.uniqueChannel,
                    "VideoStandard": "PAL",
                    "VideoStream": camera.videoStream,
                    "showStatus": camera.showStatus ?? "Unknown"
                ]
            }
            
            let cameraData = ["cameras": cameraPayloads]
            
            // Call secSetCamera with all reset cameras
            _ = try await rpcService.camera.secSetCamera(cameraData: cameraData)
            
            // Refresh camera data to reflect changes
            await cameraStore.fetchCamerasRPC()
            
            print("✅ [MainAppView] Successfully reset \(cameraPayloads.count) camera IP addresses")
            
        } catch {
            print("❌ [MainAppView] Failed to reset camera IPs: \(error)")
        }
        
        isProcessing = false
    }
}

struct PlaceholderTabView: View {
    let title: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "construction")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("\(title) Feature")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("This feature will be available in a future release.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    MainAppView()
}