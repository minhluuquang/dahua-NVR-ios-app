import Foundation

struct RPCCameraResponse: Codable {
    let camera: [RPCCameraInfo]
    
    private enum CodingKeys: String, CodingKey {
        case camera
    }
}

struct RPCCameraInfo: Codable {
    let channel: Int?
    let deviceID: String?
    let deviceInfo: RPCDeviceInfo?
    let enable: Bool?
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
    let audioInputChannels: Int
    let deviceClass: String
    let deviceType: String
    let enable: Bool
    let encryption: Int
    let httpPort: Int
    let httpsPort: Int
    let mac: String
    let name: String
    let poe: Bool
    let poePort: Int
    let port: Int
    let protocolType: String
    let rtspPort: Int
    let serialNo: String
    let userName: String
    let videoInputChannels: Int
    let videoInputs: [RPCVideoInput]
    
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
    let bufDelay: Int
    let enable: Bool
    let extraStreamUrl: String
    let mainStreamUrl: String
    let name: String
    let serviceType: String
    
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
    func toNVRCamera() -> NVRCamera? {
        // Skip cameras without device info (like "Compose" type cameras)
        guard let deviceInfo = self.deviceInfo,
              let deviceID = self.deviceID,
              let enable = self.enable else {
            return nil
        }
        
        let nvrDeviceInfo = DeviceInfo(
            enable: deviceInfo.enable,
            encryptStream: deviceInfo.encryption,
            address: deviceInfo.address,
            port: deviceInfo.port,
            usePreSecret: 0,
            userName: deviceInfo.userName,
            password: "",
            protocolType: deviceInfo.protocolType,
            videoInputChannels: deviceInfo.videoInputChannels,
            audioInputChannels: deviceInfo.audioInputChannels,
            deviceClass: deviceInfo.deviceClass,
            deviceType: deviceInfo.deviceType,
            httpPort: deviceInfo.httpPort,
            httpsPort: deviceInfo.httpsPort,
            rtspPort: deviceInfo.rtspPort,
            name: deviceInfo.name,
            machineAddress: "",
            serialNo: deviceInfo.serialNo,
            vendorAbbr: "",
            hardID: "",
            softwareVersion: "",
            activationTime: "",
            nodeType: "",
            mac: deviceInfo.mac,
            oemVendor: ""
        )
        
        var camera = NVRCamera(
            controlID: "Channel\(self.uniqueChannel)",
            name: deviceInfo.name.isEmpty ? "Camera \(self.uniqueChannel + 1)" : deviceInfo.name,
            enable: enable,
            deviceID: deviceID,
            type: self.type,
            videoStream: self.videoStream ?? "Main",
            uniqueChannel: self.uniqueChannel,
            deviceInfo: nvrDeviceInfo,
            showStatus: self.showStatus
        )
        return camera
    }
}
