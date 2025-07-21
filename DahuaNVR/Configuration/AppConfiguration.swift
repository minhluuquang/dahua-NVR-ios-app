import Foundation
import CryptoSwift

struct AppConfiguration {
    static let defaultServerURL: String = {
        #if DEBUG
        return Bundle.main.object(forInfoDictionaryKey: "DEFAULT_SERVER_URL") as? String ?? "http://cam.lab"
        #else
        return Bundle.main.object(forInfoDictionaryKey: "DEFAULT_SERVER_URL") as? String ?? ""
        #endif
    }()
    
    static let defaultUsername: String = {
        #if DEBUG
        return Bundle.main.object(forInfoDictionaryKey: "DEFAULT_USERNAME") as? String ?? "admin"
        #else
        return Bundle.main.object(forInfoDictionaryKey: "DEFAULT_USERNAME") as? String ?? ""
        #endif
    }()
    
    static let defaultPassword: String = {
        #if DEBUG
        return Bundle.main.object(forInfoDictionaryKey: "DEFAULT_PASSWORD") as? String ?? ""
        #else
        return ""
        #endif
    }()
}
