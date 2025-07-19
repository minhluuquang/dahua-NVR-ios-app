# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
This is a SwiftUI-based iOS application for Dahua NVR (Network Video Recorder) management with **dual protocol support** (HTTP CGI + RPC). The project is a standard iOS app created with Xcode 16+ using the modern Swift Testing framework. The application implements both Dahua's legacy HTTP CGI and modern RPC (Remote Procedure Call) interfaces, providing developers with full protocol flexibility. Always refers to related information in @PRD.md, @app-flow.md, and @RPC_plan.md files.

### Architecture
- **Dual Protocol Implementation**: Both HTTP CGI and RPC authentication established during connection
- **Developer Choice**: Explicit protocol selection (HTTP CGI or RPC) for each operation
- **No Automatic Fallback**: Independent protocol management for maximum control
- **Modular RPC Design**: Type-safe, module-based RPC implementation

## Build Commands
```bash
# Build the app (Debug configuration)
xcodebuild -project DahuaNVR.xcodeproj -scheme DahuaNVR -configuration Debug build

# Build for Release
xcodebuild -project DahuaNVR.xcodeproj -scheme DahuaNVR -configuration Release build

# Build and run tests
xcodebuild test -project DahuaNVR.xcodeproj -scheme DahuaNVR -destination 'platform=iOS Simulator,name=iPhone 15'

# Run only unit tests
xcodebuild test -project DahuaNVR.xcodeproj -scheme DahuaNVR -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:DahuaNVRTests

# Run only UI tests  
xcodebuild test -project DahuaNVR.xcodeproj -scheme DahuaNVR -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:DahuaNVRUITests
```

## Project Structure
- **DahuaNVR/**: Main app source code
  - **App/**: Application entry point
    - `DahuaNVRApp.swift`: Main app entry point with `@main` attribute
  - **Configuration/**: App configuration
    - `AppConfiguration.swift`: Application configuration settings
  - **Features/**: Feature-based organization
    - **Authentication/**: User authentication system with dual protocol support
      - **Models/**: Authentication data models
        - `AuthenticationState`: App authentication state management
        - `NVRCredentials`: User credentials for NVR connection
        - `PersistedAuthData`: Keychain-stored authentication data
        - `NVRSystem`: NVR system model with dual auth status tracking
      - **Services/**: Authentication and communication services
        - `AuthenticationManager`: Central authentication orchestration
        - `DahuaNVRAuthService`: Legacy HTTP CGI authentication
        - `KeychainHelper`: Secure credential storage
        - `DualProtocolService`: **NEW** - Parallel HTTP CGI + RPC authentication
        - `NVRManager`: NVR system management with dual auth status
        - **RPC/**: **NEW** - Complete RPC implementation
          - `RPCBase.swift`: Core RPC communication infrastructure
          - `RPCLogin.swift`: Two-stage RPC authentication with keep-alive
          - `RPCService.swift`: Main RPC service coordinator
          - `RPCTypes.swift`: Type-safe RPC data structures
          - **Modules/**: RPC functional modules
            - `ConfigManagerRPC.swift`: Configuration management via RPC
            - `SystemRPC.swift`: System information and control via RPC
      - **ViewModels/**: Authentication view models (`ContentViewModel`, `LoginViewModel`)
      - **Views/**: Authentication UI
        - `ContentView`: Main app entry view
        - `LoginView`: User authentication interface
        - `MainAppView`: **NEW** - Main application interface with tab navigation
        - `NVRListView`: **NEW** - NVR system selection and management
        - `CameraTabView`: **NEW** - Camera listing and management
    - **Settings/**: Application settings with dual protocol support
      - **Services/**: Settings-related services
        - `CameraAPIService`: Enhanced camera API with comprehensive logging
      - **Views/**: Settings UI components
        - `SettingsDashboardView`: Main settings interface
        - `CameraSettingsView`: **NEW** - Camera-specific settings
    - **Shared/**: Shared UI components
      - **Views/**: Reusable UI components (`SettingsRowView`)
  - **Assets.xcassets/**: App icons and visual assets
  - `Info.plist`: App configuration plist
- **DahuaNVRTests/**: Unit tests using Swift Testing framework
  - `RPCTests.swift`: **NEW** - Comprehensive RPC functionality tests
- **DahuaNVRUITests/**: UI automation tests

## Testing Framework
This project uses the modern **Swift Testing** framework (not XCTest). Tests are written with:
- `@Test` attribute for test functions
- `#expect(...)` for assertions
- `@testable import DahuaNVR` for accessing internal app code

## Development Notes
- Target platform: iOS
- UI Framework: SwiftUI
- Project format: Xcode project (`.xcodeproj`)
- Architecture: Feature-based modular organization with MVVM pattern
- **Dual Protocol Support**: Both HTTP CGI and RPC authentication/communication
- Authentication system implemented with keychain storage
- Settings dashboard with multiple configuration views
- Three main targets: DahuaNVR (app), DahuaNVRTests (unit tests), DahuaNVRUITests (UI tests)

## RPC Implementation Status
Based on @RPC_plan.md, the following RPC components are **COMPLETED**:

### ✅ Phase 1: Foundation Infrastructure
- **RPCBase**: Core RPC communication with JSON-RPC protocol
- **RPCLogin**: Two-stage authentication with MD5 digest and keep-alive
- **RPCTypes**: Type-safe data structures for RPC communication
- **Session Management**: HTTP cookie-based session handling

### ✅ Phase 2: Core RPC Modules  
- **ConfigManagerRPC**: Complete configuration management (get/set operations)
- **SystemRPC**: System information, monitoring, and control operations
- **MagicBox Integration**: Device-specific operations

### ✅ Phase 3: Dual Protocol Service
- **DualProtocolService**: Parallel HTTP CGI + RPC authentication
- **Authentication Results**: Independent status tracking for both protocols
- **Developer Interface**: Explicit protocol choice (no automatic fallback)
- **NVRSystem Model**: Enhanced with dual authentication status

### ✅ Phase 4: Testing & Integration
- **RPCTests**: Comprehensive unit test suite for all RPC components
- **Integration**: Seamless integration with existing authentication flow
- **UI Updates**: Visual indicators for dual authentication status

## Development Logging
Both HTTP CGI and RPC services include comprehensive logging for development mode:

### HTTP CGI Logging (CameraAPIService):
- **HTTP Request/Response Details**: Full URL, headers, status codes, response bodies
- **Authentication Flow**: Digest auth challenges, parsed parameters
- **Data Parsing**: Response parsing steps, camera creation failures
- **Network Errors**: URLError details, connection issues
- **Context-Specific Errors**: Detailed error messages with operation context

### RPC Logging (RPCBase & Modules):
- **RPC Request/Response Details**: JSON-RPC method calls, parameters, responses
- **Authentication Flow**: Two-stage login process, session establishment
- **Session Management**: Cookie handling, keep-alive mechanisms
- **Module Operations**: ConfigManager and System module interactions
- **Error Handling**: RPC-specific error codes and messages

### Viewing Logs:
- **Xcode Console**: View real-time logs during development
- **Device Console**: Use Console.app to view system logs
- **Breakpoint Debugging**: Set breakpoints in error handlers for detailed inspection

### Debug vs Release:
- Detailed logging is only active in DEBUG builds (`#if DEBUG`)
- Release builds will have minimal logging for performance
- Use `logger.debug()`, `logger.error()`, and `logger.warning()` for different log levels

## Developer Usage Guide

### Using Dual Protocol Services:
```swift
// Access both protocols through DualProtocolService
let dualService = DualProtocolService(credentials: credentials)

// Authenticate both protocols
let authResult = await dualService.authenticate()

// Use HTTP CGI for legacy operations
let cameras = await dualService.httpCGI.getCameras()

// Use RPC for advanced operations  
let systemInfo = await dualService.rpc.system.getDeviceInfo()
let config = await dualService.rpc.configManager.getConfig("Encode", channel: 0)
```

### RPC Module Examples:
```swift
// System information via RPC
let cpuUsage = await rpcService.system.getCPUUsage()
let memoryInfo = await rpcService.system.getMemoryInfo()

// Configuration management via RPC
await rpcService.configManager.setConfig("VideoWidget", table: widgetConfig, channel: 0)
let encodeConfig = await rpcService.configManager.getConfig("Encode", channel: 1)
```

## Important Guidelines
- Never update anything in @DahuaNVR.xcodeproj/project.pbxproj file
- Always add -quiet flag when running test. Example: xcodebuild test -quiet -project DahuaNVR.xcodeproj -scheme DahuaNVR -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:DahuaNVRTests/RPCTests/RPCTests
- Always add -quiet flag when running build. Example: xcodebuild -quiet -project DahuaNVR.xcodeproj -scheme DahuaNVR -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' build
