import CryptoKit
import Foundation

struct AuthParams: Codable {
    let random: String
    let realm: String
    let encryption: String
    let authorization: String?

    init(random: String, realm: String, encryption: String, authorization: String? = nil) {
        self.random = random
        self.realm = realm
        self.encryption = encryption
        self.authorization = authorization
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.random = try container.decode(String.self, forKey: .random)
        self.realm = try container.decode(String.self, forKey: .realm)
        self.encryption = try container.decode(String.self, forKey: .encryption)
        self.authorization = try container.decodeIfPresent(String.self, forKey: .authorization)
    }

    private enum CodingKeys: String, CodingKey {
        case random, realm, encryption, authorization
    }
}

struct LoginResult: Codable {
    let keepAliveInterval: Int?
    let session: Int?
    let rspCode: Int?
}

struct FirstLoginParams: Codable {
    let clientType: String
    let ipAddr: String?
    let loginType: String
    let userName: String
    let password: String

    init(username: String, password: String = "", clientIP: String? = nil) {
        self.clientType = "Web3.0"  // Match reference implementation
        self.ipAddr = clientIP
        self.loginType = "Direct"
        self.userName = username
        self.password = password
    }
}

struct SecondLoginParams: Codable {
    let userName: String
    let password: String
    let clientType: String
    let ipAddr: String?
    let loginType: String
    let authorityType: String?
    let passwordType: String?

    init(
        username: String, hashedPassword: String, clientIP: String? = nil,
        authorityType: String? = nil, passwordType: String? = nil
    ) {
        self.userName = username
        self.password = hashedPassword
        self.clientType = "Web3.0"  // Match reference implementation
        self.ipAddr = clientIP
        self.loginType = "Direct"
        self.authorityType = authorityType
        self.passwordType = passwordType
    }
}

class RPCLogin {
    private let rpcBase: RPCBase
    private let logger = Logger()
    private var keepAliveTimer: Timer?
    private var keepAliveInterval: Int = 60

    init(rpcBase: RPCBase) {
        self.rpcBase = rpcBase
    }

    deinit {
        stopKeepAlive()
    }

    func login(username: String, password: String) async throws {
        #if DEBUG
            logger.debug("🔐 Starting RPC Authentication")
            logger.debug("   → Protocol: Dahua JSON-RPC challenge-response")
            logger.debug("   → Username: \(username.isEmpty ? "empty" : username)")
            logger.debug("   → Process: Two-stage authentication flow")
        #endif

        try await rpcBase.setupSession()

        let authParams = try await firstLogin(username: username, password: password)

        #if DEBUG
            logger.debug("✅ Step 1 Complete: Challenge received")
            logger.debug("   → Challenge random: \(authParams.random.prefix(8))...")
            logger.debug("   → Challenge realm: \(authParams.realm)")
            logger.debug("   → Encryption type: \(authParams.encryption)")
            logger.debug("   → Next: Step 2 - Authenticated request with session")
        #endif

        try await secondLogin(username: username, password: password, authParams: authParams)

        #if DEBUG
            logger.debug("🎉 RPC Authentication Complete")
            logger.debug("   → Status: Session established successfully")
            logger.debug("   → Keep-alive: Started (\(keepAliveInterval)s intervals)")
        #endif

        startKeepAlive()
    }

    func logout() async throws {
        #if DEBUG
            logger.debug("Logging out from RPC session")
        #endif

        stopKeepAlive()

        do {
            let _: RPCResponse<EmptyResponse> = try await rpcBase.send(
                method: "global.logout",
                responseType: EmptyResponse.self,
                useLoginEndpoint: false  // Use regular /RPC2 endpoint for logout (matches reference)
            )
            #if DEBUG
                logger.debug("RPC logout successful")
            #endif
        } catch {
            #if DEBUG
                logger.error("RPC logout failed: \(error.localizedDescription)")
            #endif
        }

        rpcBase.clearSession()
    }

    private func firstLogin(username: String, password: String) async throws -> AuthParams {
        let params = FirstLoginParams(username: username)

        var paramsDict: [String: AnyJSON] = [
            "clientType": AnyJSON(params.clientType),
            "loginType": AnyJSON(params.loginType),
            "userName": AnyJSON(params.userName),
            "password": AnyJSON(params.password),
        ]

        // Only include ipAddr if it's provided
        if let ipAddr = params.ipAddr {
            paramsDict["ipAddr"] = AnyJSON(ipAddr)
        }

        // Use AnyJSON as the response type to handle the flexible JSON structure
        let response: RPCResponse<AnyJSON> = try await rpcBase.send(
            method: "global.login",
            params: paramsDict,
            responseType: AnyJSON.self,
            useLoginEndpoint: true
        )

        // Capture session ID from first login response if present
        if let sessionID = response.session {
            rpcBase.setSession(id: sessionID, username: username)
            #if DEBUG
                logger.debug("Session ID captured and set: \(sessionID)")
            #endif
        } else {
            throw RPCError(code: -1, message: "Session ID missing from first login response")
        }

        // For challenge responses, the auth parameters are in the params field
        // This is the expected path for first login (challenge response)
        guard let paramsJSON = response.params,
            let paramsDict = paramsJSON.dictionary
        else {
            throw RPCError(code: -1, message: "No auth parameters received from first login")
        }

        // Parse auth parameters using type-safe decoding
        let authParams: AuthParams
        do {
            let paramsData = try JSONSerialization.data(withJSONObject: paramsDict)
            authParams = try JSONDecoder().decode(AuthParams.self, from: paramsData)
        } catch {
            throw RPCError(
                code: -1, message: "Invalid auth parameters format: \(error.localizedDescription)")
        }

        #if DEBUG
            logger.debug("✅ Step 1: Challenge received as expected")
            logger.debug("   → Session ID: \(response.session ?? "missing")")
            logger.debug("   → Challenge params: random=\(authParams.random), realm=\(authParams.realm), encryption=\(authParams.encryption)")
        #endif

        return authParams
    }

    private func secondLogin(username: String, password: String, authParams: AuthParams)
        async throws
    {
        let hashedPassword = generateDigestAuth(
            username: username, password: password, authParams: authParams)

        let params = SecondLoginParams(
            username: username,
            hashedPassword: hashedPassword,
            authorityType: authParams.encryption,
            passwordType: authParams.encryption
        )

        var paramsDict: [String: AnyJSON] = [
            "userName": AnyJSON(params.userName),
            "password": AnyJSON(params.password),
            "clientType": AnyJSON(params.clientType),
        ]

        // Only include optional fields if they're provided
        if let ipAddr = params.ipAddr {
            paramsDict["ipAddr"] = AnyJSON(ipAddr)
        }
        if let authorityType = params.authorityType {
            paramsDict["authorityType"] = AnyJSON(authorityType)
        }
        if let passwordType = params.passwordType {
            paramsDict["passwordType"] = AnyJSON(passwordType)
        }

        do {
            // For the second login, we need to handle the response differently
            // as it has a special structure that doesn't fit the generic RPCResponse model
            let response: LoginSuccessResponse = try await rpcBase.sendDirectResponse(
                method: "global.login",
                params: paramsDict,
                responseType: LoginSuccessResponse.self,
                useLoginEndpoint: true,  // Use /RPC2_Login endpoint
                includeSession: true     // Include session ID in second login request
            )

            // Check if the login was successful
            guard response.result == true else {
                throw RPCError(
                    code: -1,
                    message: "Authentication failed - server returned result: \(response.result)"
                )
            }

            // Process successful login result
            keepAliveInterval = response.params.keepAliveInterval
            #if DEBUG
                logger.debug("Keep alive interval set to: \(keepAliveInterval) seconds")
            #endif

            #if DEBUG
                logger.debug("✅ Step 2: Authentication successful")
                logger.debug("   → Session validated and active")
            #endif

        } catch let rpcError as RPCError {
            #if DEBUG
                logger.error("❌ Step 2 failed: \(rpcError.message)")
                logger.error("   → Authentication with calculated response rejected")
            #endif
            throw RPCError(
                code: rpcError.code,
                message: "Authentication failed: \(rpcError.message)")
        }
    }

    private func generateDigestAuth(username: String, password: String, authParams: AuthParams)
        -> String
    {
        switch authParams.encryption {
        case "Basic":
            // Basic auth: base64(username:password)
            let credentials = "\(username):\(password)"
            return Data(credentials.utf8).base64EncodedString()

        case "Default":
            // Default auth: MD5(username:random:MD5(username:realm:password))
            // This is the standard Dahua RPC authentication format
            let realmHash = md5Hash("\(username):\(authParams.realm):\(password)")
            let finalHash = md5Hash("\(username):\(authParams.random):\(realmHash)")

            #if DEBUG
                logger.debug("🔐 Calculating authentication response (Default encryption)")
                logger.debug("   → Step 1: MD5(\(username):\(authParams.realm):password) = \(realmHash)")
                logger.debug("   → Step 2: MD5(\(username):\(authParams.random):\(realmHash)) = \(finalHash)")
                logger.debug("   → Algorithm: MD5(username:random:MD5(username:realm:password))")
            #endif

            return finalHash

        default:
            // Unknown encryption type, return password as-is
            #if DEBUG
                logger.debug(
                    "Unknown encryption type: \(authParams.encryption), using password as-is")
            #endif
            return password
        }
    }

    private func md5Hash(_ string: String) -> String {
        let inputData = Data(string.utf8)
        let hashed = Insecure.MD5.hash(data: inputData)
        return hashed.map { String(format: "%02hhX", $0) }.joined()
    }

    private func startKeepAlive() {
        stopKeepAlive()

        keepAliveTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(keepAliveInterval), repeats: true
        ) { [weak self] _ in
            Task {
                await self?.sendKeepAlive()
            }
        }

        #if DEBUG
            logger.debug("Started keep alive timer with interval: \(keepAliveInterval) seconds")
        #endif
    }

    private func stopKeepAlive() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil

        #if DEBUG
            logger.debug("Stopped keep alive timer")
        #endif
    }

    private func sendKeepAlive() async {
        do {
            let params: [String: AnyJSON] = [
                "timeout": AnyJSON(300),
                "active": AnyJSON(true),
            ]

            let _: RPCResponse<[String: Int]> = try await rpcBase.send(
                method: "global.keepAlive",
                params: params,
                responseType: [String: Int].self
            )
            #if DEBUG
                logger.debug("Keep alive sent successfully")
            #endif
        } catch {
            #if DEBUG
                logger.error("Keep alive failed: \(error.localizedDescription)")
            #endif
        }
    }

    var hasActiveSession: Bool {
        return rpcBase.hasActiveSession && keepAliveTimer != nil
    }
}

private struct Logger {
    func debug(_ message: String) {
        #if DEBUG
            print("[RPCLogin Debug] \(message)")
        #endif
    }

    func error(_ message: String) {
        #if DEBUG
            print("[RPCLogin Error] \(message)")
        #endif
    }
}
