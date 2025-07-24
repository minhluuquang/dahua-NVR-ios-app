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

// MARK: - Conversion Extensions for RPC Operations

extension NVRCamera {
    func toCameraPayload(withModifiedAddress newAddress: String? = nil) -> [String: Any] {
        let addressToUse = newAddress ?? self.deviceInfo.address
        
        return [
            "Channel": self.uniqueChannel,
            "DeviceID": self.deviceID,
            "DeviceInfo": [
                "Address": addressToUse,
                "AudioInputChannels": self.deviceInfo.audioInputChannels,
                "DeviceClass": self.deviceInfo.deviceClass,
                "DeviceType": self.deviceInfo.deviceType,
                "Enable": self.deviceInfo.enable,
                "Encryption": self.deviceInfo.encryptStream,
                "HttpPort": self.deviceInfo.httpPort,
                "HttpsPort": self.deviceInfo.httpsPort,
                "Mac": self.deviceInfo.mac,
                "Name": self.deviceInfo.name,
                "PoE": false,
                "PoEPort": 0,
                "Port": self.deviceInfo.port,
                "ProtocolType": self.deviceInfo.protocolType,
                "RtspPort": self.deviceInfo.rtspPort,
                "SerialNo": self.deviceInfo.serialNo,
                "UserName": self.deviceInfo.userName,
                "VideoInputChannels": self.deviceInfo.videoInputChannels,
                "VideoInputs": [
                    [
                        "BufDelay": 160,
                        "Enable": true,
                        "ExtraStreamUrl": "",
                        "MainStreamUrl": "",
                        "Name": "",
                        "ServiceType": "AUTO"
                    ]
                ],
                "Password": "",
                "LoginType": 0,
                "b_isMultiVideoSensor": false
            ],
            "Enable": self.enable,
            "Type": self.type,
            "UniqueChannel": self.uniqueChannel,
            "VideoStandard": "PAL",
            "VideoStream": self.videoStream,
            "showStatus": self.showStatus ?? "Unknown"
        ]
    }
}