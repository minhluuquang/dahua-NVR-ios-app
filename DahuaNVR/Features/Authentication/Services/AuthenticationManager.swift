import Foundation
import Combine

enum AuthError: LocalizedError {
    case authenticationFailed
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "Authentication failed"
        }
    }
}

@MainActor
final class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published private(set) var authenticationState: AuthenticationState = .idle
    @Published private(set) var currentCredentials: NVRCredentials?
    
    private var rpcAuthService: RPCAuthenticationService?
    private let keychainHelper = KeychainHelper.shared
    private let authDataKey = "dahua_nvr_auth_data"
    
    let nvrManager = NVRManager()
    
    private init() {
        loadPersistedAuth()
    }
    
    func connectToNVR(_ nvrSystem: NVRSystem) async throws {
        authenticationState = .loading
        
        try await performAuthentication(with: nvrSystem.credentials)
        
        // Ensure the NVR system exists in the list before updating status
        if !nvrManager.nvrSystems.contains(where: { $0.id == nvrSystem.id }) {
            #if DEBUG
            print("🔍 [AuthManager] Adding NVR system: \(nvrSystem.name)")
            #endif
            nvrManager.addNVRSystem(nvrSystem)
        }
        
        nvrManager.updateAuthenticationStatus(
            for: nvrSystem.id,
            rpcSuccess: true
        )
        
        #if DEBUG
        print("🔍 [AuthManager] RPC auth success, selecting NVR: \(nvrSystem.name)")
        #endif
        
        nvrManager.selectNVR(nvrSystem)
        authenticationState = .authenticated
    }
    
    // Private core authentication method
    private func performAuthentication(with credentials: NVRCredentials) async throws {
        // Reuse existing service if it's for the same server, otherwise create new
        if rpcAuthService == nil || rpcAuthService?.baseURL != credentials.serverURL {
            rpcAuthService = RPCAuthenticationService(baseURL: credentials.serverURL)
        }
        
        let authResult = await rpcAuthService!.authenticate(with: credentials)
        
        if authResult.success {
            currentCredentials = credentials
            await saveAuthData(credentials: credentials)
        } else {
            authenticationState = .failed(authResult.error?.localizedDescription ?? "Authentication failed")
            if let error = authResult.error {
                throw error
            } else {
                throw AuthError.authenticationFailed
            }
        }
    }
    
    func attemptAutoConnectToDefaultNVR() async {
        guard let defaultNVR = nvrManager.defaultNVR else {
            return
        }
        
        do {
            try await connectToNVR(defaultNVR)
        } catch {
            print("Failed to auto-connect to default NVR: \(error)")
        }
    }
    
    func logout() async {
        authenticationState = .idle
        await clearPersistedAuth()
        currentCredentials = nil
        rpcAuthService = nil
    }
    
    func attemptAutoLogin() async {
        guard let persistedAuth = loadPersistedAuthData(),
              !persistedAuth.isExpired else {
            await clearPersistedAuth()
            return
        }
        
        do {
            try await performAuthentication(with: persistedAuth.credentials)
            authenticationState = .authenticated
        } catch {
            await clearPersistedAuth()
        }
    }
    
    func refreshSession() async throws {
        guard let credentials = currentCredentials else {
            throw AuthError.authenticationFailed
        }
        
        try await performAuthentication(with: credentials)
        authenticationState = .authenticated
    }
    
    private func loadPersistedAuth() {
        if let persistedAuth = loadPersistedAuthData(),
           !persistedAuth.isExpired {
            Task {
                await attemptAutoLogin()
            }
        }
    }
    
    private func loadPersistedAuthData() -> PersistedAuthData? {
        do {
            return try keychainHelper.load(PersistedAuthData.self, forKey: authDataKey)
        } catch {
            return nil
        }
    }
    
    private func saveAuthData(credentials: NVRCredentials) async {
        let authData = PersistedAuthData(credentials: credentials)
        
        do {
            try keychainHelper.save(authData, forKey: authDataKey)
        } catch {
            print("Failed to save auth data to keychain: \(error)")
        }
    }
    
    private func clearPersistedAuth() async {
        do {
            try keychainHelper.delete(forKey: authDataKey)
        } catch {
            print("Failed to clear auth data from keychain: \(error)")
        }
    }
    
    var isAuthenticated: Bool {
        authenticationState == .authenticated
    }
    
    var isLoading: Bool {
        authenticationState == .loading
    }
    
    var hasPersistedAuth: Bool {
        keychainHelper.exists(forKey: authDataKey)
    }
    
    var cameraService: RPCAuthenticationService? {
        return rpcAuthService
    }
    
    var rpcService: RPCService? {
        return rpcAuthService?.rpc
    }
    
    var isRPCAvailable: Bool {
        return rpcAuthService != nil
    }
    
    var authenticationStatusText: String {
        return isRPCAvailable ? "RPC Connected" : "Not connected"
    }
    
    func disconnect() async {
        await logout()
        rpcAuthService = nil
    }
}