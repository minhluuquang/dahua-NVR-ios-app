import Foundation
import os.log

actor CameraStatusPoller {
    private var pollingTasks = [UUID: Task<Void, Never>]()
    private weak var cameraStore: CameraStore?
    private let rpcService: RPCService
    
    // Polling configuration
    private let initialDelay: TimeInterval = 2.0
    private let maxDelay: TimeInterval = 10.0
    private let backoffMultiplier: Double = 1.5
    private let maxRetries: Int = 6
    
    private let logger = Logger(subsystem: "com.minhlq.DahuaNVR", category: "CameraStatusPoller")
    
    init(cameraStore: CameraStore, rpcService: RPCService) {
        self.cameraStore = cameraStore
        self.rpcService = rpcService
    }
    
    /// Starts polling for a specific camera's status to detect changes after updates
    /// If a poll is already running for this camera, it's cancelled and a new one begins
    func startPolling(for cameraID: UUID) {
        #if DEBUG
        logger.debug("🔄 [CameraStatusPoller] Starting status polling for camera: \(cameraID)")
        #endif
        
        // Cancel any existing polling task for this camera to avoid redundant polls
        pollingTasks[cameraID]?.cancel()
        
        let newTask = Task {
            await pollUntilStatusChanges(for: cameraID)
        }
        pollingTasks[cameraID] = newTask
    }
    
    /// Stops polling for a specific camera
    func stopPolling(for cameraID: UUID) {
        #if DEBUG
        logger.debug("⏹️ [CameraStatusPoller] Stopping status polling for camera: \(cameraID)")
        #endif
        
        pollingTasks[cameraID]?.cancel()
        pollingTasks.removeValue(forKey: cameraID)
    }
    
    /// Stops all polling tasks. Useful for cleanup
    func stopAllPolling() {
        #if DEBUG
        logger.debug("⏹️ [CameraStatusPoller] Stopping all status polling")
        #endif
        
        pollingTasks.values.forEach { $0.cancel() }
        pollingTasks.removeAll()
    }
    
    private func pollUntilStatusChanges(for cameraID: UUID) async {
        var currentDelay = initialDelay
        var retries = 0
        
        // Get the initial status to compare against
        guard let initialCamera = await cameraStore?.findCamera(by: cameraID) else {
            #if DEBUG
            logger.debug("❌ [CameraStatusPoller] Cannot find camera with ID: \(cameraID)")
            #endif
            pollingTasks.removeValue(forKey: cameraID)
            return
        }
        
        let initialStatus = initialCamera.showStatus
        let cameraChannel = initialCamera.uniqueChannel
        
        #if DEBUG
        logger.debug("🔄 [CameraStatusPoller] Starting polling for camera \(cameraID) (Channel \(cameraChannel)) with initial status: \(initialStatus ?? "Unknown")")
        #endif
        
        while retries < maxRetries {
            do {
                // Check for cancellation before sleeping and before the network call
                try Task.checkCancellation()
                
                // Wait before checking status
                try await Task.sleep(for: .seconds(currentDelay))
                
                try Task.checkCancellation()
                
                // Get current camera states from server
                let cameraStates = try await rpcService.camera.getCameraState()
                
                // Find the state for our specific camera by channel
                if let currentState = cameraStates.first(where: { $0.channel == cameraChannel }) {
                    let newStatus = currentState.connectionState
                    
                    #if DEBUG
                    logger.debug("🔍 [CameraStatusPoller] Channel \(cameraChannel) status check: \(newStatus ?? "nil") (was: \(initialStatus ?? "nil"))")
                    #endif
                    
                    // Check if status has changed from initial
                    if newStatus != initialStatus {
                        #if DEBUG
                        logger.debug("✅ [CameraStatusPoller] Status changed for camera \(cameraID): \(initialStatus ?? "nil") → \(newStatus ?? "nil")")
                        #endif
                        
                        // Status has changed! Update the store and stop polling
                        await updateCameraStatus(cameraID: cameraID, newStatus: newStatus)
                        pollingTasks.removeValue(forKey: cameraID)
                        return
                    }
                } else {
                    #if DEBUG
                    logger.debug("⚠️ [CameraStatusPoller] No state found for camera channel: \(cameraChannel)")
                    #endif
                }
                
                // If status hasn't changed, prepare for next poll with exponential backoff
                currentDelay = min(currentDelay * backoffMultiplier, maxDelay)
                retries += 1
                
                #if DEBUG
                logger.debug("🔄 [CameraStatusPoller] Camera \(cameraID) status unchanged, retrying in \(currentDelay)s (attempt \(retries)/\(self.maxRetries))")
                #endif
                
            } catch is CancellationError {
                #if DEBUG
                logger.debug("🚫 [CameraStatusPoller] Polling for camera \(cameraID) was cancelled")
                #endif
                pollingTasks.removeValue(forKey: cameraID)
                return
            } catch {
                #if DEBUG
                logger.error("❌ [CameraStatusPoller] Error polling for camera \(cameraID): \(error.localizedDescription)")
                #endif
                
                // Handle network errors with backoff and retry
                currentDelay = min(currentDelay * backoffMultiplier, maxDelay)
                retries += 1
            }
        }
        
        #if DEBUG
        logger.debug("⏰ [CameraStatusPoller] Polling timeout for camera \(cameraID) after \(self.maxRetries) retries. Status remained: \(initialStatus ?? "Unknown")")
        #endif
        
        pollingTasks.removeValue(forKey: cameraID)
    }
    
    private func updateCameraStatus(cameraID: UUID, newStatus: String?) async {
        await cameraStore?.updateCameraStatus(for: cameraID, newStatus: newStatus)
    }
}