import Foundation

struct NVRCredentials {
    let serverURL: String
    let username: String
    let password: String
    
    var isValid: Bool {
        !serverURL.isEmpty && !username.isEmpty && !password.isEmpty
    }
}