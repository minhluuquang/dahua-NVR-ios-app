import Foundation

struct RPCRequest: Codable {
    let method: String
    let params: [String: AnyJSON]?
    let object: Int
    let session: Int
    
    init(method: String, params: [String: AnyJSON]? = nil, object: Int = 0, session: Int = 0) {
        self.method = method
        self.params = params
        self.object = object
        self.session = session
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(method, forKey: .method)
        try container.encode(object, forKey: .object)
        try container.encode(session, forKey: .session)
        
        if let params = params {
            try container.encode(params, forKey: .params)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case method, params, object, session
    }
}

struct RPCResponse<T: Codable>: Codable {
    let result: T?
    let error: RPCError?
    let id: Int?
    let session: Int?
    
    var isSuccess: Bool {
        return error == nil && result != nil
    }
}

struct RPCError: Codable, Error {
    let code: Int
    let message: String
}


class RPCBase {
    private let baseURL: String
    private var sessionID: String?
    private var sessionCookies: [HTTPCookie] = []
    private let logger = Logger()
    
    init(baseURL: String) {
        self.baseURL = baseURL
    }
    
    func send<T: Codable>(method: String, params: [String: AnyJSON]? = nil, responseType: T.Type) async throws -> RPCResponse<T> {
        let startTime = Date()
        let request = RPCRequest(method: method, params: params)
        
        #if DEBUG
        logger.debug("🚀 RPC API Call: \(method)")
        logger.debug("   → Endpoint: \(baseURL)/RPC2")
        logger.debug("   → Session: \(sessionCookies.isEmpty ? "No cookies" : "\(sessionCookies.count) cookies")")
        if let params = params {
            logger.debug("   → Parameters: \(params)")
        }
        #endif
        
        let url = URL(string: "\(baseURL)/RPC2")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if !sessionCookies.isEmpty {
            let cookieHeader = sessionCookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            urlRequest.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }
        
        do {
            let requestData = try JSONEncoder().encode(request)
            urlRequest.httpBody = requestData
            
            #if DEBUG
            if let requestString = String(data: requestData, encoding: .utf8) {
                logger.debug("RPC Request Body: \(requestString)")
            }
            #endif
            
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
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
            
            if let httpResponse = response as? HTTPURLResponse {
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: httpResponse.allHeaderFields as! [String: String], for: url)
                sessionCookies.append(contentsOf: cookies)
            }
            
            let rpcResponse = try JSONDecoder().decode(RPCResponse<T>.self, from: data)
            
            if let error = rpcResponse.error {
                #if DEBUG
                let errorDuration = Date().timeIntervalSince(startTime)
                logger.error("❌ RPC Error: \(method)")
                logger.error("   → Code: \(error.code)")
                logger.error("   → Message: \(error.message)")
                logger.error("   → Duration: \(String(format: "%.3f", errorDuration))s")
                #endif
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
    
    func setupSession() async throws {
        sessionCookies.removeAll()
        sessionID = nil
        
        #if DEBUG
        logger.debug("Setting up RPC session for \(baseURL)")
        #endif
    }
    
    func clearSession() {
        sessionCookies.removeAll()
        sessionID = nil
        
        #if DEBUG
        logger.debug("Cleared RPC session")
        #endif
    }
    
    var hasActiveSession: Bool {
        return !sessionCookies.isEmpty
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