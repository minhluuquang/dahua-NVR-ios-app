import Foundation
import CryptoKit

class DahuaNVRAuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    internal var baseURL: String = ""
    internal var username: String = ""
    internal var password: String = ""
    private let logger = Logger()
    
    func authenticate(serverURL: String, username: String, password: String) async {
        #if DEBUG
        logger.debug("🔐 Starting CGI Authentication")
        logger.debug("   → Protocol: Dahua HTTP CGI digest authentication")
        logger.debug("   → Server URL: \(serverURL)")
        logger.debug("   → Username: \(username.isEmpty ? "empty" : username)")
        logger.debug("   → Process: Two-stage digest authentication flow")
        #endif
        
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
            
            #if DEBUG
            if success {
                logger.debug("🎉 CGI Authentication Complete")
                logger.debug("   → Status: Successfully authenticated with digest auth")
            } else {
                logger.error("❌ CGI Authentication Failed")
                logger.error("   → Status: Authentication unsuccessful")
            }
            #endif
            
        } catch {
            #if DEBUG
            logger.error("❌ CGI Authentication Error: \(error.localizedDescription)")
            if let authError = error as? AuthError {
                logger.error("   → Error Type: \(authError)")
            }
            #endif
            
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func performDigestAuth() async throws -> Bool {
        let testEndpoint = "/cgi-bin/magicBox.cgi?action=getLanguageCaps"
        guard let url = URL(string: baseURL + testEndpoint) else {
            #if DEBUG
            logger.error("❌ CGI Error: Invalid URL")
            logger.error("   → Base URL: \(baseURL)")
            logger.error("   → Endpoint: \(testEndpoint)")
            #endif
            throw AuthError.invalidURL
        }
        
        #if DEBUG
        logger.debug("🚀 CGI Step 1: Initial request for auth challenge")
        logger.debug("   → URL: \(url.absoluteString)")
        logger.debug("   → Method: GET")
        logger.debug("   → User-Agent: DahuaNVR/1.0")
        #endif
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("DahuaNVR/1.0", forHTTPHeaderField: "User-Agent")
        
        let startTime = Date()
        let (data, response) = try await URLSession.shared.data(for: request)
        let duration = Date().timeIntervalSince(startTime)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            #if DEBUG
            logger.error("❌ CGI Error: Invalid response type")
            logger.error("   → Response: \(response)")
            #endif
            throw AuthError.invalidResponse
        }
        
        #if DEBUG
        logger.debug("✅ CGI Step 1 Response")
        logger.debug("   → Status: \(httpResponse.statusCode)")
        logger.debug("   → Duration: \(String(format: "%.3f", duration))s")
        if let responseString = String(data: data, encoding: .utf8) {
            logger.debug("   → Response Body: \(responseString.prefix(200))...")
        }
        if let authHeader = httpResponse.value(forHTTPHeaderField: "WWW-Authenticate") {
            logger.debug("   → WWW-Authenticate: \(authHeader)")
        }
        #endif
        
        if httpResponse.statusCode == 401 {
            #if DEBUG
            logger.debug("🔓 CGI Challenge received (expected for digest auth)")
            #endif
            
            guard let authHeader = httpResponse.value(forHTTPHeaderField: "WWW-Authenticate") else {
                #if DEBUG
                logger.error("❌ CGI Error: Missing WWW-Authenticate header")
                logger.error("   → Available headers: \(httpResponse.allHeaderFields.keys)")
                #endif
                throw AuthError.missingAuthHeader
            }
            
            let digestParams = try parseDigestHeader(authHeader)
            
            #if DEBUG
            logger.debug("✅ CGI Step 1 Complete: Challenge parsed")
            logger.debug("   → Realm: \(digestParams["realm"] ?? "missing")")
            logger.debug("   → Nonce: \(digestParams["nonce"]?.prefix(16) ?? "missing")...")
            logger.debug("   → QOP: \(digestParams["qop"] ?? "none")")
            logger.debug("   → Opaque: \(digestParams["opaque"] ?? "none")")
            logger.debug("   → Next: Step 2 - Authenticated request")
            #endif
            
            let authRequest = try buildAuthenticatedRequest(url: url, digestParams: digestParams)
            
            #if DEBUG
            logger.debug("🚀 CGI Step 2: Authenticated request")
            logger.debug("   → URL: \(url.absoluteString)")
            logger.debug("   → Method: GET")
            if let authHeaderValue = authRequest.value(forHTTPHeaderField: "Authorization") {
                logger.debug("   → Authorization: \(authHeaderValue.prefix(80))...")
            }
            #endif
            
            let authStartTime = Date()
            let (authData, authResponse) = try await URLSession.shared.data(for: authRequest)
            let authDuration = Date().timeIntervalSince(authStartTime)
            
            guard let authHttpResponse = authResponse as? HTTPURLResponse else {
                #if DEBUG
                logger.error("❌ CGI Step 2 Error: Invalid response type")
                logger.error("   → Response: \(authResponse)")
                #endif
                throw AuthError.invalidResponse
            }
            
            #if DEBUG
            logger.debug("✅ CGI Step 2 Response")
            logger.debug("   → Status: \(authHttpResponse.statusCode)")
            logger.debug("   → Duration: \(String(format: "%.3f", authDuration))s")
            if let authResponseString = String(data: authData, encoding: .utf8) {
                logger.debug("   → Response Body: \(authResponseString.prefix(200))...")
            }
            
            if authHttpResponse.statusCode == 200 {
                logger.debug("✅ CGI Step 2 Success: Authentication accepted")
            } else {
                logger.error("❌ CGI Step 2 Failed: Authentication rejected")
                logger.error("   → Status Code: \(authHttpResponse.statusCode)")
                logger.error("   → This usually indicates incorrect credentials")
            }
            #endif
            
            return authHttpResponse.statusCode == 200
        }
        
        #if DEBUG
        if httpResponse.statusCode == 200 {
            logger.debug("✅ CGI Authentication: No challenge required (already authenticated)")
        } else {
            logger.error("❌ CGI Authentication: Unexpected status code")
            logger.error("   → Status: \(httpResponse.statusCode)")
            logger.error("   → Expected: 401 (challenge) or 200 (success)")
        }
        #endif
        
        return httpResponse.statusCode == 200
    }
    
    internal func parseDigestHeader(_ header: String) throws -> [String: String] {
        #if DEBUG
        logger.debug("🔍 CGI Parsing digest header")
        logger.debug("   → Raw header: \(header)")
        #endif
        
        var params: [String: String] = [:]
        
        let headerValue = header.replacingOccurrences(of: "Digest ", with: "")
        
        #if DEBUG
        logger.debug("   → Cleaned header: \(headerValue)")
        #endif
        
        // Better parsing that handles quoted values properly
        let regex = try! NSRegularExpression(pattern: #"(\w+)=(?:"([^"]*)"|([^,\s]+))"#)
        let range = NSRange(headerValue.startIndex..<headerValue.endIndex, in: headerValue)
        let matches = regex.matches(in: headerValue, range: range)
        
        #if DEBUG
        logger.debug("   → Found \(matches.count) parameter matches")
        #endif
        
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
                    
                    #if DEBUG
                    if key == "nonce" {
                        logger.debug("   → \(key): \(value.prefix(16))...")
                    } else {
                        logger.debug("   → \(key): \(value)")
                    }
                    #endif
                }
            }
        }
        
        guard params["realm"] != nil,
              params["nonce"] != nil else {
            #if DEBUG
            logger.error("❌ CGI Error: Invalid digest header - missing required params")
            logger.error("   → Has realm: \(params["realm"] != nil)")
            logger.error("   → Has nonce: \(params["nonce"] != nil)")
            logger.error("   → All params: \(params.keys)")
            #endif
            throw AuthError.invalidDigestHeader
        }
        
        #if DEBUG
        logger.debug("✅ CGI Digest header parsed successfully")
        #endif
        
        return params
    }
    
    internal func buildAuthenticatedRequest(url: URL, digestParams: [String: String]) throws -> URLRequest {
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
        logger.debug("🔐 CGI Calculating digest response")
        logger.debug("   → HA1 input: \(username):\(realm):password")
        logger.debug("   → HA1 hash: \(ha1)")
        logger.debug("   → HA2 input: \(method):\(uri)")
        logger.debug("   → HA2 hash: \(ha2)")
        logger.debug("   → QOP: \(qop)")
        logger.debug("   → NC: \(nc)")
        logger.debug("   → CNonce: \(cnonce)")
        #endif
        
        let response: String
        if qop == "auth" {
            let responseInput = "\(ha1):\(nonce):\(nc):\(cnonce):\(qop):\(ha2)"
            response = md5(responseInput)
            #if DEBUG
            logger.debug("   → Response input: \(responseInput)")
            logger.debug("   → Response hash: \(response)")
            logger.debug("   → Algorithm: MD5(HA1:nonce:nc:cnonce:qop:HA2)")
            #endif
        } else {
            let responseInput = "\(ha1):\(nonce):\(ha2)"
            response = md5(responseInput)
            #if DEBUG
            logger.debug("   → Response input: \(responseInput)")
            logger.debug("   → Response hash: \(response)")
            logger.debug("   → Algorithm: MD5(HA1:nonce:HA2)")
            #endif
        }
        
        var authHeader = "Digest username=\"\(username)\", realm=\"\(realm)\", nonce=\"\(nonce)\", uri=\"\(uri)\", response=\"\(response)\""
        
        if qop == "auth" {
            authHeader += ", qop=\(qop), nc=\(nc), cnonce=\"\(cnonce)\""
        }
        
        if let opaque = opaque {
            authHeader += ", opaque=\"\(opaque)\""
        }
        
        #if DEBUG
        logger.debug("✅ CGI Built authorization header")
        logger.debug("   → Header length: \(authHeader.count) chars")
        logger.debug("   → Complete header: \(authHeader)")
        #endif
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("DahuaNVR/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        
        return request
    }
    
    internal func generateCnonce() -> String {
        let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        return String((0..<8).map { _ in chars.randomElement()! })
    }
    
    internal func md5(_ string: String) -> String {
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

private struct Logger {
    func debug(_ message: String) {
        #if DEBUG
        print("[CGI Debug] \(message)")
        #endif
    }
    
    func error(_ message: String) {
        #if DEBUG
        print("[CGI Error] \(message)")
        #endif
    }
}