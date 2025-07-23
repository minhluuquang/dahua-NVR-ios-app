import Foundation

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
    var showStatus: String?

    enum CodingKeys: String, CodingKey {
        case controlID = "ControlID"
        case name = "Name"
        case enable = "Enable"
        case deviceID = "DeviceID"
        case type = "Type"
        case videoStream = "VideoStream"
        case uniqueChannel = "UniqueChannel"
        case deviceInfo = "DeviceInfo"
        case showStatus = "showStatus"
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