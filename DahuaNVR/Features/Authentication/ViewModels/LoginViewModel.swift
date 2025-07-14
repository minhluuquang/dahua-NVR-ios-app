import Foundation
import SwiftUI

@MainActor
class LoginViewModel: ObservableObject {
    @Published var serverURL = AppConfiguration.defaultServerURL
    @Published var username = AppConfiguration.defaultUsername
    @Published var password = AppConfiguration.defaultPassword
    @Published var authenticationState: AuthenticationState = .idle
    @Published var showingAlert = false
    
    private let authService: DahuaNVRAuthService
    
    init(authService: DahuaNVRAuthService) {
        self.authService = authService
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
    
    func login() async {
        authenticationState = .loading
        
        let credentials = NVRCredentials(
            serverURL: serverURL,
            username: username,
            password: password
        )
        
        await authService.authenticate(
            serverURL: credentials.serverURL,
            username: credentials.username,
            password: credentials.password
        )
        
        if authService.isAuthenticated {
            authenticationState = .authenticated
        } else {
            let errorMsg = authService.errorMessage ?? "Authentication failed"
            authenticationState = .failed(errorMsg)
            showingAlert = true
        }
    }
    
    func dismissAlert() {
        showingAlert = false
        if case .failed = authenticationState {
            authenticationState = .idle
        }
    }
}