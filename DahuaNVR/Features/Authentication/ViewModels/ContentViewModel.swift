import Foundation
import SwiftUI

@MainActor
class ContentViewModel: ObservableObject {
    @Published var isAuthenticated = false
    
    private let authService: DahuaNVRAuthService
    
    init(authService: DahuaNVRAuthService) {
        self.authService = authService
        
        // Observe auth service changes
        authService.$isAuthenticated
            .assign(to: &$isAuthenticated)
    }
    
    func getAuthService() -> DahuaNVRAuthService {
        return authService
    }
}