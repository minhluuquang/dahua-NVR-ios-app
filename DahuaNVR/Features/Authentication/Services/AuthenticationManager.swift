import Foundation
import Combine

@MainActor
final class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published private(set) var authenticationState: AuthenticationState = .idle
    @Published private(set) var currentCredentials: NVRCredentials?
    
    private let authService = DahuaNVRAuthService()
    private let keychainHelper = KeychainHelper.shared
    private let authDataKey = "dahua_nvr_auth_data"
    
    private var cancellables = Set<AnyCancellable>()
    
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
}