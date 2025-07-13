# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
This is a SwiftUI-based iOS application for Dahua NVR (Network Video Recorder) management. The project is a standard iOS app created with Xcode 16+ using the modern Swift Testing framework.

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
  - `DahuaNVRApp.swift`: Main app entry point with `@main` attribute
  - `ContentView.swift`: Primary SwiftUI view (currently a basic "Hello, world!" placeholder)
  - `Assets.xcassets/`: App icons and visual assets
- **DahuaNVRTests/**: Unit tests using Swift Testing framework
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
- The app is currently in its initial state with basic SwiftUI template code
- Three main targets: DahuaNVR (app), DahuaNVRTests (unit tests), DahuaNVRUITests (UI tests)