# Camera Status Fix: Centralized State Management Solution

## Recommended Architecture

**CameraStore** (`ObservableObject`)

---

## Implementation Plan

### Phase 1: Create CameraStore Foundation

1. **Create `CameraStore.swift`**
    - Implement as an `ObservableObject` class
    - Add `@Published var cameras: [NVRCamera]`
    - Add `@Published var isLoading: Bool` and `@Published var errorMessage: String?`
    - Move camera fetching logic from views into the store

2. **Implement Core Methods**
    - `fetchCameras()` — Centralized `getAllCameras` + `getCameraState` flow
    - `updateCamera(cameraData:)` — Handles `secSetCamera` + refresh flow
    - `refreshCameraStatus()` — Updates camera connection states

---

### Phase 2: Update View Architecture

1. **Modify `CameraTabView`**
    - Replace `@State cameras` with `@StateObject var store = CameraStore()`
    - Remove duplicate `fetchCamerasRPC()` method
    - Use `store.cameras` for UI data

2. **Update `CameraDetailsView`**
    - Remove isolated `@State private var camera`
    - Use `@EnvironmentObject var store: CameraStore`
    - Find camera from store using ID/channel for current data

3. **Modify `CameraEditSheet`**
    - Use `@EnvironmentObject var store: CameraStore`
    - Call `store.updateCamera()` instead of direct RPC
    - Remove local camera update logic

---

### Phase 3: Data Flow Integration

1. **`secSetCamera` Flow in Store**
    ```
    store.updateCamera()
      ↓
    rpcService.secSetCamera()
      ↓
    rpcService.getAllCameras() (with getCameraState)
      ↓
    update @Published cameras
      ↓
    all views automatically refresh
    ```

2. **Environment Injection**
    - Inject `CameraStore` at app root level
    - All camera views access the same store instance

---

## Benefits Delivered

- **Fixes Status Issue:** `CameraDetailsView` shows current status from centralized data
- **Eliminates Code Duplication:** Single camera fetching implementation
- **Future-Proof Architecture:** Ready for new camera features and views
- **Consistent State:** All views always show the same camera data
- **Maintainable Codebase:** Clear separation of data and UI concerns

---

## Long-term Advantages

- Easy to add camera search, filtering, grouping features
- Simple to implement real-time status updates
- Straightforward offline/caching capabilities
- Reduced bugs from state synchronization issues
- Clear testing boundaries for data vs UI logic
