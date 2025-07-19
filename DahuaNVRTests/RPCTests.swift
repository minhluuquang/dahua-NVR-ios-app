import Testing
@testable import DahuaNVR
import Foundation
import CryptoKit

struct RPCTests {
    
    @Test("RPCBase can create valid JSON-RPC requests")
    func testRPCRequestCreation() {
        let request = RPCRequest(method: "test.method", params: ["key": "value"])
        
        #expect(request.method == "test.method")
        #expect(request.object == 0)
        #expect(request.session == 0)
        #expect(request.params != nil)
    }
    
    @Test("RPCBase handles response parsing correctly")
    func testRPCResponseParsing() throws {
        let responseData = """
        {
            "result": {"status": "success"},
            "error": null,
            "id": 1,
            "session": 123
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(RPCResponse<[String: String]>.self, from: responseData)
        
        #expect(response.isSuccess == true)
        #expect(response.result?["status"] == "success")
        #expect(response.error == nil)
    }
    
    @Test("RPCBase handles error responses correctly")
    func testRPCErrorHandling() throws {
        let errorData = """
        {
            "result": null,
            "error": {"code": 500, "message": "Internal error"},
            "id": 1,
            "session": 123
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(RPCResponse<[String: String]>.self, from: errorData)
        
        #expect(response.isSuccess == false)
        #expect(response.error?.code == 500)
        #expect(response.error?.message == "Internal error")
    }
    
    @Test("ConfigManagerRPC module initialization")
    func testConfigManagerInit() {
        let rpcBase = RPCBase(baseURL: "http://test.com")
        let configManager = ConfigManagerRPC(rpcBase: rpcBase)
        
        #expect(configManager.rpcBase === rpcBase)
    }
    
    @Test("SystemRPC module initialization")
    func testSystemRPCInit() {
        let rpcBase = RPCBase(baseURL: "http://test.com")
        let systemRPC = SystemRPC(rpcBase: rpcBase)
        
        #expect(systemRPC.rpcBase === rpcBase)
    }
    
    @Test("MagicBoxRPC module initialization")
    func testMagicBoxRPCInit() {
        let rpcBase = RPCBase(baseURL: "http://test.com")
        let magicBoxRPC = MagicBoxRPC(rpcBase: rpcBase)
        
        #expect(magicBoxRPC.rpcBase === rpcBase)
    }
    
    @Test("RPCService initializes all modules correctly")
    func testRPCServiceInit() {
        let rpcService = RPCService(baseURL: "http://test.com")
        
        #expect(rpcService.configManager.rpcBase !== nil)
        #expect(rpcService.system.rpcBase !== nil)
        #expect(rpcService.magicBox.rpcBase !== nil)
        #expect(rpcService.isAuthenticated == false)
    }
    
    @Test("DualProtocolService initializes both services")
    func testDualProtocolServiceInit() {
        let dualService = DualProtocolService(baseURL: "http://test.com")
        
        #expect(dualService.httpCGI !== nil)
        #expect(dualService.rpc !== nil)
        #expect(dualService.isFullyAuthenticated == false)
    }
    
    @Test("AuthenticationResult calculates bothSuccessful correctly")
    func testAuthenticationResult() {
        let httpSuccess = AuthResult(success: true, protocol: "HTTP CGI")
        let rpcSuccess = AuthResult(success: true, protocol: "RPC")
        let rpcFailure = AuthResult(success: false, protocol: "RPC")
        
        let bothSuccess = AuthenticationResult(httpCGI: httpSuccess, rpc: rpcSuccess)
        let partialSuccess = AuthenticationResult(httpCGI: httpSuccess, rpc: rpcFailure)
        
        #expect(bothSuccess.bothSuccessful == true)
        #expect(partialSuccess.bothSuccessful == false)
    }
    
    @Test("NVRSystem model supports authentication status")
    func testNVRSystemAuthStatus() {
        let credentials = NVRCredentials(serverURL: "http://test.com", username: "user", password: "pass")
        let system = NVRSystem(
            name: "Test NVR",
            credentials: credentials,
            rpcAuthSuccess: true,
            httpCGIAuthSuccess: true
        )
        
        #expect(system.dualAuthAvailable == true)
        #expect(system.authenticationStatus.contains("✓"))
        
        let partialSystem = NVRSystem(
            name: "Test NVR",
            credentials: credentials,
            rpcAuthSuccess: false,
            httpCGIAuthSuccess: true
        )
        
        #expect(partialSystem.dualAuthAvailable == false)
        #expect(partialSystem.authenticationStatus.contains("✗"))
    }
}

struct RPCLoginTests {
    
    @Test("RPCLogin initialization")
    func testRPCLoginInit() {
        let rpcBase = RPCBase(baseURL: "http://test.com")
        let rpcLogin = RPCLogin(rpcBase: rpcBase)
        
        #expect(!rpcLogin.hasActiveSession)
    }
}