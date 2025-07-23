import SwiftUI
import os.log

@MainActor
class CameraStore: ObservableObject {
    @Published var cameras: [NVRCamera] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let logger = Logger(subsystem: "com.minhlq.DahuaNVR", category: "CameraStore")
    private var statusPoller: CameraStatusPoller?
    
    func fetchCamerasRPC() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        guard let rpcService = AuthenticationManager.shared.rpcService,
              rpcService.hasActiveSession else {
            isLoading = false
            errorMessage = "No active RPC connection to NVR system."
            return
        }
        
        do {
            let fetchedCameras = try await rpcService.camera.getAllCameras()
            guard isLoading else { return }
            cameras = fetchedCameras
            isLoading = false
        } catch {
            guard isLoading else { return }
            isLoading = false
            errorMessage = "Failed to load cameras: \(error.localizedDescription)"
        }
    }
    
    func updateCamera(cameraData: [String: Any]) async throws {
        guard let rpcService = AuthenticationManager.shared.rpcService else {
            throw NSError(domain: "CameraStoreError", code: -1, userInfo: [NSLocalizedDescriptionKey: "RPC service not available"])
        }
        
        #if DEBUG
        logger.debug("📦 [CameraStore] Updating camera...")
        #endif
        
        let updatedCameras = try await rpcService.camera.secSetCamera(cameraData: cameraData)
        
        #if DEBUG
        logger.debug("📦 [CameraStore] Camera updated successfully, updating local cameras array...")
        #endif
        
        // Update local cameras array with fresh data from server
        // This triggers immediate UI updates via @Published
        cameras = updatedCameras
        
        // Start polling for status changes after successful update
        // Extract camera ID from cameraData to identify which camera was updated
        if let camerasArray = cameraData["cameras"] as? [[String: Any]],
           let firstCamera = camerasArray.first,
           let deviceID = firstCamera["DeviceID"] as? String,
           let updatedCamera = cameras.first(where: { $0.deviceID == deviceID }) {
            
            #if DEBUG
            logger.debug("📦 [CameraStore] Starting status polling for updated camera: \(updatedCamera.name) (ID: \(updatedCamera.id))")
            #endif
            
            await getStatusPoller().startPolling(for: updatedCamera.id)
        }
    }
    
    func refreshCameraStatus() async {
        await fetchCamerasRPC()
    }
    
    func findCamera(by id: UUID) -> NVRCamera? {
        return cameras.first { $0.id == id }
    }
    
    func findCamera(by channel: Int) -> NVRCamera? {
        return cameras.first { $0.uniqueChannel == channel }
    }
    
    func findCamera(by deviceID: String) -> NVRCamera? {
        return cameras.first { $0.deviceID == deviceID }
    }
    
    // MARK: - Status Poller Management
    
    private func getStatusPoller() -> CameraStatusPoller {
        if let existingPoller = statusPoller {
            return existingPoller
        }
        
        guard let rpcService = AuthenticationManager.shared.rpcService else {
            fatalError("RPC service must be available when CameraStore is initialized")
        }
        
        let newPoller = CameraStatusPoller(cameraStore: self, rpcService: rpcService)
        statusPoller = newPoller
        return newPoller
    }
    
    // MARK: - Status Update Methods
    
    /// Updates only the status of a specific camera without triggering full UI refresh
    /// This is called by CameraStatusPoller when status changes are detected
    func updateCameraStatus(for cameraID: UUID, newStatus: String?) {
        if let index = cameras.firstIndex(where: { $0.id == cameraID }) {
            let oldStatus = cameras[index].showStatus
            cameras[index].showStatus = newStatus
            
            #if DEBUG
            logger.debug("📦 [CameraStore] Updated camera \(self.cameras[index].name) status: \(oldStatus ?? "nil") → \(newStatus ?? "nil")")
            #endif
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        if let poller = statusPoller {
            Task {
                await poller.stopAllPolling()
            }
        }
    }
}