# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DahuaNVR is a production-ready SwiftUI iOS application for Dahua Network Video Recorder (NVR) management. The app features a modern RPC-only architecture with robust security, comprehensive encryption, and seamless camera management capabilities for professional surveillance systems.

## Tech Stack

- **Platform**: iOS 18.5+
- **Language**: Swift 6.1.2
- **UI Framework**: SwiftUI (declarative UI)
- **Architecture**: MVVM with RPC-only communication
- **Testing**: Swift Testing Framework (modern, not XCTest)
- **Security**: Keychain Services, RSA/AES hybrid encryption
- **Dependencies**: BigInt, CryptoSwift, HaishinKit
- **Development Tool**: Xcode 16+

## Project Structure

```
DahuaNVR/
├── App/
│   └── DahuaNVRApp.swift                 # Main app entry point
├── Configuration/
│   └── AppConfiguration.swift           # App configuration settings
├── Features/
│   ├── Authentication/
│   │   ├── Models/                      # Data models (AuthenticationState, NVRCredentials)
│   │   ├── Services/                    # Core business logic
│   │   │   ├── AuthenticationManager.swift      # Central auth orchestration
│   │   │   ├── RPCAuthenticationService.swift   # RPC-only auth service
│   │   │   ├── KeychainHelper.swift             # Secure credential storage
│   │   │   ├── RPC/                             # Complete RPC implementation
│   │   │   │   ├── RPCBase.swift                # Core RPC communication
│   │   │   │   ├── RPCService.swift             # Main RPC coordinator
│   │   │   │   └── Modules/                     # Feature-specific RPC modules
│   │   │   │       ├── CameraRPC.swift          # Camera operations
│   │   │   │       ├── SecurityRPC.swift        # Security & encryption
│   │   │   │       └── SystemRPC.swift          # System information
│   │   │   └── Encryption/              # Hybrid RSA/AES encryption system
│   │   ├── ViewModels/                  # MVVM presentation logic
│   │   └── Views/                       # SwiftUI interface components
│   ├── Settings/
│   │   └── Views/                       # Settings UI (CameraSettingsView, etc.)
│   └── Shared/
│       └── Views/                       # Reusable UI components
└── Assets.xcassets/                     # App icons and visual assets

DahuaNVRTests/                           # Unit tests with Swift Testing
DahuaNVRUITests/                         # UI automation tests
```

## Common Commands

```bash
# Development
xcodebuild -quiet -project DahuaNVR.xcodeproj -scheme DahuaNVR -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -quiet -project DahuaNVR.xcodeproj -scheme DahuaNVR -configuration Release build

# Testing
xcodebuild test -quiet -project DahuaNVR.xcodeproj -scheme DahuaNVR -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild test -quiet -project DahuaNVR.xcodeproj -scheme DahuaNVR -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:DahuaNVRTests
```

## Coding Standards

### Architecture Patterns
- **RPC-Only Communication**: All server interactions use JSON-RPC protocol via `RPCService`
- **MVVM Pattern**: Views → ViewModels → Services → Models
- **Dependency Management**: Services accessed through `AuthenticationManager.shared.rpcService`
- **Async/Await**: Modern concurrency patterns throughout codebase
- **Feature-Based Organization**: Code organized by business functionality, not technical layers

### Code Quality Standards
- **Swift Testing Framework**: Use `@Test` and `#expect()` (not XCTest)
- **Error Handling**: Comprehensive error types with `LocalizedError` conformance
- **Security**: Always use keychain for credential storage, never plaintext
- **Logging**: Use `#if DEBUG` guards for development-only logging
- **Memory Safety**: Proper `@MainActor` usage for UI updates

### API Usage Patterns
```swift
// Correct RPC service access
guard let rpcService = AuthenticationManager.shared.rpcService else { return }
let cameras = try await rpcService.camera.getAllCameras()

// Correct async UI updates
await MainActor.run {
    self.isLoading = false
    self.cameras = fetchedCameras
}
```

## Workflow Instructions

### Development Process
1. **Always read existing files** before making changes to understand current patterns
2. **Run tests before commits**: Unit tests must pass before code integration
3. **Security First**: Review all authentication and encryption code changes
4. **UI Consistency**: Follow existing SwiftUI patterns and component structure
5. **RPC Integration**: All server communication must use established RPC modules

### Git Practices
- **Never modify** `DahuaNVR.xcodeproj/project.pbxproj` directly
- **Always use `-quiet` flag** in build/test commands for cleaner output
- **Test on simulator** before device deployment

## Custom Rules & Notes

### Current Architecture Status (B+ Grade - 83/100)

**✅ Production Ready Components:**
- RPC-only architecture with comprehensive modules
- Robust RSA/AES hybrid encryption system
- Secure keychain credential management
- Modern Swift async/await patterns
- Comprehensive unit test coverage

**⚠️ Known Technical Debt:**
- Code duplication in camera fetching logic (CameraTabView vs CameraSettingsView)
- Mixed model types (NVRCamera/CameraDevice) need consolidation
- UI views tightly coupled to AuthenticationManager singleton
- Incomplete implementations: SnapshotSettings, OverlaySettings, CameraName
- Large view files need decomposition (CameraSettingsView: 750 lines)

### Priority Improvements
1. **Extract shared camera service** to eliminate duplication
2. **Consolidate data models** for consistency
3. **Implement dependency injection** for better testability
4. **Complete placeholder features** for full functionality
5. **Break down large view files** into focused components

### Security Guidelines
- **No critical vulnerabilities identified** in latest review
- Keychain integration properly implemented
- Session management and encryption practices are secure
- Input validation and error boundaries in place
- Follow established patterns for any new security features

### Performance Notes
- RPC service instances efficiently reused for same server connections
- Proper async task cancellation handling needed in UI components
- Loading states protected against concurrent requests
