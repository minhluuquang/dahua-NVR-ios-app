import CryptoKit
import Foundation
import os.log

// Network Service Actor for task deduplication and cancellation resilience
actor CameraNetworkService {
    private var activeFetchTask: Task<[NVRCamera], Error>?
    private let logger = Logger(subsystem: "com.minhlq.DahuaNVR", category: "CameraNetworkService")
    
    func fetchCameras(with credentials: NVRCredentials) async throws -> [NVRCamera] {
        // If a task is already running, await its result to avoid duplicate requests
        if let activeFetchTask = activeFetchTask {
            #if DEBUG
            logger.debug("🔄 Joining existing camera fetch task")
            #endif
            return try await activeFetchTask.value
        }
        
        // Create new protected task that won't be cancelled by UI lifecycle
        let task = Task {
            defer { 
                Task { self.clearActiveTask() }
            }
            
            #if DEBUG
            logger.debug("🚀 Starting new protected camera fetch task")
            #endif
            
            return try await self.performCameraFetch(with: credentials)
        }
        
        self.activeFetchTask = task
        return try await task.value
    }
    
    private func clearActiveTask() {
        activeFetchTask = nil
    }
    
    private func performCameraFetch(with credentials: NVRCredentials) async throws -> [NVRCamera] {
        let service = CameraAPIServiceHelper(credentials: credentials)
        return try await service.getCameraAll()
    }
}

// Helper class for actual network operations
private class CameraAPIServiceHelper {
    private let baseURL: String
    private let username: String
    private let password: String
    private let logger = Logger(subsystem: "com.minhlq.DahuaNVR", category: "CameraAPIServiceHelper")
    
    init(credentials: NVRCredentials) {
        self.baseURL = credentials.serverURL
        self.username = credentials.username
        self.password = credentials.password
    }
    
    // Move all the existing network logic here...
    func getCameraAll() async throws -> [NVRCamera] {
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
            #endif
            throw error
        }
        
        #if DEBUG
        logger.debug("getCameraAll - Successfully constructed URL: \(url.absoluteString)")
        #endif

        let authenticatedRequest = try await createAuthenticatedRequest(for: url)
        let (data, response) = try await URLSession.shared.data(for: authenticatedRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CameraAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw CameraAPIError.requestFailed(statusCode: httpResponse.statusCode)
        }

        guard let responseString = String(data: data, encoding: .utf8) else {
            throw CameraAPIError.decodingError
        }

        #if DEBUG
        logger.debug("🔍 getCameraAll - Raw server response:")
        logger.debug("Response length: \(responseString.count) characters")
        #endif

        return try parseDahuaResponse(responseString)
    }
    
    private func createAuthenticatedRequest(for url: URL) async throws -> URLRequest {
        #if DEBUG
        logger.debug("🔐 CGI Digest Authentication Flow Starting")
        logger.debug("   → URL: \(url.absoluteString)")
        logger.debug("   → Username: \(self.username)")
        #endif
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("DahuaNVR/1.0", forHTTPHeaderField: "User-Agent")

        #if DEBUG
        logger.debug("🚀 CGI Step 1: Making initial unauthenticated request")
        #endif

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CameraAPIError.invalidResponse
        }

        #if DEBUG
        logger.debug("📥 CGI Step 1 Response: Status \(httpResponse.statusCode)")
        #endif

        if httpResponse.statusCode == 401 {
            #if DEBUG
            logger.debug("🔑 CGI Step 2: Processing 401 challenge")
            #endif
            
            guard let authHeader = httpResponse.value(forHTTPHeaderField: "WWW-Authenticate") else {
                #if DEBUG
                logger.error("❌ CGI Error: No WWW-Authenticate header found")
                #endif
                throw CameraAPIError.missingAuthHeader
            }

            #if DEBUG
            logger.debug("📋 CGI Digest Challenge Received:")
            logger.debug("   → WWW-Authenticate: \(authHeader)")
            #endif

            let digestParams = try parseDigestHeader(authHeader)
            
            #if DEBUG
            logger.debug("✅ CGI Step 3: Building authenticated request")
            #endif
            
            return try buildAuthenticatedRequest(
                url: url,
                digestParams: digestParams
            )
        }

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

        guard params["realm"] != nil, params["nonce"] != nil else {
            throw CameraAPIError.invalidDigestHeader
        }

        return params
    }
    
    private func buildAuthenticatedRequest(url: URL, digestParams: [String: String]) throws -> URLRequest {
        guard let realm = digestParams["realm"], let nonce = digestParams["nonce"] else {
            throw CameraAPIError.invalidDigestHeader
        }

        let qop = digestParams["qop"] ?? "auth"
        let opaque = digestParams["opaque"]
        let uri = url.path + (url.query != nil ? "?" + url.query! : "")
        let method = "GET"
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
                        key.index(after: key.firstIndex(of: "[")!)...key.index(before: key.firstIndex(of: "]")!)])
                let propertyPath = String(key[key.index(after: key.firstIndex(of: ".")!)...])

                if let index = Int(indexStr) {
                    if currentCameraIndex != index {
                        if currentCameraIndex != nil, !currentCameraData.isEmpty {
                            if let camera = createNVRCamera(from: currentCameraData) {
                                cameras.append(camera)
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
            }
        }

        return cameras
    }
    
    private func createNVRCamera(from data: [String: String]) -> NVRCamera? {
        guard let enable = data["Enable"].flatMap({ Bool($0) }),
            let deviceID = data["DeviceID"],
            let uniqueChannel = data["UniqueChannel"].flatMap({ Int($0) }),
            let address = data["DeviceInfo.Address"],
            let httpPort = data["DeviceInfo.HttpPort"].flatMap({ Int($0) })
        else {
            return nil
        }

        let controlID = data["ControlID"] ?? ""
        let name = data["DeviceInfo.Name"] ?? "Unknown Camera"
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
}

class CameraAPIService: ObservableObject {
    @Published var cameras: [NVRCamera] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let networkService = CameraNetworkService()
    private let logger = Logger(subsystem: "com.minhlq.DahuaNVR", category: "CameraAPIService")

    init() {
        // Clean initialization - no async tasks
    }
    
    // MARK: - Authentication Test Method
    // Helper method for testing authentication without affecting global state
    
    func authenticate(with credentials: NVRCredentials) async throws {
        #if DEBUG
        logger.debug("authenticate(with:) - Testing authentication using actor network service for \(credentials.serverURL)")
        #endif
        
        // Use the actor network service to test authentication
        _ = try await networkService.fetchCameras(with: credentials)
        
        #if DEBUG
        logger.debug("authenticate(with:) - CGI authentication successful")
        #endif
    }
    
    // MARK: - NEW ARCHITECTURE: Explicit Credential Methods
    // These methods accept credentials as parameters, eliminating dependency on global state
    // This improves testability and prevents circular dependency issues during authentication
    
    func fetchCameras(with credentials: NVRCredentials) async -> [NVRCamera] {
        #if DEBUG
        logger.debug("fetchCameras(with:) - Using actor-based network service for \(credentials.serverURL)")
        #endif
        
        do {
            return try await networkService.fetchCameras(with: credentials)
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            logDetailedError(error: error, context: "fetchCameras(with:)")
            return []
        }
    }
    
    func updateCameraIP(camera: NVRCamera, newIPAddress: String, with credentials: NVRCredentials) async throws {
        #if DEBUG
        logger.debug("updateCameraIP(with:) - Using actor-based network service for \(credentials.serverURL)")
        #endif
        
        // For now, we'll throw an error since camera IP updates aren't implemented in the actor yet
        // This can be implemented later by extending the CameraNetworkService actor
        throw CameraAPIError.requestFailed(statusCode: 501) // Not Implemented
    }

    // MARK: - DEPRECATED METHODS: Backward Compatibility
    // These methods are deprecated and will be removed in a future version
    // Use the explicit credential versions above for better testability and architecture
    
    @available(*, deprecated, renamed: "fetchCameras(with:)", 
               message: "Use fetchCameras(with credentials:) for explicit credential handling and better testability")
    func fetchCameras() async {
        guard let credentials = await AuthenticationManager.shared.currentCredentials else {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Authentication required. Please login first."
            }
            return
        }
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
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
        guard let credentials = await AuthenticationManager.shared.currentCredentials else {
            let error = CameraAPIError.invalidURL
            logDetailedError(error: error, context: "updateCameraIP - no credentials in AuthenticationManager")
            throw error
        }
        
        try await updateCameraIP(camera: camera, newIPAddress: newIPAddress, with: credentials)
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
