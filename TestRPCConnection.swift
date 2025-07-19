import Foundation

// Test script to verify RPC connection
@main
struct TestRPCConnection {
    static func main() async {
        print("=== Dahua NVR RPC Connection Test ===")
        
        // Test configuration - update these values
        let serverURL = "http://192.168.1.108:80"  // Update with your NVR IP
        let username = "admin"
        let password = "admin123"  // Update with your password
        
        print("Server: \(serverURL)")
        print("Username: \(username)")
        print("")
        
        // Test dual protocol service
        let dualService = DualProtocolService(baseURL: serverURL)
        let credentials = NVRCredentials(
            serverURL: serverURL,
            username: username,
            password: password
        )
        
        print("Starting authentication...")
        let result = await dualService.authenticate(credentials: credentials)
        
        print("\n=== Authentication Results ===")
        print("HTTP CGI: \(result.httpCGI.success ? "✅ Success" : "❌ Failed")")
        if let error = result.httpCGI.error {
            print("  Error: \(error)")
        }
        
        print("RPC: \(result.rpc.success ? "✅ Success" : "❌ Failed")")
        if let error = result.rpc.error {
            print("  Error: \(error)")
        }
        
        print("\nBoth Successful: \(result.bothSuccessful ? "✅" : "❌")")
        
        // If RPC succeeded, try some API calls
        if result.rpc.success {
            print("\n=== Testing RPC API Calls ===")
            
            do {
                // Test MagicBox API
                print("\n1. Getting device info...")
                let deviceType = try await dualService.rpc.magicBox.getDeviceType()
                print("   Device Type: \(deviceType)")
                
                let deviceClass = try await dualService.rpc.magicBox.getDeviceClass()
                print("   Device Class: \(deviceClass)")
                
                let vendor = try await dualService.rpc.magicBox.getVendor()
                print("   Vendor: \(vendor)")
                
                // Test System API
                print("\n2. Getting system info...")
                let deviceInfo = try await dualService.rpc.system.getDeviceInfo()
                print("   Device Info: \(deviceInfo)")
                
                let cpuUsage = try await dualService.rpc.system.getCPUUsage()
                print("   CPU Usage: \(cpuUsage)%")
                
                let memoryInfo = try await dualService.rpc.system.getMemoryInfo()
                print("   Memory: \(memoryInfo)")
                
                print("\n✅ All RPC API calls successful!")
                
            } catch {
                print("\n❌ RPC API Error: \(error)")
            }
        }
        
        // Disconnect
        print("\nDisconnecting...")
        await dualService.disconnect()
        print("Done.")
    }
}

// Include necessary files from the project
// Note: This is a standalone test file. To run it properly, you would need to:
// 1. Import the DahuaNVR module or
// 2. Include all the necessary source files in a test target