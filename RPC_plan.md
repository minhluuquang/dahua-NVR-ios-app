# RPC-Only Architecture Migration Plan

## Executive Summary

Transition from dual authentication (HTTP CGI + RPC) to an RPC-only architecture by systematically removing HTTP CGI code, while maintaining all existing functionality.

---

## Migration Strategy Overview

| Current State           | Target State      |
|------------------------|-------------------|
| DualProtocolService    | RPCService        |
| - HTTP CGI             | - RPC Only        |
| - RPC                  |                   |

---

## Phase-by-Phase Implementation

### Phase 1: RPC Feature Parity Assessment & Enhancement

**Objective:** Ensure RPC modules provide 100% feature coverage for current HTTP CGI operations.

- **Audit Current HTTP CGI Functionality**
    - Analyze `CameraAPIService` for all HTTP CGI endpoints.
    - Document camera management operations (e.g., `getCameras`, camera settings).
    - Identify unique HTTP CGI capabilities not yet in RPC.

- **Enhance RPC Modules**
    - Add missing RPC methods to match HTTP CGI functionality.
    - Extend `CameraRPC` for camera management as needed.
    - Ensure `ConfigManagerRPC` and `SystemRPC` cover all use cases.
    - Add comprehensive error handling matching HTTP CGI behavior.

- **Create RPC-HTTP Compatibility Layer**
    - Build adapter methods with the same interfaces as HTTP CGI.
    - Ensure UI components can switch seamlessly.
    - Maintain consistent data structures and return types.

**Success Criteria:** RPC modules can perform every operation currently done via HTTP CGI.

---

### Phase 2: Service Architecture Transition

**Objective:** Replace `DualProtocolService` with an RPC-only authentication service.

- **Create Unified RPCAuthenticationService**
    - Replace `DualProtocolService` with a single RPC authentication flow.
    - Maintain interface contracts for dependent components.
    - Implement session management and keep-alive.
    - Add detailed logging for development and debugging.

- **Update NVRManager & AuthenticationManager**
    - Remove dual authentication status tracking.
    - Simplify authentication state models (remove HTTP CGI references).
    - Update `NVRSystem` model to track only RPC authentication status.
    - Maintain compatibility with existing keychain storage.

- **Authentication Flow Integration**
    - Ensure seamless integration with existing login flow.
    - Update `ContentViewModel` and `LoginViewModel` to use RPC-only service.
    - Maintain user experience and error handling.
    - Preserve credential management and session persistence.

**Dependencies:** Phase 1 RPC modules must be feature-complete.  
**Risk Mitigation:** Maintain interface compatibility to minimize UI component changes.

---

### Phase 3: UI Component Migration

**Objective:** Update all UI components to use RPC-only services.

- **Update Core UI Components**
    - `CameraTabView`: Switch from HTTP CGI to RPC `CameraModule`.
    - `CameraSettingsView`: Use RPC `ConfigManagerRPC` for configuration.
    - `MainAppView`: Remove dual authentication status displays.
    - Update all camera-related UI to use RPC service interfaces.

- **Settings & Configuration Views**
    - Remove HTTP CGI references in all settings views.
    - Update `CameraEditSheet` to use RPC for camera management.
    - Ensure all configuration changes use RPC `ConfigManagerRPC`.
    - Maintain user experience and functionality.

- **Error Handling & User Feedback**
    - Update error messages for RPC-only operations.
    - Ensure proper error propagation from RPC services.
    - Maintain informative user feedback for connection/authentication issues.
    - Update loading states and progress indicators.

**Dependencies:** Phase 2 authentication service must be stable and Phase 1 RPC modules complete.  
**Validation:** Each UI component must pass functional tests with RPC backend.

---

### Phase 4: Cleanup & Architecture Finalization

**Objective:** Remove all HTTP CGI code and finalize RPC-only architecture.

- **HTTP CGI Code Removal**
    - Delete `CameraAPIService` (HTTP CGI camera operations).
    - Remove `DahuaNVRAuthService` (legacy HTTP CGI authentication).
    - Remove all HTTP CGI related imports and dependencies.
    - Clean up HTTP CGI utility functions and helpers.

- **Model & Data Structure Cleanup**
    - Remove dual authentication fields from `NVRSystem` model.
    - Simplify `AuthenticationState` to track only RPC status.
    - Update `PersistedAuthData` for RPC-only credentials if needed.
    - Remove HTTP CGI specific error types and enums.

- **Documentation & Architecture Updates**
    - Update `CLAUDE.md` to reflect RPC-only architecture.
    - Remove references to dual protocol implementation.
    - Update developer usage guide with RPC-only examples.
    - Document simplified authentication flow.
    - Update build commands and testing instructions as needed.

**Validation:** System must function with zero HTTP CGI dependencies.

---

## Implementation Strategy & First Steps

### Dependency Flow

```
Phase 1 (Foundation)
        |
        v
Phase 2 (Core Services)
        |
        v
Phase 3 (UI Integration)
        |
        v
Phase 4 (Cleanup)
```

### Immediate Action Items (Priority Order)

1. **Code Audit (Critical)**
     - Analyze current HTTP CGI usage:
         - `grep -r "CameraAPIService" DahuaNVR/`
         - `grep -r "DahuaNVRAuthService" DahuaNVR/`
         - `grep -r "httpCGI" DahuaNVR/`
2. **RPC Capability Assessment (Critical)**
     - Review existing RPC modules (`CameraRPC`, `ConfigManagerRPC`, `SystemRPC`).
     - Identify gaps compared to HTTP CGI functionality.
     - Document missing RPC methods needed.
3. **Testing Strategy Setup (High)**
     - Ensure `RPCTests` covers all functionality replacing HTTP CGI.
     - Set up testing infrastructure for incremental validation.
     - Create rollback plan in case issues arise.

---

## Success Metrics

- Zero HTTP CGI code references remaining.
- All tests passing with RPC-only implementation.
- Performance equal or better than dual protocol system.
- Complete feature parity with previous HTTP CGI capabilities.

---

## Risk Mitigation

Each phase includes validation checkpoints and rollback capability if critical issues are discovered.

