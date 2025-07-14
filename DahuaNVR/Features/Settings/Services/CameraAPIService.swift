import Foundation
import CryptoKit

class CameraAPIService: ObservableObject {
    @Published var cameras: [NVRCamera] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var baseURL: String = ""
    private var username: String = ""
    private var password: String = ""
    
    init() {
        Task {
            await updateCredentials()
        }
    }
    
    @MainActor
    private func updateCredentials() {
        let authManager = AuthenticationManager.shared
        self.baseURL = authManager.currentCredentials?.serverURL ?? ""
        self.username = authManager.currentCredentials?.username ?? ""
        self.password = authManager.currentCredentials?.password ?? ""
    }
    
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
        
        do {
            let fetchedCameras = try await getCameraAll()
            await MainActor.run {
                self.cameras = fetchedCameras
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func getCameraAll() async throws -> [NVRCamera] {
        let endpoint = "/cgi-bin/LogicDeviceManager.cgi?action=getCameraAll"
        guard let url = URL(string: baseURL + endpoint) else {
            throw CameraAPIError.invalidURL
        }
        
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
        
        return try parseDahuaResponse(responseString)
    }
    
    private func createAuthenticatedRequest(for url: URL) async throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("DahuaNVR/1.0", forHTTPHeaderField: "User-Agent")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CameraAPIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            guard let authHeader = httpResponse.value(forHTTPHeaderField: "WWW-Authenticate") else {
                throw CameraAPIError.missingAuthHeader
            }
            
            let digestParams = try parseDigestHeader(authHeader)
            return try buildAuthenticatedRequest(url: url, digestParams: digestParams)
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
        
        guard params["realm"] != nil,
              params["nonce"] != nil else {
            throw CameraAPIError.invalidDigestHeader
        }
        
        return params
    }
    
    private func buildAuthenticatedRequest(url: URL, digestParams: [String: String]) throws -> URLRequest {
        guard let realm = digestParams["realm"],
              let nonce = digestParams["nonce"] else {
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
                let indexStr = String(key[key.index(after: key.firstIndex(of: "[")!)...key.index(before: key.firstIndex(of: "]")!)])
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
              let httpPort = data["DeviceInfo.HttpPort"].flatMap({ Int($0) }) else {
            return nil
        }
        
        let name = data["DeviceInfo.Name"] ?? "Unknown Camera"
        let protocolType = data["DeviceInfo.ProtocolType"] ?? "Unknown"
        let deviceType = data["DeviceInfo.DeviceType"] ?? "Unknown"
        let serialNo = data["DeviceInfo.SerialNo"] ?? ""
        let mac = data["DeviceInfo.Mac"] ?? ""
        let softwareVersion = data["DeviceInfo.SoftwareVersion"] ?? ""
        
        let deviceInfo = DeviceInfo(
            address: address,
            httpPort: httpPort,
            protocolType: protocolType,
            deviceType: deviceType,
            serialNo: serialNo,
            mac: mac,
            softwareVersion: softwareVersion
        )
        
        return NVRCamera(
            name: name,
            enable: enable,
            deviceID: deviceID,
            uniqueChannel: uniqueChannel,
            deviceInfo: deviceInfo
        )
    }
}

struct CameraResponse: Codable {
    let camera: [NVRCamera]
}

struct NVRCamera: Codable, Identifiable {
    let id = UUID()
    let name: String
    let enable: Bool
    let deviceID: String
    let uniqueChannel: Int
    let deviceInfo: DeviceInfo
    
    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case enable = "Enable"
        case deviceID = "DeviceID"
        case uniqueChannel = "UniqueChannel"
        case deviceInfo = "DeviceInfo"
    }
}

struct DeviceInfo: Codable {
    let address: String
    let httpPort: Int
    let protocolType: String
    let deviceType: String
    let serialNo: String
    let mac: String
    let softwareVersion: String
    
    enum CodingKeys: String, CodingKey {
        case address = "Address"
        case httpPort = "HttpPort"
        case protocolType = "ProtocolType"
        case deviceType = "DeviceType"
        case serialNo = "SerialNo"
        case mac = "Mac"
        case softwareVersion = "SoftwareVersion"
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