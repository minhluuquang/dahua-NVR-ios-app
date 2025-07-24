import SwiftUI
import os.log

@MainActor
class CameraStore: ObservableObject {
    @Published var cameras: [NVRCamera] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let logger = Logger(subsystem: "com.minhlq.DahuaNVR", category: "CameraStore")
    private var statusPoller: CameraStatusPoller?
    private var currentFetchTask: Task<Void, Never>?
    
    /// Single method for all camera refresh scenarios
    func refresh() async {
        // Cancel any in-flight request
        currentFetchTask?.cancel()
        
        // Create new fetch task
        currentFetchTask = Task { [weak self] in
            guard let self = self else { return }
            
            // Update UI state
            self.isLoading = true
            self.errorMessage = nil
            
            do {
                // Check if we have active connection
                guard let rpcService = AuthenticationManager.shared.rpcService,
                      rpcService.hasActiveSession else {
                    self.errorMessage = "No active RPC connection to NVR system."
                    self.isLoading = false
                    return
                }
                
                // Fetch cameras (will throw if cancelled)
                let fetchedCameras = try await rpcService.camera.getAllCameras()
                
                // Only update if not cancelled
                if !Task.isCancelled {
                    self.cameras = fetchedCameras
                }
                
            } catch {
                // Only show error if not cancelled
                if !Task.isCancelled {
                    self.errorMessage = "Failed to load cameras: \(error.localizedDescription)"
                }
            }
            
            // Always clear loading state if not cancelled
            if !Task.isCancelled {
                self.isLoading = false
            }
        }
        
        // Await completion
        await currentFetchTask?.value
    }
    
    // Keep old method name for compatibility, just forwards to refresh
    func fetchCamerasRPC() async {
        await refresh()
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
        await refresh()
    }
    
    func refreshCameraStatusWithDelay(delay: TimeInterval = 3.0) async {
        #if DEBUG
        logger.debug("📦 [CameraStore] Waiting \(delay) seconds before refreshing camera status...")
        #endif
        
        try? await Task.sleep(for: .seconds(delay))
        await refresh()
        
        #if DEBUG
        logger.debug("📦 [CameraStore] Camera status refreshed after delay")
        #endif
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
        // Cancel any ongoing fetch
        currentFetchTask?.cancel()
        
        // Stop status polling
        if let poller = statusPoller {
            Task {
                await poller.stopAllPolling()
            }
        }
    }
}
