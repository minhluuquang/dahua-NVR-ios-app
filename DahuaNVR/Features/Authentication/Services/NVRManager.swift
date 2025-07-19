import Foundation
import Combine

class NVRManager: ObservableObject {
    @Published var nvrSystems: [NVRSystem] = []
    @Published var currentNVR: NVRSystem?
    
    private let userDefaults = UserDefaults.standard
    private let nvrSystemsKey = "SavedNVRSystems"
    private let currentNVRKey = "CurrentNVR"
    
    init() {
        loadNVRSystems()
    }
    
    func addNVRSystem(_ system: NVRSystem) {
        #if DEBUG
        print("🔍 [NVRManager] Adding NVR system: \(system.name), isDefault: \(system.isDefault)")
        #endif
        
        var updatedSystems = nvrSystems
        
        if system.isDefault {
            updatedSystems = updatedSystems.map { 
                NVRSystem(id: $0.id, name: $0.name, credentials: $0.credentials, isDefault: false, rpcAuthSuccess: $0.rpcAuthSuccess, httpCGIAuthSuccess: $0.httpCGIAuthSuccess)
            }
        }
        
        updatedSystems.append(system)
        nvrSystems = updatedSystems
        
        if system.isDefault {
            currentNVR = system
        }
        
        #if DEBUG
        print("🔍 [NVRManager] NVR systems count after add: \(nvrSystems.count)")
        print("🔍 [NVRManager] Current NVR after add: \(currentNVR?.name ?? "nil")")
        #endif
        
        saveNVRSystems()
    }
    
    func removeNVRSystem(_ system: NVRSystem) {
        nvrSystems.removeAll { $0.id == system.id }
        
        if currentNVR?.id == system.id {
            currentNVR = nvrSystems.first { $0.isDefault }
        }
        
        saveNVRSystems()
    }
    
    func setDefaultNVR(_ system: NVRSystem) {
        nvrSystems = nvrSystems.map { nvr in
            NVRSystem(
                id: nvr.id,
                name: nvr.name,
                credentials: nvr.credentials,
                isDefault: nvr.id == system.id,
                rpcAuthSuccess: nvr.rpcAuthSuccess,
                httpCGIAuthSuccess: nvr.httpCGIAuthSuccess
            )
        }
        
        currentNVR = system
        saveNVRSystems()
    }
    
    func selectNVR(_ system: NVRSystem) {
        #if DEBUG
        print("🔍 [NVRManager] Selecting NVR: \(system.name)")
        #endif
        currentNVR = system
        saveCurrentNVR()
    }
    
    var defaultNVR: NVRSystem? {
        nvrSystems.first { $0.isDefault }
    }
    
    func updateAuthenticationStatus(for systemId: UUID, rpcSuccess: Bool, httpCGISuccess: Bool) {
        if let index = nvrSystems.firstIndex(where: { $0.id == systemId }) {
            let system = nvrSystems[index]
            nvrSystems[index] = NVRSystem(
                id: system.id,
                name: system.name,
                credentials: system.credentials,
                isDefault: system.isDefault,
                rpcAuthSuccess: rpcSuccess,
                httpCGIAuthSuccess: httpCGISuccess
            )
            
            if currentNVR?.id == systemId {
                currentNVR = nvrSystems[index]
            }
            
            saveNVRSystems()
        }
    }
    
    func clearAuthenticationStatus(for systemId: UUID) {
        updateAuthenticationStatus(for: systemId, rpcSuccess: false, httpCGISuccess: false)
    }
    
    private func loadNVRSystems() {
        #if DEBUG
        print("🔍 [NVRManager] Loading NVR systems from UserDefaults")
        #endif
        
        if let data = userDefaults.data(forKey: nvrSystemsKey),
           let systems = try? JSONDecoder().decode([NVRSystem].self, from: data) {
            nvrSystems = systems
            #if DEBUG
            print("🔍 [NVRManager] Loaded \(systems.count) NVR systems: \(systems.map { $0.name })")
            #endif
        } else {
            #if DEBUG
            print("🔍 [NVRManager] No NVR systems found in UserDefaults")
            #endif
        }
        
        if let data = userDefaults.data(forKey: currentNVRKey),
           let system = try? JSONDecoder().decode(NVRSystem.self, from: data) {
            currentNVR = system
            #if DEBUG
            print("🔍 [NVRManager] Loaded current NVR: \(system.name)")
            #endif
        } else {
            currentNVR = defaultNVR
            #if DEBUG
            print("🔍 [NVRManager] No current NVR found, using default: \(defaultNVR?.name ?? "nil")")
            #endif
        }
    }
    
    private func saveNVRSystems() {
        if let data = try? JSONEncoder().encode(nvrSystems) {
            userDefaults.set(data, forKey: nvrSystemsKey)
            #if DEBUG
            print("🔍 [NVRManager] Saved \(nvrSystems.count) NVR systems to UserDefaults")
            #endif
        }
        saveCurrentNVR()
        userDefaults.synchronize()
    }
    
    private func saveCurrentNVR() {
        if let currentNVR = currentNVR,
           let data = try? JSONEncoder().encode(currentNVR) {
            userDefaults.set(data, forKey: currentNVRKey)
            #if DEBUG
            print("🔍 [NVRManager] Saved current NVR: \(currentNVR.name)")
            #endif
        }
    }
}