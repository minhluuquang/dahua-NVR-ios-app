import Foundation
import CryptoKit

class DahuaNVRAuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var baseURL: String = ""
    private var username: String = ""
    private var password: String = ""
    
    func authenticate(serverURL: String, username: String, password: String) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        self.baseURL = serverURL
        self.username = username
        self.password = password
        
        do {
            let success = try await performDigestAuth()
            await MainActor.run {
                self.isAuthenticated = success
                self.isLoading = false
                if !success {
                    self.errorMessage = "Authentication failed. Please check your credentials."
                }
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func performDigestAuth() async throws -> Bool {
        let testEndpoint = "/cgi-bin/magicBox.cgi?action=getLanguageCaps"
        guard let url = URL(string: baseURL + testEndpoint) else {
            throw AuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("DahuaNVR/1.0", forHTTPHeaderField: "User-Agent")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            guard let authHeader = httpResponse.value(forHTTPHeaderField: "WWW-Authenticate") else {
                throw AuthError.missingAuthHeader
            }
            
            let digestParams = try parseDigestHeader(authHeader)
            let authRequest = try buildAuthenticatedRequest(url: url, digestParams: digestParams)
            
            let (_, authResponse) = try await URLSession.shared.data(for: authRequest)
            
            guard let authHttpResponse = authResponse as? HTTPURLResponse else {
                throw AuthError.invalidResponse
            }
            
            return authHttpResponse.statusCode == 200
        }
        
        return httpResponse.statusCode == 200
    }
    
    private func parseDigestHeader(_ header: String) throws -> [String: String] {
        var params: [String: String] = [:]
        
        let headerValue = header.replacingOccurrences(of: "Digest ", with: "")
        
        // Better parsing that handles quoted values properly
        let regex = try! NSRegularExpression(pattern: #"(\w+)=(?:"([^"]*)"|([^,\s]+))"#)
        let range = NSRange(headerValue.startIndex..<headerValue.endIndex, in: headerValue)
        let matches = regex.matches(in: headerValue, range: range)
        
        for match in matches {
            if match.numberOfRanges >= 3 {
                let keyRange = match.range(at: 1)
                let quotedValueRange = match.range(at: 2)
                let unquotedValueRange = match.range(at: 3)
                
                if let keySwiftRange = Range(keyRange, in: headerValue) {
                    let key = String(headerValue[keySwiftRange])
                    
                    var value: String
                    if quotedValueRange.location != NSNotFound,
                       let valueSwiftRange = Range(quotedValueRange, in: headerValue) {
                        value = String(headerValue[valueSwiftRange])
                    } else if unquotedValueRange.location != NSNotFound,
                              let valueSwiftRange = Range(unquotedValueRange, in: headerValue) {
                        value = String(headerValue[valueSwiftRange])
                    } else {
                        continue
                    }
                    
                    params[key] = value
                }
            }
        }
        
        guard params["realm"] != nil,
              params["nonce"] != nil else {
            throw AuthError.invalidDigestHeader
        }
        
        return params
    }
    
    private func buildAuthenticatedRequest(url: URL, digestParams: [String: String]) throws -> URLRequest {
        guard let realm = digestParams["realm"],
              let nonce = digestParams["nonce"] else {
            throw AuthError.invalidDigestHeader
        }
        
        let qop = digestParams["qop"] ?? "auth"
        let opaque = digestParams["opaque"]
        let uri = url.path + (url.query != nil ? "?" + url.query! : "")
        let method = "GET"
        let nc = "00000001"
        let cnonce = generateCnonce()
        
        let ha1 = md5("\(username):\(realm):\(password)")
        let ha2 = md5("\(method):\(uri)")
        
        #if DEBUG
        print("[HTTP Auth Debug] Generating digest response:")
        print("   → HA1 input: \(username):\(realm):\(password)")
        print("   → HA1 hash: \(ha1)")
        print("   → HA2 input: \(method):\(uri)")
        print("   → HA2 hash: \(ha2)")
        print("   → QOP: \(qop)")
        print("   → NC: \(nc)")
        print("   → CNonce: \(cnonce)")
        #endif
        
        let response: String
        if qop == "auth" {
            let responseInput = "\(ha1):\(nonce):\(nc):\(cnonce):\(qop):\(ha2)"
            response = md5(responseInput)
            #if DEBUG
            print("   → Response input: \(responseInput)")
            print("   → Response hash: \(response)")
            #endif
        } else {
            let responseInput = "\(ha1):\(nonce):\(ha2)"
            response = md5(responseInput)
            #if DEBUG
            print("   → Response input: \(responseInput)")
            print("   → Response hash: \(response)")
            #endif
        }
        
        var authHeader = "Digest username=\"\(username)\", realm=\"\(realm)\", nonce=\"\(nonce)\", uri=\"\(uri)\", response=\"\(response)\""
        
        if qop == "auth" {
            authHeader += ", qop=\(qop), nc=\(nc), cnonce=\"\(cnonce)\""
        }
        
        if let opaque = opaque {
            authHeader += ", opaque=\"\(opaque)\""
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("DahuaNVR/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        
        return request
    }
    
    private func generateCnonce() -> String {
        let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        return String((0..<8).map { _ in chars.randomElement()! })
    }
    
    private func md5(_ string: String) -> String {
        let digest = Insecure.MD5.hash(data: string.data(using: .utf8)!)
        return digest.map { String(format: "%02x", $0) }.joined().lowercased()
    }
    
    func logout() {
        isAuthenticated = false
        username = ""
        password = ""
        baseURL = ""
        errorMessage = nil
    }
}

enum AuthError: LocalizedError {
    case invalidURL
    case invalidResponse
    case missingAuthHeader
    case invalidDigestHeader
    case authenticationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .missingAuthHeader:
            return "Missing authentication header"
        case .invalidDigestHeader:
            return "Invalid digest authentication header"
        case .authenticationFailed:
            return "Authentication failed"
        }
    }
}