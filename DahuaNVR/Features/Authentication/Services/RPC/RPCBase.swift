import Foundation

struct RPCRequest: Codable {
    let method: String
    let params: [String: AnyJSON]?
    let object: Int?
    let session: Int?
    let id: Int?
    
    init(method: String, params: [String: AnyJSON]? = nil, object: Int? = nil, session: Int? = nil, id: Int? = nil) {
        self.method = method
        self.params = params
        self.object = object
        self.session = session
        self.id = id
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(method, forKey: .method)
        
        if let object = object {
            try container.encode(object, forKey: .object)
        }
        if let session = session {
            try container.encode(session, forKey: .session)
        }
        if let id = id {
            try container.encode(id, forKey: .id)
        }
        if let params = params {
            try container.encode(params, forKey: .params)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case method, params, object, session, id
    }
}

struct RPCResponse<T: Codable>: Codable {
    let result: T?
    let params: T?  // Add params field for challenge responses
    let error: RPCError?
    let id: Int?
    let session: String?  // Change to String to match actual response
    
    var isSuccess: Bool {
        return error == nil && (result != nil || params != nil)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.params = try container.decodeIfPresent(T.self, forKey: .params)
        self.error = try container.decodeIfPresent(RPCError.self, forKey: .error)
        self.id = try container.decodeIfPresent(Int.self, forKey: .id)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        
        // For the result field, try to decode as T but handle cases where it might be a simple bool
        do {
            self.result = try container.decodeIfPresent(T.self, forKey: .result)
        } catch {
            // If decoding as T fails, try to decode as AnyJSON and see if it's a boolean false
            if let anyResult = try? container.decodeIfPresent(AnyJSON.self, forKey: .result),
               let boolResult = anyResult.bool,
               boolResult == false {
                // This is expected for login challenges
                self.result = nil
            } else {
                // Some other decode error
                throw error
            }
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case result, params, error, id, session
    }
}

struct RPCError: Codable, Error {
    let code: Int
    let message: String
}


class RPCBase {
    private let baseURL: String
    private var sessionID: String?
    private var username: String?
    private let logger = Logger()
    private var requestID: Int = 0
    private let urlSession: URLSession
    private var manualCookies: [String: String] = [:]
    
    init(baseURL: String) {
        self.baseURL = baseURL
        
        // Create URLSession with persistent cookie storage
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        self.urlSession = URLSession(configuration: config)
    }
    
    private func nextRequestID() -> Int {
        requestID += 1
        return requestID
    }
    
    func send<T: Codable>(method: String, params: [String: AnyJSON]? = nil, responseType: T.Type, useLoginEndpoint: Bool = false) async throws -> RPCResponse<T> {
        let startTime = Date()
        let request: RPCRequest
        
        if useLoginEndpoint {
            // For login requests, use id instead of session
            request = RPCRequest(method: method, params: params, id: nextRequestID())
        } else {
            // For regular requests, use stored session ID if available
            let sessionValue = sessionID != nil ? Int(sessionID!) : 0
            request = RPCRequest(method: method, params: params, object: 0, session: sessionValue)
        }
        
        let endpoint = useLoginEndpoint ? "/RPC2_Login" : "/RPC2"
        
        let url = URL(string: "\(baseURL)\(endpoint)")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Set manual cookies for session management
        if !manualCookies.isEmpty {
            let cookieHeaderValue = manualCookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
            urlRequest.setValue(cookieHeaderValue, forHTTPHeaderField: "Cookie")
            #if DEBUG
            logger.debug("   → Manual cookies (\(manualCookies.count)): \(cookieHeaderValue)")
            #endif
        } else {
            #if DEBUG
            logger.debug("   → Manual cookies: None")
            #endif
        }
        
        #if DEBUG
        logger.debug("🚀 RPC API Call: \(method)")
        logger.debug("   → Endpoint: \(baseURL)\(endpoint)")
        
        // Check for existing cookies
        if let cookies = urlSession.configuration.httpCookieStorage?.cookies(for: url), !cookies.isEmpty {
            logger.debug("   → Session: \(cookies.count) cookies")
            // Log cookie details for debugging
            for cookie in cookies {
                logger.debug("   → Cookie: \(cookie.name)=\(cookie.value)")
            }
        } else {
            logger.debug("   → Session: No cookies")
        }
        
        if let params = params {
            logger.debug("   → Parameters: \(params)")
        }
        #endif
        
        do {
            let requestData = try JSONEncoder().encode(request)
            urlRequest.httpBody = requestData
            
            #if DEBUG
            if let requestString = String(data: requestData, encoding: .utf8) {
                logger.debug("RPC Request Body: \(requestString)")
            }
            #endif
            
            let (data, response) = try await urlSession.data(for: urlRequest)
            
            #if DEBUG
            let responseDuration = Date().timeIntervalSince(startTime)
            if let httpResponse = response as? HTTPURLResponse {
                logger.debug("✅ RPC Response: \(method)")
                logger.debug("   → Status: \(httpResponse.statusCode)")
                logger.debug("   → Duration: \(String(format: "%.3f", responseDuration))s")
                if let responseString = String(data: data, encoding: .utf8) {
                    logger.debug("   → Response: \(responseString)")
                }
                
                // Log response cookies for debugging
                if let headerFields = httpResponse.allHeaderFields as? [String: String] {
                    let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
                    for cookie in cookies {
                        logger.debug("   → Response Cookie: \(cookie.name)=\(cookie.value)")
                    }
                }
            }
            #endif
            
            // URLSession handles cookies automatically with the configured cookie storage
            
            let rpcResponse: RPCResponse<T>
            do {
                rpcResponse = try JSONDecoder().decode(RPCResponse<T>.self, from: data)
            } catch {
                #if DEBUG
                logger.error("Failed to decode RPC response: \(error.localizedDescription)")
                if let responseString = String(data: data, encoding: .utf8) {
                    logger.error("Raw response: \(responseString)")
                }
                #endif
                throw RPCError(code: -1, message: "Invalid server response format: \(error.localizedDescription)")
            }
            
            // Store session ID from login response
            if let session = rpcResponse.session {
                sessionID = session
                #if DEBUG
                logger.debug("Stored session ID: \(session)")
                #endif
            }
            
            if let error = rpcResponse.error {
                #if DEBUG
                let errorDuration = Date().timeIntervalSince(startTime)
                logger.error("❌ RPC Error: \(method)")
                logger.error("   → Code: \(error.code)")
                logger.error("   → Message: \(error.message)")
                logger.error("   → Duration: \(String(format: "%.3f", errorDuration))s")
                #endif
                
                // For login challenge errors (268632079 or 401), we should return the response
                // instead of throwing an error so the caller can access the params
                // BUT only for the first login (when we don't have session cookies yet)
                if useLoginEndpoint && (error.code == 268632079 || error.code == 401) {
                    if manualCookies.isEmpty {
                        // First login - challenge is expected
                        #if DEBUG
                        logger.debug("🔓 Login challenge received (expected for first login), returning response with params")
                        #endif
                        return rpcResponse
                    } else {
                        // Second login with session cookies - challenge means authentication failed
                        #if DEBUG
                        logger.error("❌ Unexpected login challenge on second login with session cookies - authentication failed")
                        #endif
                        throw error
                    }
                }
                
                throw error
            }
            
            #if DEBUG
            let successDuration = Date().timeIntervalSince(startTime)
            logger.debug("✅ RPC Success: \(method) completed in \(String(format: "%.3f", successDuration))s")
            #endif
            
            return rpcResponse
        } catch {
            #if DEBUG
            let networkErrorDuration = Date().timeIntervalSince(startTime)
            logger.error("❌ RPC Network Error: \(method)")
            logger.error("   → Error: \(error.localizedDescription)")
            logger.error("   → Duration: \(String(format: "%.3f", networkErrorDuration))s")
            #endif
            throw error
        }
    }
    
    func setSession(id: String, username: String? = nil) {
        sessionID = id
        if let username = username {
            self.username = username
        }
        
        // Store session cookies manually for reliable access
        manualCookies = [
            "WebClientSessionID": id,
            "DWebClientSessionID": id, 
            "DhWebClientSessionID": id
        ]
        
        if let username = self.username {
            manualCookies["username"] = username
        }
        
        #if DEBUG
        logger.debug("Session ID set: \(id)")
        logger.debug("Manual cookies stored: \(manualCookies.count)")
        for (name, value) in manualCookies {
            logger.debug("Manual cookie: \(name)=\(value)")
        }
        #endif
    }
    
    func setupSession() async throws {
        // Clear any existing session data
        sessionID = nil
        username = nil
        requestID = 0
        manualCookies.removeAll()
        
        #if DEBUG
        logger.debug("Setting up RPC session for \(baseURL)")
        #endif
    }
    
    func clearSession() {
        sessionID = nil
        username = nil
        requestID = 0
        manualCookies.removeAll()
        
        #if DEBUG
        logger.debug("Cleared RPC session")
        #endif
    }
    
    var hasActiveSession: Bool {
        if sessionID != nil {
            return true
        }
        
        // Check if we have session cookies
        if let url = URL(string: baseURL),
           let cookieStorage = urlSession.configuration.httpCookieStorage,
           let cookies = cookieStorage.cookies(for: url) {
            return cookies.contains { $0.name == "WebClientSessionID" }
        }
        
        return false
    }
}

private struct Logger {
    func debug(_ message: String) {
        #if DEBUG
        print("[RPC Debug] \(message)")
        #endif
    }
    
    func error(_ message: String) {
        #if DEBUG
        print("[RPC Error] \(message)")
        #endif
    }
}