import CryptoKit
import Foundation
import os.log

class CameraAPIService: ObservableObject {
    @Published var cameras: [NVRCamera] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var baseURL: String = ""
    private var username: String = ""
    private var password: String = ""
    private let logger = Logger(subsystem: "com.minhlq.DahuaNVR", category: "CameraAPIService")

    init() {
        // Removed async Task that caused race condition
        // Credentials will be set explicitly via method calls
    }
    
    // MARK: - Authentication Test Method
    // Helper method for testing authentication without affecting global state
    
    func authenticate(with credentials: NVRCredentials) async throws {
        #if DEBUG
        logger.debug("authenticate(with:) - Testing authentication for \(credentials.serverURL)")
        #endif
        
        // Test authentication by making a simple authenticated request
        let endpoint = "/cgi-bin/LogicDeviceManager.cgi?action=getCameraAll"
        guard let url = URL(string: credentials.serverURL + endpoint) else {
            throw CameraAPIError.invalidURL
        }
        
        #if DEBUG
        logger.debug("authenticate(with:) - Testing CGI authentication with URL: \(url.absoluteString)")
        #endif
        
        // Use stateless authentication to avoid race conditions
        let authenticatedRequest = try await createAuthenticatedRequest(
            for: url,
            username: credentials.username,
            password: credentials.password
        )
        let (_, response) = try await URLSession.shared.data(for: authenticatedRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CameraAPIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            #if DEBUG
            logger.error("authenticate(with:) - CGI authentication failed with status: \(httpResponse.statusCode)")
            #endif
            throw CameraAPIError.requestFailed(statusCode: httpResponse.statusCode)
        }
        
        #if DEBUG
        logger.debug("authenticate(with:) - CGI authentication successful")
        #endif
    }
    
    // MARK: - NEW ARCHITECTURE: Explicit Credential Methods
    // These methods accept credentials as parameters, eliminating dependency on global state
    // This improves testability and prevents circular dependency issues during authentication
    
    func fetchCameras(with credentials: NVRCredentials) async -> [NVRCamera] {
        #if DEBUG
        logger.debug("fetchCameras(with:) - Using explicit credentials for \(credentials.serverURL)")
        logger.debug("fetchCameras(with:) - Credentials Debug:")
        logger.debug("   → serverURL: '\(credentials.serverURL)'")
        logger.debug("   → username: '\(credentials.username)'")
        #endif
        
        // Use provided credentials directly instead of relying on global state
        let savedBaseURL = self.baseURL
        let savedUsername = self.username  
        let savedPassword = self.password
        
        #if DEBUG
        logger.debug("fetchCameras(with:) - Before setting credentials:")
        logger.debug("   → current baseURL: '\(self.baseURL)'")
        #endif
        
        // Temporarily set credentials for this operation
        self.baseURL = credentials.serverURL
        self.username = credentials.username
        self.password = credentials.password
        
        #if DEBUG
        logger.debug("fetchCameras(with:) - After setting credentials:")
        logger.debug("   → new baseURL: '\(self.baseURL)'")
        logger.debug("   → new username: '\(self.username)'")
        #endif
        
        do {
            let cameras = try await getCameraAll()
            
            // Restore original credentials
            self.baseURL = savedBaseURL
            self.username = savedUsername
            self.password = savedPassword
            
            return cameras
        } catch {
            // Restore original credentials even on error
            self.baseURL = savedBaseURL
            self.username = savedUsername
            self.password = savedPassword
            
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            logDetailedError(error: error, context: "fetchCameras(with:)")
            return []
        }
    }
    
    func updateCameraIP(camera: NVRCamera, newIPAddress: String, with credentials: NVRCredentials) async throws {
        #if DEBUG
        logger.debug("updateCameraIP(with:) - Using explicit credentials for \(credentials.serverURL)")
        #endif
        
        // Use provided credentials directly instead of relying on global state
        let savedBaseURL = self.baseURL
        let savedUsername = self.username
        let savedPassword = self.password
        
        // Temporarily set credentials for this operation
        self.baseURL = credentials.serverURL
        self.username = credentials.username
        self.password = credentials.password
        
        do {
            try await updateCameraByGroup(camera: camera, newIPAddress: newIPAddress)
            
            // Restore original credentials
            self.baseURL = savedBaseURL
            self.username = savedUsername
            self.password = savedPassword
        } catch {
            // Restore original credentials even on error
            self.baseURL = savedBaseURL
            self.username = savedUsername
            self.password = savedPassword
            
            logDetailedError(error: error, context: "updateCameraIP(with:)")
            throw error
        }
    }

    @MainActor
    private func updateCredentials() {
        let authManager = AuthenticationManager.shared
        self.baseURL = authManager.currentCredentials?.serverURL ?? ""
        self.username = authManager.currentCredentials?.username ?? ""
        self.password = authManager.currentCredentials?.password ?? ""
    }

    // MARK: - DEPRECATED METHODS: Backward Compatibility
    // These methods are deprecated and will be removed in a future version
    // Use the explicit credential versions above for better testability and architecture
    
    @available(*, deprecated, renamed: "fetchCameras(with:)", 
               message: "Use fetchCameras(with credentials:) for explicit credential handling and better testability")
    func fetchCameras() async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }

        await updateCredentials()

        guard !baseURL.isEmpty && !username.isEmpty && !password.isEmpty else {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Authentication required. Please login first."
            }
            return
        }

        // Use the new explicit credential method for consistency
        let credentials = await MainActor.run {
            return AuthenticationManager.shared.currentCredentials
        }
        
        guard let credentials = credentials else {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "No credentials available in AuthenticationManager"
            }
            return
        }
        
        let fetchedCameras = await fetchCameras(with: credentials)
        await MainActor.run {
            self.cameras = fetchedCameras
            self.isLoading = false
        }
    }

    @available(*, deprecated, renamed: "updateCameraIP(camera:newIPAddress:with:)",
               message: "Use updateCameraIP(camera:newIPAddress:with credentials:) for explicit credential handling and better testability")
    func updateCameraIP(camera: NVRCamera, newIPAddress: String) async throws {
        await updateCredentials()

        guard !baseURL.isEmpty && !username.isEmpty && !password.isEmpty else {
            let error = CameraAPIError.invalidURL
            logDetailedError(error: error, context: "updateCameraIP - missing credentials")
            throw error
        }

        // Use the new explicit credential method for consistency
        let credentials = await MainActor.run {
            return AuthenticationManager.shared.currentCredentials
        }
        
        guard let credentials = credentials else {
            let error = CameraAPIError.invalidURL
            logDetailedError(error: error, context: "updateCameraIP - no credentials in AuthenticationManager")
            throw error
        }
        
        try await updateCameraIP(camera: camera, newIPAddress: newIPAddress, with: credentials)
    }

    private func getCameraAll() async throws -> [NVRCamera] {
        let endpoint = "/cgi-bin/LogicDeviceManager.cgi?action=getCameraAll"
        
        #if DEBUG
        logger.debug("getCameraAll - URL Construction Debug:")
        logger.debug("   → baseURL: '\(self.baseURL)'")
        logger.debug("   → endpoint: '\(endpoint)'")
        logger.debug("   → combined: '\(self.baseURL + endpoint)'")
        #endif
        
        guard let url = URL(string: baseURL + endpoint) else {
            let error = CameraAPIError.invalidURL
            #if DEBUG
            logger.error("getCameraAll - URL construction failed!")
            logger.error("   → baseURL: '\(self.baseURL)'")
            logger.error("   → endpoint: '\(endpoint)'") 
            logger.error("   → combined: '\(self.baseURL + endpoint)'")
            #endif
            logDetailedError(
                error: error, context: "getCameraAll - invalid URL: \(baseURL + endpoint)")
            throw error
        }
        
        #if DEBUG
        logger.debug("getCameraAll - Successfully constructed URL: \(url.absoluteString)")
        #endif

        let authenticatedRequest = try await createAuthenticatedRequest(for: url)
        let (data, response) = try await URLSession.shared.data(for: authenticatedRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            let error = CameraAPIError.invalidResponse
            logDetailedError(error: error, context: "getCameraAll - invalid response type")
            throw error
        }

        guard httpResponse.statusCode == 200 else {
            let error = CameraAPIError.requestFailed(statusCode: httpResponse.statusCode)
            logHTTPError(response: httpResponse, data: data, context: "getCameraAll")
            throw error
        }

        guard let responseString = String(data: data, encoding: .utf8) else {
            let error = CameraAPIError.decodingError
            logDetailedError(
                error: error, context: "getCameraAll - unable to decode response as UTF-8")
            throw error
        }


        return try parseDahuaResponse(responseString)
    }

    private func updateCameraByGroup(camera: NVRCamera, newIPAddress: String) async throws {
        let endpoint = "/cgi-bin/LogicDeviceManager.cgi?action=addCameraByGroup"
        guard let url = URL(string: baseURL + endpoint) else {
            let error = CameraAPIError.invalidURL
            logDetailedError(
                error: error, context: "updateCameraByGroup - invalid URL: \(baseURL + endpoint)")
            throw error
        }

        let requestBody = createUpdateCameraRequestBody(camera: camera, newIPAddress: newIPAddress)

        #if DEBUG
            if let jsonData = try? JSONSerialization.data(withJSONObject: requestBody),
                let jsonString = String(data: jsonData, encoding: .utf8)
            {
                logger.debug("updateCameraByGroup request body: \(jsonString)")
            }
        #endif

        let authenticatedRequest = try await createAuthenticatedPOSTRequest(
            for: url, body: requestBody)

        let (data, response) = try await URLSession.shared.data(for: authenticatedRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            let error = CameraAPIError.invalidResponse
            logDetailedError(error: error, context: "updateCameraByGroup - invalid response type")
            throw error
        }

        guard httpResponse.statusCode == 200 else {
            let error = CameraAPIError.requestFailed(statusCode: httpResponse.statusCode)
            logHTTPError(response: httpResponse, data: data, context: "updateCameraByGroup")
            throw error
        }

        guard let responseString = String(data: data, encoding: .utf8) else {
            let error = CameraAPIError.decodingError
            logDetailedError(
                error: error, context: "updateCameraByGroup - unable to decode response as UTF-8")
            throw error
        }

        #if DEBUG
            logger.debug("updateCameraByGroup response: \(responseString)")
        #endif

        if !responseString.contains("OK") {
            let error = CameraAPIError.requestFailed(statusCode: httpResponse.statusCode)
            logDetailedError(
                error: error,
                context: "updateCameraByGroup - response does not contain 'OK': \(responseString)")
            throw error
        }
    }

    private func createUpdateCameraRequestBody(camera: NVRCamera, newIPAddress: String) -> [String:
        Any]
    {
        return [
            "group": [
                [
                    "DeviceInfo": [
                        "Address": newIPAddress,
                        "HttpPort": camera.deviceInfo.httpPort,
                        "Port": camera.deviceInfo.port,
                        "UserName": camera.deviceInfo.userName,
                        "Password": camera.deviceInfo.password,
                        "ProtocolType": camera.deviceInfo.protocolType,
                        "Name": camera.deviceInfo.name,
                        "DeviceType": camera.deviceInfo.deviceType,
                        "SerialNo": camera.deviceInfo.serialNo,
                        "Mac": camera.deviceInfo.mac,
                        "SoftwareVersion": camera.deviceInfo.softwareVersion,
                    ],
                    "cameras": [
                        [
                            "uniqueChannel": camera.uniqueChannel
                        ]
                    ],
                ]
            ]
        ]
    }

    private func createAuthenticatedRequest(for url: URL) async throws -> URLRequest {
        // Use instance variables for backward compatibility
        return try await createAuthenticatedRequest(
            for: url,
            username: self.username,
            password: self.password
        )
    }
    
    private func createAuthenticatedRequest(
        for url: URL,
        username: String,
        password: String
    ) async throws -> URLRequest {
        #if DEBUG
        logger.debug("🔐 CGI Digest Authentication Flow Starting")
        logger.debug("   → URL: \(url.absoluteString)")
        logger.debug("   → Username: \(username)")
        #endif
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("DahuaNVR/1.0", forHTTPHeaderField: "User-Agent")

        #if DEBUG
        logger.debug("🚀 CGI Step 1: Making initial unauthenticated request")
        #endif

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            let error = CameraAPIError.invalidResponse
            logDetailedError(
                error: error, context: "createAuthenticatedRequest - invalid response type")
            throw error
        }

        #if DEBUG
        logger.debug("📥 CGI Step 1 Response: Status \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            logger.debug("   → Response Body: \(responseString)")
        }
        logger.debug("   → All Headers: \(httpResponse.allHeaderFields)")
        #endif

        if httpResponse.statusCode == 401 {
            #if DEBUG
            logger.debug("🔑 CGI Step 2: Processing 401 challenge")
            #endif
            
            guard let authHeader = httpResponse.value(forHTTPHeaderField: "WWW-Authenticate") else {
                let error = CameraAPIError.missingAuthHeader
                #if DEBUG
                logger.error("❌ CGI Error: No WWW-Authenticate header found")
                #endif
                logHTTPError(
                    response: httpResponse, data: data,
                    context: "createAuthenticatedRequest - missing auth header")
                throw error
            }

            #if DEBUG
            logger.debug("📋 CGI Digest Challenge Received:")
            logger.debug("   → WWW-Authenticate: \(authHeader)")
            #endif

            let digestParams = try parseDigestHeader(authHeader)
            
            #if DEBUG
            logger.debug("✅ CGI Step 3: Building authenticated request")
            logger.debug("   → Digest Params: \(digestParams)")
            #endif
            
            return try buildAuthenticatedRequest(
                url: url,
                digestParams: digestParams,
                username: username,
                password: password
            )
        } else {
            #if DEBUG
            logger.debug("✅ CGI No authentication required (status: \(httpResponse.statusCode))")
            #endif
        }

        return request
    }

    private func createAuthenticatedPOSTRequest(for url: URL, body: [String: Any]) async throws
        -> URLRequest
    {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("DahuaNVR/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        #if DEBUG
            logger.debug("Creating authenticated POST request for URL: \(url.absoluteString)")
        #endif

        let jsonData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            let error = CameraAPIError.invalidResponse
            logDetailedError(
                error: error, context: "createAuthenticatedPOSTRequest - invalid response type")
            throw error
        }

        if httpResponse.statusCode == 401 {
            guard let authHeader = httpResponse.value(forHTTPHeaderField: "WWW-Authenticate") else {
                let error = CameraAPIError.missingAuthHeader
                logHTTPError(
                    response: httpResponse, data: data,
                    context: "createAuthenticatedPOSTRequest - missing auth header")
                throw error
            }


            let digestParams = try parseDigestHeader(authHeader)
            return try buildAuthenticatedPOSTRequest(
                url: url, body: body, digestParams: digestParams)
        }

        return request
    }

    private func buildAuthenticatedPOSTRequest(
        url: URL, body: [String: Any], digestParams: [String: String]
    ) throws -> URLRequest {
        guard let realm = digestParams["realm"],
            let nonce = digestParams["nonce"]
        else {
            throw CameraAPIError.invalidDigestHeader
        }

        let qop = digestParams["qop"] ?? "auth"
        let opaque = digestParams["opaque"]
        let uri = url.path + (url.query != nil ? "?" + url.query! : "")
        let method = "POST"
        let nc = "00000001"
        let cnonce = generateCnonce()

        let ha1 = md5("\(username):\(realm):\(password)")
        let ha2 = md5("\(method):\(uri)")

        let response: String
        if qop == "auth" {
            response = md5("\(ha1):\(nonce):\(nc):\(cnonce):\(qop):\(ha2)")
        } else {
            response = md5("\(ha1):\(nonce):\(ha2)")
        }

        var authHeader =
            "Digest username=\"\(username)\", realm=\"\(realm)\", nonce=\"\(nonce)\", uri=\"\(uri)\", response=\"\(response)\""

        if qop == "auth" {
            authHeader += ", qop=\(qop), nc=\(nc), cnonce=\"\(cnonce)\""
        }

        if let opaque = opaque {
            authHeader += ", opaque=\"\(opaque)\""
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("DahuaNVR/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")

        let jsonData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = jsonData

        return request
    }

    private func parseDigestHeader(_ header: String) throws -> [String: String] {

        var params: [String: String] = [:]

        let headerValue = header.replacingOccurrences(of: "Digest ", with: "")
        let components = headerValue.components(separatedBy: ", ")

        for component in components {
            let parts = component.components(separatedBy: "=")
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "\"", with: "")
                params[key] = value
            }
        }


        guard params["realm"] != nil,
            params["nonce"] != nil
        else {
            let error = CameraAPIError.invalidDigestHeader
            logDetailedError(
                error: error,
                context: "parseDigestHeader - missing realm or nonce in header: \(header)")
            throw error
        }

        return params
    }

    private func buildAuthenticatedRequest(
        url: URL,
        digestParams: [String: String],
        username: String,
        password: String
    ) throws -> URLRequest {
        #if DEBUG
        logger.debug("🔧 CGI Building Digest Authentication Request")
        #endif
        
        guard let realm = digestParams["realm"],
            let nonce = digestParams["nonce"]
        else {
            throw CameraAPIError.invalidDigestHeader
        }

        let qop = digestParams["qop"] ?? "auth"
        let opaque = digestParams["opaque"]
        let uri = url.path + (url.query != nil ? "?" + url.query! : "")
        let method = "GET"
        let nc = "00000001"
        let cnonce = generateCnonce()

        #if DEBUG
        logger.debug("📋 CGI Digest Parameters:")
        logger.debug("   → username: \(username)")
        logger.debug("   → realm: \(realm)")
        logger.debug("   → nonce: \(nonce)")
        logger.debug("   → uri: \(uri)")
        logger.debug("   → method: \(method)")
        logger.debug("   → qop: \(qop)")
        logger.debug("   → nc: \(nc)")
        logger.debug("   → cnonce: \(cnonce)")
        if let opaque = opaque {
            logger.debug("   → opaque: \(opaque)")
        }
        #endif

        let ha1 = md5("\(username):\(realm):\(password)")
        let ha2 = md5("\(method):\(uri)")

        #if DEBUG
        logger.debug("🔐 CGI Digest Calculation:")
        logger.debug("   → HA1 input: \(username):\(realm):[password]")
        logger.debug("   → HA1 result: \(ha1)")
        logger.debug("   → HA2 input: \(method):\(uri)")
        logger.debug("   → HA2 result: \(ha2)")
        #endif

        let response: String
        if qop == "auth" {
            let responseInput = "\(ha1):\(nonce):\(nc):\(cnonce):\(qop):\(ha2)"
            response = md5(responseInput)
            #if DEBUG
            logger.debug("   → Response input (with qop): \(responseInput)")
            logger.debug("   → Response result: \(response)")
            #endif
        } else {
            let responseInput = "\(ha1):\(nonce):\(ha2)"
            response = md5(responseInput)
            #if DEBUG
            logger.debug("   → Response input (no qop): \(responseInput)")
            logger.debug("   → Response result: \(response)")
            #endif
        }

        var authHeader =
            "Digest username=\"\(username)\", realm=\"\(realm)\", nonce=\"\(nonce)\", uri=\"\(uri)\", response=\"\(response)\""

        if qop == "auth" {
            authHeader += ", qop=\(qop), nc=\(nc), cnonce=\"\(cnonce)\""
        }

        if let opaque = opaque {
            authHeader += ", opaque=\"\(opaque)\""
        }

        #if DEBUG
        logger.debug("📤 CGI Final Authorization Header:")
        logger.debug("   → \(authHeader)")
        #endif

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("DahuaNVR/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")

        #if DEBUG
        logger.debug("✅ CGI Authenticated request built successfully")
        #endif

        return request
    }

    private func generateCnonce() -> String {
        let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        return String((0..<8).map { _ in chars.randomElement()! })
    }

    private func md5(_ string: String) -> String {
        let digest = Insecure.MD5.hash(data: string.data(using: .utf8)!)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }

    private func parseDahuaResponse(_ responseString: String) throws -> [NVRCamera] {

        var cameras: [NVRCamera] = []
        var currentCameraData: [String: String] = [:]
        var currentCameraIndex: Int?

        let lines = responseString.components(separatedBy: .newlines)


        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }

            let parts = trimmedLine.components(separatedBy: "=")
            guard parts.count >= 2 else { continue }

            let key = parts[0]
            let value = parts[1..<parts.count].joined(separator: "=")

            if key.range(of: #"camera\[(\d+)\]\.(.+)"#, options: .regularExpression) != nil {
                let indexStr = String(
                    key[
                        key.index(
                            after: key.firstIndex(of: "[")!)...key.index(
                                before: key.firstIndex(of: "]")!)])
                let propertyPath = String(key[key.index(after: key.firstIndex(of: ".")!)...])

                if let index = Int(indexStr) {
                    if currentCameraIndex != index {
                        if currentCameraIndex != nil, !currentCameraData.isEmpty {
                            if let camera = createNVRCamera(from: currentCameraData) {
                                cameras.append(camera)
                            } else {
                                #if DEBUG
                                    logger.warning(
                                        "Failed to create camera from data for index \(currentCameraIndex!): \(currentCameraData)"
                                    )
                                #endif
                            }
                        }
                        currentCameraIndex = index
                        currentCameraData = [:]
                    }
                    currentCameraData[propertyPath] = value
                }
            }
        }

        if currentCameraIndex != nil, !currentCameraData.isEmpty {
            if let camera = createNVRCamera(from: currentCameraData) {
                cameras.append(camera)
                #if DEBUG
                    logger.debug(
                        "Successfully parsed final camera \(currentCameraIndex!): \(camera.name)")
                #endif
            } else {
                #if DEBUG
                    logger.warning(
                        "Failed to create final camera from data for index \(currentCameraIndex!): \(currentCameraData)"
                    )
                #endif
            }
        }

        #if DEBUG
            logger.debug("Parsing completed. Found \(cameras.count) cameras")
        #endif

        return cameras
    }

    private func createNVRCamera(from data: [String: String]) -> NVRCamera? {

        guard let enable = data["Enable"].flatMap({ Bool($0) }),
            let deviceID = data["DeviceID"],
            let uniqueChannel = data["UniqueChannel"].flatMap({ Int($0) }),
            let address = data["DeviceInfo.Address"],
            let httpPort = data["DeviceInfo.HttpPort"].flatMap({ Int($0) })
        else {
            #if DEBUG
                logger.warning(
                    "Failed to create NVR camera - missing required fields. Data: \(data)")
            #endif
            return nil
        }

        let controlID = data["ControlID"] ?? ""
        let name = data["Name"] ?? "Unknown Camera"
        let type = data["Type"] ?? "Unknown"
        let videoStream = data["VideoStream"] ?? "Main"

        let deviceInfo = DeviceInfo(
            enable: data["DeviceInfo.Enable"].flatMap({ Bool($0) }) ?? true,
            encryptStream: data["DeviceInfo.EncryptStream"].flatMap({ Int($0) }) ?? 0,
            address: address,
            port: data["DeviceInfo.Port"].flatMap({ Int($0) }) ?? 37777,
            usePreSecret: data["DeviceInfo.usePreSecret"].flatMap({ Int($0) }) ?? 0,
            userName: data["DeviceInfo.UserName"] ?? "",
            password: data["DeviceInfo.Password"] ?? "",
            protocolType: data["DeviceInfo.ProtocolType"] ?? "Unknown",
            videoInputChannels: data["DeviceInfo.VideoInputChannels"].flatMap({ Int($0) }) ?? 0,
            audioInputChannels: data["DeviceInfo.AudioInputChannels"].flatMap({ Int($0) }) ?? 0,
            deviceClass: data["DeviceInfo.DeviceClass"] ?? "",
            deviceType: data["DeviceInfo.DeviceType"] ?? "Unknown",
            httpPort: httpPort,
            httpsPort: data["DeviceInfo.HttpsPort"].flatMap({ Int($0) }) ?? 443,
            rtspPort: data["DeviceInfo.RtspPort"].flatMap({ Int($0) }) ?? 554,
            name: data["DeviceInfo.Name"] ?? "Unknown Device",
            machineAddress: data["DeviceInfo.MachineAddress"] ?? "",
            serialNo: data["DeviceInfo.SerialNo"] ?? "",
            vendorAbbr: data["DeviceInfo.VendorAbbr"] ?? "",
            hardID: data["DeviceInfo.HardID"] ?? "",
            softwareVersion: data["DeviceInfo.SoftwareVersion"] ?? "",
            activationTime: data["DeviceInfo.ActivationTime"] ?? "",
            nodeType: data["DeviceInfo.NodeType"] ?? "",
            mac: data["DeviceInfo.Mac"] ?? "",
            oemVendor: data["DeviceInfo.OEMVendor"] ?? ""
        )

        return NVRCamera(
            controlID: controlID,
            name: name,
            enable: enable,
            deviceID: deviceID,
            type: type,
            videoStream: videoStream,
            uniqueChannel: uniqueChannel,
            deviceInfo: deviceInfo
        )
    }

    private func logDetailedError(error: Error, context: String) {
        #if DEBUG
            logger.error("[\(context)] Error: \(error.localizedDescription)")

            if let cameraError = error as? CameraAPIError {
                logger.error(
                    "[\(context)] Camera API Error Type: \(String(describing: cameraError))")
            }

            if let urlError = error as? URLError {
                logger.error("[\(context)] URL Error Code: \(urlError.code.rawValue)")
                logger.error("[\(context)] URL Error Description: \(urlError.localizedDescription)")
                if let url = urlError.failingURL {
                    logger.error("[\(context)] Failing URL: \(url.absoluteString)")
                }
            }

            logger.error("[\(context)] Full Error: \(String(describing: error))")
        #endif
    }

    private func logHTTPError(response: HTTPURLResponse, data: Data, context: String) {
        #if DEBUG
            logger.error("[\(context)] HTTP Error - Status Code: \(response.statusCode)")
            logger.error(
                "[\(context)] HTTP Error - URL: \(response.url?.absoluteString ?? "Unknown")")
            logger.error("[\(context)] HTTP Error - Headers: \(response.allHeaderFields)")

            if let responseString = String(data: data, encoding: .utf8) {
                logger.error("[\(context)] HTTP Error - Response Body: \(responseString)")
            } else {
                logger.error(
                    "[\(context)] HTTP Error - Response Body: Unable to decode as UTF-8, data length: \(data.count)"
                )
            }
        #endif
    }
}

struct CameraResponse: Codable {
    let camera: [NVRCamera]
}

struct NVRCamera: Codable, Identifiable {
    let id = UUID()
    let controlID: String
    let name: String
    let enable: Bool
    let deviceID: String
    let type: String
    let videoStream: String
    let uniqueChannel: Int
    let deviceInfo: DeviceInfo

    enum CodingKeys: String, CodingKey {
        case controlID = "ControlID"
        case name = "Name"
        case enable = "Enable"
        case deviceID = "DeviceID"
        case type = "Type"
        case videoStream = "VideoStream"
        case uniqueChannel = "UniqueChannel"
        case deviceInfo = "DeviceInfo"
    }
}

struct DeviceInfo: Codable {
    let enable: Bool
    let encryptStream: Int
    let address: String
    let port: Int
    let usePreSecret: Int
    let userName: String
    let password: String
    let protocolType: String
    let videoInputChannels: Int
    let audioInputChannels: Int
    let deviceClass: String
    let deviceType: String
    let httpPort: Int
    let httpsPort: Int
    let rtspPort: Int
    let name: String
    let machineAddress: String
    let serialNo: String
    let vendorAbbr: String
    let hardID: String
    let softwareVersion: String
    let activationTime: String
    let nodeType: String
    let mac: String
    let oemVendor: String

    enum CodingKeys: String, CodingKey {
        case enable = "Enable"
        case encryptStream = "EncryptStream"
        case address = "Address"
        case port = "Port"
        case usePreSecret = "usePreSecret"
        case userName = "UserName"
        case password = "Password"
        case protocolType = "ProtocolType"
        case videoInputChannels = "VideoInputChannels"
        case audioInputChannels = "AudioInputChannels"
        case deviceClass = "DeviceClass"
        case deviceType = "DeviceType"
        case httpPort = "HttpPort"
        case httpsPort = "HttpsPort"
        case rtspPort = "RtspPort"
        case name = "Name"
        case machineAddress = "MachineAddress"
        case serialNo = "SerialNo"
        case vendorAbbr = "VendorAbbr"
        case hardID = "HardID"
        case softwareVersion = "SoftwareVersion"
        case activationTime = "ActivationTime"
        case nodeType = "NodeType"
        case mac = "Mac"
        case oemVendor = "OEMVendor"
    }
}

enum CameraAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case missingAuthHeader
    case invalidDigestHeader
    case requestFailed(statusCode: Int)
    case decodingError

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
        case .requestFailed(let statusCode):
            return "Request failed with status code: \(statusCode)"
        case .decodingError:
            return "Failed to decode response data"
        }
    }
}
