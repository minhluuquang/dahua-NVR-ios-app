import Foundation

struct RPCCameraResponse: Codable {
    let camera: [RPCCameraInfo]
    
    private enum CodingKeys: String, CodingKey {
        case camera
    }
}

struct RPCCameraInfo: Codable {
    let channel: Int
    let deviceID: String
    let deviceInfo: RPCDeviceInfo
    let enable: Bool
    let type: String
    let uniqueChannel: Int
    let videoStandard: String?
    let videoStream: String?
    let showStatus: String?
    
    private enum CodingKeys: String, CodingKey {
        case channel = "Channel"
        case deviceID = "DeviceID"
        case deviceInfo = "DeviceInfo"
        case enable = "Enable"
        case type = "Type"
        case uniqueChannel = "UniqueChannel"
        case videoStandard = "VideoStandard"
        case videoStream = "VideoStream"
        case showStatus = "showStatus"
    }
}

struct RPCDeviceInfo: Codable {
    let address: String
    let audioInputChannels: Int?
    let deviceClass: String?
    let deviceType: String?
    let enable: Bool
    let encryption: Int?
    let httpPort: Int
    let httpsPort: Int
    let mac: String?
    let name: String?
    let poe: Bool?
    let poePort: Int?
    let port: Int
    let protocolType: String?
    let rtspPort: Int?
    let serialNo: String?
    let userName: String?
    let videoInputChannels: Int?
    let videoInputs: [RPCVideoInput]?
    
    private enum CodingKeys: String, CodingKey {
        case address = "Address"
        case audioInputChannels = "AudioInputChannels"
        case deviceClass = "DeviceClass"
        case deviceType = "DeviceType"
        case enable = "Enable"
        case encryption = "Encryption"
        case httpPort = "HttpPort"
        case httpsPort = "HttpsPort"
        case mac = "Mac"
        case name = "Name"
        case poe = "PoE"
        case poePort = "PoEPort"
        case port = "Port"
        case protocolType = "ProtocolType"
        case rtspPort = "RtspPort"
        case serialNo = "SerialNo"
        case userName = "UserName"
        case videoInputChannels = "VideoInputChannels"
        case videoInputs = "VideoInputs"
    }
}

struct RPCVideoInput: Codable {
    let bufDelay: Int?
    let enable: Bool
    let extraStreamUrl: String?
    let mainStreamUrl: String?
    let name: String?
    let serviceType: String?
    
    private enum CodingKeys: String, CodingKey {
        case bufDelay = "BufDelay"
        case enable = "Enable"
        case extraStreamUrl = "ExtraStreamUrl"
        case mainStreamUrl = "MainStreamUrl"
        case name = "Name"
        case serviceType = "ServiceType"
    }
}

extension RPCCameraInfo {
    func toNVRCamera() -> NVRCamera {
        let deviceInfo = DeviceInfo(
            enable: self.deviceInfo.enable,
            encryptStream: self.deviceInfo.encryption ?? 0,
            address: self.deviceInfo.address,
            port: self.deviceInfo.port,
            usePreSecret: 0,
            userName: self.deviceInfo.userName ?? "",
            password: "",
            protocolType: self.deviceInfo.protocolType ?? "Unknown",
            videoInputChannels: self.deviceInfo.videoInputChannels ?? 0,
            audioInputChannels: self.deviceInfo.audioInputChannels ?? 0,
            deviceClass: self.deviceInfo.deviceClass ?? "",
            deviceType: self.deviceInfo.deviceType ?? "Unknown",
            httpPort: self.deviceInfo.httpPort,
            httpsPort: self.deviceInfo.httpsPort,
            rtspPort: self.deviceInfo.rtspPort ?? 554,
            name: self.deviceInfo.name ?? "Unknown Device",
            machineAddress: "",
            serialNo: self.deviceInfo.serialNo ?? "",
            vendorAbbr: "",
            hardID: "",
            softwareVersion: "",
            activationTime: "",
            nodeType: "",
            mac: self.deviceInfo.mac ?? "",
            oemVendor: ""
        )
        
        return NVRCamera(
            controlID: "Channel\(self.uniqueChannel)",
            name: self.deviceInfo.name ?? "Camera \(self.uniqueChannel + 1)",
            enable: self.enable,
            deviceID: self.deviceID,
            type: self.type,
            videoStream: self.videoStream ?? "Main",
            uniqueChannel: self.uniqueChannel,
            deviceInfo: deviceInfo
        )
    }
}