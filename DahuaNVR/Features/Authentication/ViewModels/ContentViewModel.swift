import Foundation
import SwiftUI
import Combine

@MainActor
class ContentViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isInitializing = true
    
    private let authManager = AuthenticationManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        bindAuthManager()
        initializeAuth()
    }
    
    private func bindAuthManager() {
        authManager.$authenticationState
            .map { $0 == .authenticated }
            .assign(to: \.isAuthenticated, on: self)
            .store(in: &cancellables)
    }
    
    private func initializeAuth() {
        // Auto-login is now handled by AuthenticationManager initialization
        isInitializing = false
    }
    
    func logout() async {
        await authManager.logout()
    }
}