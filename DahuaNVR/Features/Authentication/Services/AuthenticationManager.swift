import Foundation
import Combine

@MainActor
final class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published private(set) var authenticationState: AuthenticationState = .idle
    @Published private(set) var currentCredentials: NVRCredentials?
    
    private let authService = DahuaNVRAuthService()
    private var dualProtocolService: DualProtocolService?
    private let keychainHelper = KeychainHelper.shared
    private let authDataKey = "dahua_nvr_auth_data"
    
    private var cancellables = Set<AnyCancellable>()
    
    let nvrManager = NVRManager()
    
    private init() {
        bindAuthService()
        loadPersistedAuth()
    }
    
    private func bindAuthService() {
        Publishers.CombineLatest3(
            authService.$isAuthenticated,
            authService.$isLoading,
            authService.$errorMessage
        )
        .map { isAuthenticated, isLoading, errorMessage in
            if isLoading {
                return AuthenticationState.loading
            } else if isAuthenticated {
                return AuthenticationState.authenticated
            } else if let errorMessage = errorMessage {
                return AuthenticationState.failed(errorMessage)
            } else {
                return AuthenticationState.idle
            }
        }
        .receive(on: DispatchQueue.main)
        .assign(to: \.authenticationState, on: self)
        .store(in: &cancellables)
    }
    
    func login(with credentials: NVRCredentials) async throws {
        await authService.authenticate(
            serverURL: credentials.serverURL,
            username: credentials.username,
            password: credentials.password
        )
        
        if authenticationState == .authenticated {
            await saveAuthData(credentials: credentials)
            currentCredentials = credentials
        }
    }
    
    func connectToNVR(_ nvrSystem: NVRSystem) async throws {
        dualProtocolService = DualProtocolService(baseURL: nvrSystem.credentials.serverURL)
        
        let authResult = await dualProtocolService!.authenticate(credentials: nvrSystem.credentials)
        
        // Ensure the NVR system exists in the list before updating status
        if !nvrManager.nvrSystems.contains(where: { $0.id == nvrSystem.id }) {
            #if DEBUG
            print("🔍 [AuthManager] Adding NVR system: \(nvrSystem.name)")
            #endif
            nvrManager.addNVRSystem(nvrSystem)
        }
        
        nvrManager.updateAuthenticationStatus(
            for: nvrSystem.id,
            rpcSuccess: authResult.rpc.success,
            httpCGISuccess: authResult.httpCGI.success
        )
        
        if authResult.httpCGI.success {
            #if DEBUG
            print("🔍 [AuthManager] HTTP CGI auth success, selecting NVR: \(nvrSystem.name)")
            #endif
            currentCredentials = nvrSystem.credentials
            await saveAuthData(credentials: nvrSystem.credentials)
            nvrManager.selectNVR(nvrSystem)
            
            // Update authService state to trigger navigation
            await authService.authenticate(
                serverURL: nvrSystem.credentials.serverURL,
                username: nvrSystem.credentials.username,
                password: nvrSystem.credentials.password
            )
        } else {
            if let error = authResult.httpCGI.error {
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
        authService.logout()
        await clearPersistedAuth()
        currentCredentials = nil
    }
    
    func attemptAutoLogin() async {
        guard let persistedAuth = loadPersistedAuthData(),
              !persistedAuth.isExpired else {
            await clearPersistedAuth()
            return
        }
        
        await authService.authenticate(
            serverURL: persistedAuth.credentials.serverURL,
            username: persistedAuth.credentials.username,
            password: persistedAuth.credentials.password
        )
        
        if authenticationState == .authenticated {
            currentCredentials = persistedAuth.credentials
        } else {
            await clearPersistedAuth()
        }
    }
    
    func refreshSession() async throws {
        guard let credentials = currentCredentials else {
            throw AuthError.authenticationFailed
        }
        
        await authService.authenticate(
            serverURL: credentials.serverURL,
            username: credentials.username,
            password: credentials.password
        )
        
        if authenticationState == .authenticated {
            await saveAuthData(credentials: credentials)
        }
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
    
    var httpCGIService: CameraAPIService? {
        return dualProtocolService?.httpCGI
    }
    
    var rpcService: RPCService? {
        return dualProtocolService?.rpc
    }
    
    var isDualProtocolAvailable: Bool {
        return dualProtocolService?.isFullyAuthenticated ?? false
    }
    
    var authenticationStatusText: String {
        return dualProtocolService?.authenticationStatus ?? "Not connected"
    }
    
    func disconnect() async {
        await dualProtocolService?.disconnect()
        await logout()
        dualProtocolService = nil
    }
}