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
            // Get raw RPC camera data to preserve original structure including VideoInputs
            let rawRPCCameras = try await rpcService.camera.getRawCameraData()
            
            // Also get camera states to identify online cameras
            let cameraStates = try await rpcService.camera.getCameraState()
            let onlineChannels = Set(cameraStates.filter { $0.connectionState == "Connected" }.map { $0.channel })
            
            // Filter for online cameras only
            let onlineCameras = rawRPCCameras.filter { camera in
                guard let enable = camera.enable else { return false }
                return enable && onlineChannels.contains(camera.uniqueChannel)
            }
            
            guard !onlineCameras.isEmpty else {
                print("ℹ️ [MainAppView] No online cameras found to scramble")
                isProcessing = false
                return
            }
            
            // Create camera payload using the RPCCameraInfo extension, preserving original VideoInputs
            let cameraPayloads = onlineCameras.compactMap { camera -> [String: Any]? in
                guard let deviceInfo = camera.deviceInfo else { return nil }
                let scrambledIP = deviceInfo.address + "1"
                return camera.toCameraPayload(withModifiedAddress: scrambledIP)
            }
            
            let cameraData = ["cameras": cameraPayloads]
            
            // Call secSetCamera with all modified cameras
            _ = try await rpcService.camera.secSetCamera(cameraData: cameraData)
            
            // Refresh camera data with delay to allow connection states to settle
            await cameraStore.refreshCameraStatusWithDelay()
            
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
            // Get raw RPC camera data to preserve original structure including VideoInputs
            let rawRPCCameras = try await rpcService.camera.getRawCameraData()
            
            // Filter for cameras with scrambled IPs (those ending with extra characters like "1")
            // Detect IPs that end with "1" and are longer than standard IP format
            let scrambledCameras = rawRPCCameras.filter { camera in
                guard let enable = camera.enable,
                      let deviceInfo = camera.deviceInfo else { return false }
                return enable && deviceInfo.address.hasSuffix("1") && deviceInfo.address.count > 11
            }
            
            guard !scrambledCameras.isEmpty else {
                print("ℹ️ [MainAppView] No scrambled cameras found to reset")
                isProcessing = false
                return
            }
            
            // Create camera payload using the RPCCameraInfo extension, preserving original VideoInputs
            let cameraPayloads = scrambledCameras.compactMap { camera -> [String: Any]? in
                guard let deviceInfo = camera.deviceInfo else { return nil }
                let resetIP = String(deviceInfo.address.dropLast())
                return camera.toCameraPayload(withModifiedAddress: resetIP)
            }
            
            let cameraData = ["cameras": cameraPayloads]
            
            // Call secSetCamera with all reset cameras
            _ = try await rpcService.camera.secSetCamera(cameraData: cameraData)
            
            // Refresh camera data with delay to allow connection states to settle
            await cameraStore.refreshCameraStatusWithDelay()
            
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