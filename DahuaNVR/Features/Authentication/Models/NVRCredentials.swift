import Foundation

struct NVRCredentials: Codable {
    let serverURL: String
    let username: String
    let password: String
    
    var isValid: Bool {
        !serverURL.isEmpty && !username.isEmpty && !password.isEmpty
    }
}