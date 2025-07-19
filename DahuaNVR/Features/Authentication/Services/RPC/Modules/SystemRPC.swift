import Foundation

struct SystemInfo: Codable {
    let deviceClass: String?
    let deviceType: String?
    let hardwareVersion: String?
    let softwareVersion: String?
    let buildDate: String?
    let serialNumber: String?
    let processor: String?
    let deviceModel: String?
    
    private enum CodingKeys: String, CodingKey {
        case deviceClass = "DeviceClass"
        case deviceType = "DeviceType"
        case hardwareVersion = "HardwareVersion"
        case softwareVersion = "SoftwareVersion"
        case buildDate = "BuildDate"
        case serialNumber = "SerialNo"
        case processor = "Processor"
        case deviceModel = "DeviceModel"
    }
}

struct SystemUsage: Codable {
    let cpuUsage: Double?
    let memoryUsage: Double?
    let cpuTemperature: Double?
    let fanSpeed: Int?
    
    private enum CodingKeys: String, CodingKey {
        case cpuUsage = "CpuUsage"
        case memoryUsage = "MemoryUsage"
        case cpuTemperature = "CpuTemperature"
        case fanSpeed = "FanSpeed"
    }
}

struct SystemTime: Codable {
    let currentTime: String?
    let timeZone: String?
    let dstEnable: Bool?
    
    private enum CodingKeys: String, CodingKey {
        case currentTime = "CurrentTime"
        case timeZone = "TimeZone"
        case dstEnable = "DstEnable"
    }
}

struct SystemCapabilities: Codable {
    let maxChannels: Int?
    let maxRemoteChannels: Int?
    let maxPlayback: Int?
    let maxLiveView: Int?
    let supportPTZ: Bool?
    let supportAudio: Bool?
    let supportAlarm: Bool?
    
    private enum CodingKeys: String, CodingKey {
        case maxChannels = "MaxChannels"
        case maxRemoteChannels = "MaxRemoteChannels"
        case maxPlayback = "MaxPlayback"
        case maxLiveView = "MaxLiveView"
        case supportPTZ = "SupportPTZ"
        case supportAudio = "SupportAudio"
        case supportAlarm = "SupportAlarm"
    }
}

class SystemRPC: RPCModule {
    let rpcBase: RPCBase
    private let logger = Logger()
    
    required init(rpcBase: RPCBase) {
        self.rpcBase = rpcBase
    }
    
    func getSystemInfo() async throws -> SystemInfo {
        #if DEBUG
        logger.debug("Getting system information")
        #endif
        
        let response: RPCResponse<SystemInfo> = try await rpcBase.send(
            method: "system.getSystemInfo",
            responseType: SystemInfo.self
        )
        
        guard let result = response.result else {
            throw RPCError(code: -1, message: "No system info received")
        }
        
        #if DEBUG
        logger.debug("Retrieved system info - Device: \(result.deviceType ?? "Unknown"), Version: \(result.softwareVersion ?? "Unknown")")
        #endif
        
        return result
    }
    
    func getSystemUsage() async throws -> SystemUsage {
        #if DEBUG
        logger.debug("📊 RPC System Monitor: Usage statistics")
        #endif
        
        let response: RPCResponse<SystemUsage> = try await rpcBase.send(
            method: "system.getSystemUsage",
            responseType: SystemUsage.self
        )
        
        guard let result = response.result else {
            throw RPCError(code: -1, message: "No system usage info received")
        }
        
        #if DEBUG
        logger.debug("Retrieved system usage - CPU: \(result.cpuUsage ?? 0)%, Memory: \(result.memoryUsage ?? 0)%")
        #endif
        
        return result
    }
    
    func getCurrentTime() async throws -> SystemTime {
        #if DEBUG
        logger.debug("Getting current system time")
        #endif
        
        let response: RPCResponse<SystemTime> = try await rpcBase.send(
            method: "system.getCurrentTime",
            responseType: SystemTime.self
        )
        
        guard let result = response.result else {
            throw RPCError(code: -1, message: "No system time received")
        }
        
        #if DEBUG
        logger.debug("Retrieved system time: \(result.currentTime ?? "Unknown")")
        #endif
        
        return result
    }
    
    func getCapabilities() async throws -> SystemCapabilities {
        #if DEBUG
        logger.debug("Getting system capabilities")
        #endif
        
        let response: RPCResponse<SystemCapabilities> = try await rpcBase.send(
            method: "system.getCapabilities",
            responseType: SystemCapabilities.self
        )
        
        guard let result = response.result else {
            throw RPCError(code: -1, message: "No system capabilities received")
        }
        
        #if DEBUG
        logger.debug("Retrieved capabilities - Max Channels: \(result.maxChannels ?? 0), PTZ Support: \(result.supportPTZ ?? false)")
        #endif
        
        return result
    }
    
    func reboot() async throws -> Bool {
        #if DEBUG
        logger.debug("Initiating system reboot")
        #endif
        
        let response: RPCResponse<SuccessResponse> = try await rpcBase.send(
            method: "system.reboot",
            responseType: SuccessResponse.self
        )
        
        guard response.result != nil else {
            throw RPCError(code: -1, message: "Failed to initiate reboot")
        }
        
        #if DEBUG
        logger.debug("System reboot initiated successfully")
        #endif
        
        return true
    }
    
    func shutdown() async throws -> Bool {
        #if DEBUG
        logger.debug("Initiating system shutdown")
        #endif
        
        let response: RPCResponse<SuccessResponse> = try await rpcBase.send(
            method: "system.shutdown",
            responseType: SuccessResponse.self
        )
        
        guard response.result != nil else {
            throw RPCError(code: -1, message: "Failed to initiate shutdown")
        }
        
        #if DEBUG
        logger.debug("System shutdown initiated successfully")
        #endif
        
        return true
    }
}

struct MagicBoxInfo: Codable {
    let deviceModel: String?
    let serialNumber: String?
    let softwareVersion: String?
    let hardwareVersion: String?
    let buildDate: String?
    let uptime: Int?
    
    private enum CodingKeys: String, CodingKey {
        case deviceModel = "DeviceModel"
        case serialNumber = "SerialNo"
        case softwareVersion = "SoftwareVersion"
        case hardwareVersion = "HardwareVersion"
        case buildDate = "BuildDate"
        case uptime = "Uptime"
    }
}

struct MagicBoxStatus: Codable {
    let temperature: Double?
    let fanSpeed: Int?
    let powerStatus: String?
    let alarmStatus: String?
    
    private enum CodingKeys: String, CodingKey {
        case temperature = "Temperature"
        case fanSpeed = "FanSpeed"
        case powerStatus = "PowerStatus"
        case alarmStatus = "AlarmStatus"
    }
}

class MagicBoxRPC: RPCModule {
    let rpcBase: RPCBase
    private let logger = Logger()
    
    required init(rpcBase: RPCBase) {
        self.rpcBase = rpcBase
    }
    
    func getDeviceInfo() async throws -> MagicBoxInfo {
        #if DEBUG
        logger.debug("🔍 RPC System Info: Device information")
        #endif
        
        let response: RPCResponse<MagicBoxInfo> = try await rpcBase.send(
            method: "magicBox.getDeviceInfo",
            responseType: MagicBoxInfo.self
        )
        
        guard let result = response.result else {
            throw RPCError(code: -1, message: "No MagicBox device info received")
        }
        
        #if DEBUG
        logger.debug("Retrieved MagicBox info - Model: \(result.deviceModel ?? "Unknown"), Uptime: \(result.uptime ?? 0)s")
        #endif
        
        return result
    }
    
    func getDeviceStatus() async throws -> MagicBoxStatus {
        #if DEBUG
        logger.debug("Getting MagicBox device status")
        #endif
        
        let response: RPCResponse<MagicBoxStatus> = try await rpcBase.send(
            method: "magicBox.getDeviceStatus",
            responseType: MagicBoxStatus.self
        )
        
        guard let result = response.result else {
            throw RPCError(code: -1, message: "No MagicBox device status received")
        }
        
        #if DEBUG
        logger.debug("Retrieved MagicBox status - Temp: \(result.temperature ?? 0)°C, Fan: \(result.fanSpeed ?? 0) RPM")
        #endif
        
        return result
    }
    
    func getProductDefinition() async throws -> [String: Any] {
        #if DEBUG
        logger.debug("Getting product definition")
        #endif
        
        let response: RPCResponse<AnyJSON> = try await rpcBase.send(
            method: "magicBox.getProductDefinition",
            responseType: AnyJSON.self
        )
        
        guard let result = response.result?.dictionary else {
            throw RPCError(code: -1, message: "No product definition received")
        }
        
        #if DEBUG
        logger.debug("Retrieved product definition with \(result.keys.count) properties")
        #endif
        
        return result
    }
    
    func getVendorInfo() async throws -> [String: Any] {
        #if DEBUG
        logger.debug("Getting vendor information")
        #endif
        
        let response: RPCResponse<AnyJSON> = try await rpcBase.send(
            method: "magicBox.getVendorInfo",
            responseType: AnyJSON.self
        )
        
        guard let result = response.result?.dictionary else {
            throw RPCError(code: -1, message: "No vendor info received")
        }
        
        #if DEBUG
        logger.debug("Retrieved vendor info with \(result.keys.count) properties")
        #endif
        
        return result
    }
    
    func getSoftwareVersion() async throws -> [String: Any] {
        #if DEBUG
        logger.debug("Getting software version details")
        #endif
        
        let response: RPCResponse<AnyJSON> = try await rpcBase.send(
            method: "magicBox.getSoftwareVersion",
            responseType: AnyJSON.self
        )
        
        guard let result = response.result?.dictionary else {
            throw RPCError(code: -1, message: "No software version info received")
        }
        
        #if DEBUG
        logger.debug("Retrieved software version info")
        #endif
        
        return result
    }
}

private struct Logger {
    func debug(_ message: String) {
        #if DEBUG
        print("[SystemRPC Debug] \(message)")
        #endif
    }
    
    func error(_ message: String) {
        #if DEBUG
        print("[SystemRPC Error] \(message)")
        #endif
    }
}