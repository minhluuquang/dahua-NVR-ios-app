import Foundation

enum AuthenticationState: Equatable {
    case idle
    case loading
    case authenticated
    case failed(String)
    
    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
    
    var isAuthenticated: Bool {
        if case .authenticated = self {
            return true
        }
        return false
    }
    
    var errorMessage: String? {
        if case .failed(let message) = self {
            return message
        }
        return nil
    }
}