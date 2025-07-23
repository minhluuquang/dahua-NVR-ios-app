import Foundation
import SwiftUI

@MainActor
class LoginViewModel: ObservableObject {
    @Published var serverURL = AppConfiguration.defaultServerURL
    @Published var username = AppConfiguration.defaultUsername
    @Published var password = AppConfiguration.defaultPassword
    @Published var showingAlert = false
    
    private let authManager = AuthenticationManager.shared
    
    var authenticationState: AuthenticationState {
        authManager.authenticationState
    }
    
    var isFormValid: Bool {
        !serverURL.isEmpty && !username.isEmpty && !password.isEmpty
    }
    
    var isLoading: Bool {
        authenticationState.isLoading
    }
    
    var errorMessage: String? {
        authenticationState.errorMessage
    }
    
    var hasPersistedCredentials: Bool {
        authManager.hasPersistedAuth
    }
    
    func login() async {
        let credentials = NVRCredentials(
            serverURL: serverURL,
            username: username,
            password: password
        )
        
        let nvrName = extractNVRNameFromURL(serverURL)
        let nvrSystem = NVRSystem(
            name: nvrName,
            credentials: credentials,
            isDefault: true
        )
        
        do {
            try await authManager.connectToNVR(nvrSystem)
        } catch {
            showingAlert = true
        }
    }
    
    private func extractNVRNameFromURL(_ url: String) -> String {
        if let urlComponents = URLComponents(string: url),
           let host = urlComponents.host {
            return host
        }
        return "NVR System"
    }
    
    func attemptAutoLogin() async {
        // Auto-login is now handled by AuthenticationManager initialization
        // This method is no longer needed but kept for interface compatibility
    }
    
    func loadPersistedCredentials() {
        if let credentials = authManager.currentCredentials {
            serverURL = credentials.serverURL
            username = credentials.username
            password = credentials.password
        }
    }
    
    func dismissAlert() {
        showingAlert = false
    }
}