import Testing
@testable import DahuaNVR
import Foundation
import CryptoKit

struct RPCTests {
    
    @Test("RPCBase can create valid JSON-RPC requests")
    func testRPCRequestCreation() {
        let params: [String: AnyJSON] = ["key": AnyJSON("value")]
        let request = RPCRequest(method: "test.method", params: params)
        
        #expect(request.method == "test.method")
        #expect(request.object == nil)  // Should be nil by default
        #expect(request.session == nil)  // Should be nil by default
        #expect(request.params != nil)
    }
    
    @Test("RPCBase handles response parsing correctly")
    func testRPCResponseParsing() throws {
        let responseData = """
        {
            "result": {"status": "success"},
            "error": null,
            "id": 1,
            "session": "123"
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(RPCResponse<[String: String]>.self, from: responseData)
        
        #expect(response.isSuccess == true)
        #expect(response.result?["status"] == "success")
        #expect(response.error == nil)
        #expect(response.session == "123")
    }
    
    @Test("RPCBase handles error responses correctly")
    func testRPCErrorHandling() throws {
        let errorData = """
        {
            "result": null,
            "error": {"code": 500, "message": "Internal error"},
            "id": 1,
            "session": "123"
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(RPCResponse<[String: String]>.self, from: errorData)
        
        #expect(response.isSuccess == false)
        #expect(response.error?.code == 500)
        #expect(response.error?.message == "Internal error")
        #expect(response.session == "123")
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
    
    @Test("RPCBase session management")
    func testRPCBaseSessionManagement() {
        let rpcBase = RPCBase(baseURL: "http://test.com")
        
        // Initially no session
        #expect(!rpcBase.hasActiveSession)
        
        // Set session ID
        rpcBase.setSession(id: "test-session-123")
        #expect(rpcBase.hasActiveSession)
        
        // Clear session
        rpcBase.clearSession()
        #expect(!rpcBase.hasActiveSession)
    }
    
    @Test("AuthParams structure handles all fields")
    func testAuthParamsStructure() throws {
        let authData = """
        {
            "random": "random123",
            "realm": "Login to device",
            "encryption": "Default",
            "authorization": "Basic"
        }
        """.data(using: .utf8)!
        
        let authParams = try JSONDecoder().decode(AuthParams.self, from: authData)
        
        #expect(authParams.random == "random123")
        #expect(authParams.realm == "Login to device")
        #expect(authParams.encryption == "Default")
        #expect(authParams.authorization == "Basic")
    }
    
    @Test("LoginResult structure handles session field")
    func testLoginResultStructure() throws {
        let loginData = """
        {
            "keepAliveInterval": 60,
            "session": 12345,
            "rspCode": 200
        }
        """.data(using: .utf8)!
        
        let loginResult = try JSONDecoder().decode(LoginResult.self, from: loginData)
        
        #expect(loginResult.keepAliveInterval == 60)
        #expect(loginResult.session == 12345)
        #expect(loginResult.rspCode == 200)
    }
}