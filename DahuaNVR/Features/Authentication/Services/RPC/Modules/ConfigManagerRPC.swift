import Foundation

protocol RPCModule {
    var rpcBase: RPCBase { get }
    init(rpcBase: RPCBase)
}


struct ConfigResult: Codable {
    let result: Bool
    let error: String?
}

private struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        if let intValue = value as? Int {
            try container.encode(intValue)
        } else if let stringValue = value as? String {
            try container.encode(stringValue)
        } else if let boolValue = value as? Bool {
            try container.encode(boolValue)
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue)
        } else if let dictValue = value as? [String: Any] {
            try container.encode(dictValue.mapValues(AnyCodable.init))
        } else if let arrayValue = value as? [Any] {
            try container.encode(arrayValue.map(AnyCodable.init))
        } else {
            try container.encodeNil()
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else {
            value = NSNull()
        }
    }
}

class ConfigManagerRPC: RPCModule {
    let rpcBase: RPCBase
    private let logger = Logger()
    
    required init(rpcBase: RPCBase) {
        self.rpcBase = rpcBase
    }
    
    func getConfig(name: String, channel: Int? = nil) async throws -> [String: Any] {
        var params: [String: AnyJSON] = ["name": AnyJSON(name)]
        
        if let channel = channel {
            params["channel"] = AnyJSON(channel)
        }
        
        #if DEBUG
        logger.debug("⚙️ RPC Config Get: \(name)")
        if let channel = channel {
            logger.debug("   → Channel: \(channel)")
        }
        #endif
        
        let response: RPCResponse<AnyJSON> = try await rpcBase.send(
            method: "configManager.getConfig",
            params: params,
            responseType: AnyJSON.self
        )
        
        guard let result = response.result?.dictionary else {
            throw RPCError(code: -1, message: "No config data received for \(name)")
        }
        
        #if DEBUG
        logger.debug("Retrieved config \(name): \(result.keys.joined(separator: ", "))")
        #endif
        
        return result
    }
    
    func setConfig(name: String, table: [String: Any], channel: Int? = nil) async throws -> Bool {
        var params: [String: AnyJSON] = [
            "name": AnyJSON(name),
            "table": AnyJSON(table)
        ]
        
        if let channel = channel {
            params["channel"] = AnyJSON(channel)
        }
        
        #if DEBUG
        logger.debug("📝 RPC Config Set: \(name)")
        if let channel = channel {
            logger.debug("   → Channel: \(channel)")
        }
        logger.debug("   → Table keys: \(table.keys.joined(separator: ", "))")
        #endif
        
        let response: RPCResponse<ConfigResult> = try await rpcBase.send(
            method: "configManager.setConfig",
            params: params,
            responseType: ConfigResult.self
        )
        
        guard let result = response.result else {
            throw RPCError(code: -1, message: "No result received for setting config \(name)")
        }
        
        if !result.result {
            let errorMessage = result.error ?? "Unknown error"
            throw RPCError(code: -1, message: "Failed to set config \(name): \(errorMessage)")
        }
        
        #if DEBUG
        logger.debug("Successfully set config: \(name)")
        #endif
        
        return result.result
    }
    
    func getEncodeConfig(channel: Int) async throws -> [String: Any] {
        return try await getConfig(name: "Encode", channel: channel)
    }
    
    func setEncodeConfig(channel: Int, config: [String: Any]) async throws -> Bool {
        return try await setConfig(name: "Encode", table: config, channel: channel)
    }
    
    func getVideoConfig(channel: Int) async throws -> [String: Any] {
        return try await getConfig(name: "VideoWidget", channel: channel)
    }
    
    func setVideoConfig(channel: Int, config: [String: Any]) async throws -> Bool {
        return try await setConfig(name: "VideoWidget", table: config, channel: channel)
    }
    
    func getSystemConfig() async throws -> [String: Any] {
        return try await getConfig(name: "General")
    }
    
    func setSystemConfig(config: [String: Any]) async throws -> Bool {
        return try await setConfig(name: "General", table: config)
    }
    
    func getNetworkConfig() async throws -> [String: Any] {
        return try await getConfig(name: "Network")
    }
    
    func setNetworkConfig(config: [String: Any]) async throws -> Bool {
        return try await setConfig(name: "Network", table: config)
    }
    
    func getStorageConfig() async throws -> [String: Any] {
        return try await getConfig(name: "Storage")
    }
    
    func setStorageConfig(config: [String: Any]) async throws -> Bool {
        return try await setConfig(name: "Storage", table: config)
    }
    
    func backupConfig() async throws -> String {
        #if DEBUG
        logger.debug("Creating configuration backup")
        #endif
        
        let response: RPCResponse<AnyJSON> = try await rpcBase.send(
            method: "configManager.backup",
            responseType: AnyJSON.self
        )
        
        guard let result = response.result?.dictionary,
              let backupData = result["data"] as? String else {
            throw RPCError(code: -1, message: "Failed to create configuration backup")
        }
        
        #if DEBUG
        logger.debug("Configuration backup created successfully")
        #endif
        
        return backupData
    }
    
    func restoreConfig(backupData: String) async throws -> Bool {
        let params: [String: AnyJSON] = ["data": AnyJSON(backupData)]
        
        #if DEBUG
        logger.debug("Restoring configuration from backup")
        #endif
        
        let response: RPCResponse<ConfigResult> = try await rpcBase.send(
            method: "configManager.restore",
            params: params,
            responseType: ConfigResult.self
        )
        
        guard let result = response.result else {
            throw RPCError(code: -1, message: "No result received for config restore")
        }
        
        if !result.result {
            let errorMessage = result.error ?? "Unknown error"
            throw RPCError(code: -1, message: "Failed to restore config: \(errorMessage)")
        }
        
        #if DEBUG
        logger.debug("Configuration restored successfully")
        #endif
        
        return result.result
    }
}

private struct Logger {
    func debug(_ message: String) {
        #if DEBUG
        print("[ConfigManagerRPC Debug] \(message)")
        #endif
    }
    
    func error(_ message: String) {
        #if DEBUG
        print("[ConfigManagerRPC Error] \(message)")
        #endif
    }
}