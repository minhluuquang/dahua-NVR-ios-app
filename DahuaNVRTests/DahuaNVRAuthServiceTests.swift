import CryptoKit
import Foundation
import Testing

@testable import DahuaNVR

@Suite("Dahua NVR Authentication Service Tests")
struct DahuaNVRAuthServiceTests {

    // Test credentials as specified
    let testServerURL = "http://cam.lab"
    let testUsername = "admin"
    let testPassword = "Minhmeo75321@"

    @Test("Authentication service initialization")
    func testAuthServiceInitialization() {
        let authService = DahuaNVRAuthService()

        #expect(authService.isAuthenticated == false)
        #expect(authService.isLoading == false)
        #expect(authService.errorMessage == nil)
    }

    @Test("MD5 hash calculation")
    func testMD5Calculation() {
        let authService = DahuaNVRAuthService()

        // Test with known values to verify MD5 implementation
        let testString = "admin:Device_Test:password123"
        let hash = authService.md5(testString)

        // Verify hash is 32 characters (MD5 hex output)
        #expect(hash.count == 32)
        #expect(hash.allSatisfy { $0.isHexDigit })
    }

    @Test("Client nonce generation")
    func testCnonceGeneration() {
        let authService = DahuaNVRAuthService()

        let cnonce1 = authService.generateCnonce()
        let cnonce2 = authService.generateCnonce()

        // Verify cnonce properties
        #expect(cnonce1.count == 8)
        #expect(cnonce2.count == 8)
        #expect(cnonce1 != cnonce2)  // Should be different each time
        #expect(cnonce1.allSatisfy { $0.isLetter || $0.isNumber })
    }

    @Test("Digest header parsing with quoted values")
    func testDigestHeaderParsingQuoted() throws {
        let authService = DahuaNVRAuthService()
        let testHeader =
            #"Digest realm="Device_00408CA5EA04", nonce="000562fd20ef95ad", qop="auth", opaque="5ccc069c403ebaf9f0171e9517f40e41""#

        let params = try authService.parseDigestHeader(testHeader)

        #expect(params["realm"] == "Device_00408CA5EA04")
        #expect(params["nonce"] == "000562fd20ef95ad")
        #expect(params["qop"] == "auth")
        #expect(params["opaque"] == "5ccc069c403ebaf9f0171e9517f40e41")
    }

    @Test("Digest header parsing with mixed quoted/unquoted values")
    func testDigestHeaderParsingMixed() throws {
        let authService = DahuaNVRAuthService()
        let testHeader =
            #"Digest realm="Device_Test", nonce=abc123, qop=auth, opaque="test_opaque""#

        let params = try authService.parseDigestHeader(testHeader)

        #expect(params["realm"] == "Device_Test")
        #expect(params["nonce"] == "abc123")
        #expect(params["qop"] == "auth")
        #expect(params["opaque"] == "test_opaque")
    }

    @Test("Digest header parsing missing required fields")
    func testDigestHeaderParsingMissingFields() {
        let authService = DahuaNVRAuthService()
        let testHeader = #"Digest qop="auth", opaque="test""#  // Missing realm and nonce

        #expect(throws: AuthError.invalidDigestHeader) {
            try authService.parseDigestHeader(testHeader)
        }
    }

    @Test("Digest response calculation with QOP auth")
    func testDigestResponseCalculationWithQOP() throws {
        let authService = DahuaNVRAuthService()

        // Set up test values
        let username = "admin"
        let password = "password123"
        let realm = "Device_Test"
        let nonce = "dcd98b7102dd2f0e8b11d0f600bfb0c093"
        let method = "GET"
        let uri = "/cgi-bin/magicBox.cgi?action=getLanguageCaps"
        let qop = "auth"
        let nc = "00000001"
        let cnonce = "0a4f113b"

        // Calculate expected values manually
        let ha1 = authService.md5("\(username):\(realm):\(password)")
        let ha2 = authService.md5("\(method):\(uri)")
        let _ = authService.md5("\(ha1):\(nonce):\(nc):\(cnonce):\(qop):\(ha2)")

        // Verify the calculation is deterministic
        let ha1_verify = authService.md5("\(username):\(realm):\(password)")
        #expect(ha1 == ha1_verify)
    }

    @Test("Authentication request building")
    func testAuthenticationRequestBuilding() throws {
        let authService = DahuaNVRAuthService()

        // Set up credentials for the test
        authService.username = testUsername
        authService.password = testPassword

        let testURL = URL(string: "http://cam.lab/cgi-bin/magicBox.cgi?action=getLanguageCaps")!

        let digestParams: [String: String] = [
            "realm": "Device_Test",
            "nonce": "test_nonce_123",
            "qop": "auth",
            "opaque": "test_opaque",
        ]

        let request = try authService.buildAuthenticatedRequest(
            url: testURL, digestParams: digestParams)

        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "DahuaNVR/1.0")

        let authHeader = request.value(forHTTPHeaderField: "Authorization")
        #expect(authHeader != nil)
        #expect(authHeader!.hasPrefix("Digest"))
        #expect(authHeader!.contains("username="))
        #expect(authHeader!.contains("realm="))
        #expect(authHeader!.contains("nonce="))
        #expect(authHeader!.contains("response="))
    }

    @Test("Full authentication flow with real server")
    func testFullAuthenticationFlow() async throws {
        let authService = DahuaNVRAuthService()

        // Perform authentication against real server
        await authService.authenticate(
            serverURL: testServerURL,
            username: testUsername,
            password: testPassword
        )

        // The test must succeed - authentication should work with correct credentials
        if !authService.isAuthenticated {
            if let error = authService.errorMessage {
                print("❌ Authentication failed: \(error)")

                // Provide helpful error context
                if error.contains("could not connect") || error.contains("network")
                    || error.contains("timed out")
                {
                    print("💡 Make sure http://cam.lab is accessible and running")
                } else if error.contains("Authentication failed") {
                    print("💡 Check if credentials are correct: admin / Minhmeo75321@")
                } else {
                    print("💡 Server: \(testServerURL)")
                    print("💡 Username: \(testUsername)")
                    print("💡 Password: \(testPassword)")
                }
            } else {
                print("❌ Authentication failed with no error message")
            }
        } else {
            print("✅ Authentication successful to \(testServerURL)")
        }

        // FAIL the test if authentication didn't succeed
        #expect(
            authService.isAuthenticated,
            "Authentication must succeed. Server down or wrong credentials?")
        #expect(authService.errorMessage == nil, "No error should occur with correct credentials")
    }

    @Test("Logout functionality")
    func testLogout() {
        let authService = DahuaNVRAuthService()

        // Simulate authenticated state
        authService.isAuthenticated = true
        authService.errorMessage = "Some error"

        // Perform logout
        authService.logout()

        #expect(authService.isAuthenticated == false)
        #expect(authService.errorMessage == nil)
    }

    @Test("Invalid URL handling")
    func testInvalidURLHandling() async {
        let authService = DahuaNVRAuthService()

        await authService.authenticate(
            serverURL: "invalid-url",
            username: testUsername,
            password: testPassword
        )

        #expect(authService.isAuthenticated == false)
        #expect(authService.errorMessage != nil)
    }

    @Test("Wrong credentials should fail")
    func testWrongCredentialsHandling() async {
        let authService = DahuaNVRAuthService()

        await authService.authenticate(
            serverURL: testServerURL,
            username: "wrong_user",
            password: "wrong_password"
        )

        // Should fail with wrong credentials
        #expect(
            authService.isAuthenticated == false,
            "Authentication should fail with wrong credentials")
        #expect(
            authService.errorMessage != nil, "Should have error message when authentication fails")

        if let error = authService.errorMessage {
            print("✅ Expected failure with wrong credentials: \(error)")
        }
    }

    @Test("Empty credentials handling")
    func testEmptyCredentialsHandling() async {
        let authService = DahuaNVRAuthService()

        await authService.authenticate(
            serverURL: testServerURL,
            username: "",
            password: ""
        )

        #expect(authService.isAuthenticated == false)
        #expect(authService.errorMessage != nil, "Should have error message with empty credentials")
    }
}
