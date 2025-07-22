import Foundation

struct RPCRequest: Codable {
    let method: String
    let params: [String: AnyJSON]?
    let object: Int?
    let session: String?
    let id: Int?
    
    init(method: String, params: [String: AnyJSON]? = nil, object: Int? = nil, session: String? = nil, id: Int? = nil) {
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
    
    init(baseURL: String) {
        self.baseURL = baseURL
        
        // Simple URLSession configuration - no cookie management needed
        let config = URLSessionConfiguration.default
        self.urlSession = URLSession(configuration: config)
    }
    
    private func nextRequestID() -> Int {
        requestID += 1
        return requestID
    }
    
    func sendDirectResponse<T: Codable>(method: String, params: [String: AnyJSON]? = nil, responseType: T.Type, useLoginEndpoint: Bool = false, includeSession: Bool = false) async throws -> T {
        let startTime = Date()
        let request: RPCRequest
        
        if useLoginEndpoint && !includeSession {
            // First login request - use id instead of session
            request = RPCRequest(method: method, params: params, id: nextRequestID())
        } else {
            // Regular requests or second login - use stored session ID directly
            if includeSession {
                // Second login with session ID
                request = RPCRequest(method: method, params: params, session: sessionID, id: nextRequestID())
            } else {
                // Regular API calls
                request = RPCRequest(method: method, params: params, object: 0, session: sessionID)
            }
        }
        
        let endpoint = useLoginEndpoint ? "/RPC2_Login" : "/RPC2"
        
        let url = URL(string: "\(baseURL)\(endpoint)")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        #if DEBUG
        logger.debug("🚀 RPC Call: \(method)")
        logger.debug("   → Full URL: \(url.absoluteString)")
        logger.debug("   → Endpoint: \(baseURL)\(endpoint)")
        logger.debug("   → Session ID: \(sessionID ?? "none")")
        logger.debug("   → Use Login Endpoint: \(useLoginEndpoint)")
        logger.debug("   → Include Session: \(includeSession)")
        
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
            }
            #endif
            
            // First try to decode as the target type directly
            do {
                let directResponse = try JSONDecoder().decode(T.self, from: data)
                
                // For login responses that include session ID, extract and store it
                if let loginResponse = directResponse as? LoginSuccessResponse {
                    sessionID = loginResponse.session
                    #if DEBUG
                    logger.debug("Stored session ID from direct response: \(loginResponse.session)")
                    #endif
                }
                
                #if DEBUG
                let successDuration = Date().timeIntervalSince(startTime)
                logger.debug("✅ RPC Success: \(method) completed in \(String(format: "%.3f", successDuration))s")
                #endif
                
                return directResponse
                
            } catch {
                #if DEBUG
                logger.error("Failed to decode direct RPC response: \(error.localizedDescription)")
                if let responseString = String(data: data, encoding: .utf8) {
                    logger.error("Raw response: \(responseString)")
                }
                #endif
                throw RPCError(code: -1, message: "Invalid server response format: \(error.localizedDescription)")
            }
            
        } catch {
            #if DEBUG
            let networkErrorDuration = Date().timeIntervalSince(startTime)
            logger.error("❌ RPC Network Error: \(method)")
            logger.error("   → Full URL: \(url.absoluteString)")
            logger.error("   → Error: \(error.localizedDescription)")
            logger.error("   → Error Type: \(type(of: error))")
            logger.error("   → Duration: \(String(format: "%.3f", networkErrorDuration))s")
            
            // Log the request that failed
            if let requestData = urlRequest.httpBody,
               let requestString = String(data: requestData, encoding: .utf8) {
                logger.error("   → Failed Request Body: \(requestString)")
            }
            
            // Check for specific network errors
            if let urlError = error as? URLError {
                logger.error("   → URLError Code: \(urlError.code.rawValue)")
                logger.error("   → URLError Description: \(urlError.localizedDescription)")
            }
            #endif
            throw error
        }
    }

    func send<T: Codable>(method: String, params: [String: AnyJSON]? = nil, responseType: T.Type, useLoginEndpoint: Bool = false, includeSession: Bool = false) async throws -> RPCResponse<T> {
        let startTime = Date()
        let request: RPCRequest
        
        if useLoginEndpoint && !includeSession {
            // First login request - use id instead of session
            request = RPCRequest(method: method, params: params, id: nextRequestID())
        } else {
            // Regular requests or second login - use stored session ID directly
            if includeSession {
                // Second login with session ID
                request = RPCRequest(method: method, params: params, session: sessionID, id: nextRequestID())
            } else {
                // Regular API calls
                request = RPCRequest(method: method, params: params, object: 0, session: sessionID)
            }
        }
        
        let endpoint = useLoginEndpoint ? "/RPC2_Login" : "/RPC2"
        
        let url = URL(string: "\(baseURL)\(endpoint)")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        #if DEBUG
        logger.debug("🚀 RPC Call: \(method)")
        logger.debug("   → Full URL: \(url.absoluteString)")
        logger.debug("   → Endpoint: \(baseURL)\(endpoint)")
        logger.debug("   → Session ID: \(sessionID ?? "none")")
        logger.debug("   → Use Login Endpoint: \(useLoginEndpoint)")
        logger.debug("   → Include Session: \(includeSession)")
        
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
            }
            #endif
            
            
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
                
                // For login challenge errors (268632079 or 401), return the response for the first login
                // so the caller can access the challenge params
                if useLoginEndpoint && !includeSession && (error.code == 268632079 || error.code == 401) {
                    // First login - challenge is expected
                    #if DEBUG
                    logger.debug("🔓 Login challenge received (expected for first login)")
                    #endif
                    return rpcResponse
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
            logger.error("   → Full URL: \(url.absoluteString)")
            logger.error("   → Error: \(error.localizedDescription)")
            logger.error("   → Error Type: \(type(of: error))")
            logger.error("   → Duration: \(String(format: "%.3f", networkErrorDuration))s")
            
            // Log the request that failed
            if let requestData = urlRequest.httpBody,
               let requestString = String(data: requestData, encoding: .utf8) {
                logger.error("   → Failed Request Body: \(requestString)")
            }
            
            // Check for specific network errors
            if let urlError = error as? URLError {
                logger.error("   → URLError Code: \(urlError.code.rawValue)")
                logger.error("   → URLError Description: \(urlError.localizedDescription)")
            }
            #endif
            throw error
        }
    }
    
    func setSession(id: String, username: String? = nil) {
        sessionID = id
        if let username = username {
            self.username = username
        }
        
        #if DEBUG
        logger.debug("📋 Session established: \(id)")
        if let username = self.username {
            logger.debug("   → Username: \(username)")
        }
        #endif
    }
    
    func setupSession() async throws {
        // Clear any existing session data
        sessionID = nil
        username = nil
        requestID = 0
        
        #if DEBUG
        logger.debug("🔧 Setting up RPC session for \(baseURL)")
        #endif
    }
    
    func clearSession() {
        sessionID = nil
        username = nil
        requestID = 0
        
        #if DEBUG
        logger.debug("🧹 Cleared RPC session")
        #endif
    }
    
    var hasActiveSession: Bool {
        return sessionID != nil
    }
    
    // Special method for OutsideCmd endpoint
    func sendOutsideCmd<T: Codable>(method: String, params: [String: AnyJSON]? = nil, responseType: T.Type) async throws -> RPCResponse<T> {
        let startTime = Date()
        let request = RPCRequest(method: method, params: params, id: nextRequestID())
        
        let url = URL(string: "\(baseURL)/OutsideCmd")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
        urlRequest.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        
        #if DEBUG
        logger.debug("🚀 OutsideCmd RPC Call: \(method)")
        logger.debug("   → Full URL: \(url.absoluteString)")
        logger.debug("   → Request ID: \(request.id ?? 0)")
        #endif
        
        do {
            let requestData = try JSONEncoder().encode(request)
            urlRequest.httpBody = requestData
            
            #if DEBUG
            if let requestString = String(data: requestData, encoding: .utf8) {
                logger.debug("OutsideCmd Request Body: \(requestString)")
            }
            #endif
            
            let (data, response) = try await urlSession.data(for: urlRequest)
            
            #if DEBUG
            let responseDuration = Date().timeIntervalSince(startTime)
            if let httpResponse = response as? HTTPURLResponse {
                logger.debug("✅ OutsideCmd Response: \(method)")
                logger.debug("   → Status: \(httpResponse.statusCode)")
                logger.debug("   → Duration: \(String(format: "%.3f", responseDuration))s")
                if let responseString = String(data: data, encoding: .utf8) {
                    logger.debug("   → Response: \(responseString)")
                }
            }
            #endif
            
            let rpcResponse = try JSONDecoder().decode(RPCResponse<T>.self, from: data)
            return rpcResponse
            
        } catch {
            #if DEBUG
            let networkErrorDuration = Date().timeIntervalSince(startTime)
            logger.error("❌ OutsideCmd Network Error: \(method)")
            logger.error("   → Full URL: \(url.absoluteString)")
            logger.error("   → Error: \(error.localizedDescription)")
            logger.error("   → Duration: \(String(format: "%.3f", networkErrorDuration))s")
            #endif
            throw error
        }
    }
    
    // Special method for OutsideCmd endpoint that decodes directly (not wrapped in RPCResponse)
    func sendOutsideCmdDirect<T: Codable>(method: String, params: [String: AnyJSON]? = nil, responseType: T.Type) async throws -> T {
        let startTime = Date()
        let request = RPCRequest(method: method, params: params, id: nextRequestID())
        
        let url = URL(string: "\(baseURL)/OutsideCmd")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
        urlRequest.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        
        #if DEBUG
        logger.debug("🚀 OutsideCmd Direct Call: \(method)")
        logger.debug("   → Full URL: \(url.absoluteString)")
        logger.debug("   → Request ID: \(request.id ?? 0)")
        #endif
        
        do {
            let requestData = try JSONEncoder().encode(request)
            urlRequest.httpBody = requestData
            
            #if DEBUG
            if let requestString = String(data: requestData, encoding: .utf8) {
                logger.debug("OutsideCmd Direct Request Body: \(requestString)")
            }
            #endif
            
            let (data, response) = try await urlSession.data(for: urlRequest)
            
            #if DEBUG
            let responseDuration = Date().timeIntervalSince(startTime)
            if let httpResponse = response as? HTTPURLResponse {
                logger.debug("✅ OutsideCmd Direct Response: \(method)")
                logger.debug("   → Status: \(httpResponse.statusCode)")
                logger.debug("   → Duration: \(String(format: "%.3f", responseDuration))s")
                if let responseString = String(data: data, encoding: .utf8) {
                    logger.debug("   → Response: \(responseString)")
                }
            }
            #endif
            
            let directResponse = try JSONDecoder().decode(T.self, from: data)
            return directResponse
            
        } catch {
            #if DEBUG
            let networkErrorDuration = Date().timeIntervalSince(startTime)
            logger.error("❌ OutsideCmd Direct Network Error: \(method)")
            logger.error("   → Full URL: \(url.absoluteString)")
            logger.error("   → Error: \(error.localizedDescription)")
            logger.error("   → Duration: \(String(format: "%.3f", networkErrorDuration))s")
            #endif
            throw error
        }
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