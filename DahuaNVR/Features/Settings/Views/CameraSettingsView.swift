import SwiftUI

struct CameraSettingsView: View {
    var body: some View {
        List {
            ForEach(CameraSettingsSection.allCases, id: \.self) { section in
                NavigationLink(destination: destinationView(for: section)) {
                    SettingsRowView(
                        title: section.title,
                        description: section.description,
                        icon: section.icon,
                        color: section.color
                    )
                }
            }
        }
        .navigationTitle("Camera Settings")
        .navigationBarTitleDisplayMode(.large)
    }
    
    @ViewBuilder
    private func destinationView(for section: CameraSettingsSection) -> some View {
        switch section {
        case .cameraList:
            CameraListView()
        case .imageSettings:
            ImageSettingsView()
        case .encode:
            EncodeSettingsView()
        case .cameraName:
            CameraNameView()
        }
    }
}

enum CameraSettingsSection: CaseIterable {
    case cameraList
    case imageSettings
    case encode
    case cameraName
    
    var title: String {
        switch self {
        case .cameraList: return "Camera List"
        case .imageSettings: return "Image Settings"
        case .encode: return "Encode"
        case .cameraName: return "Camera Name"
        }
    }
    
    var description: String {
        switch self {
        case .cameraList: return "Manage connected cameras"
        case .imageSettings: return "Adjust image quality and appearance"
        case .encode: return "Configure video encoding settings"
        case .cameraName: return "Rename cameras"
        }
    }
    
    var icon: String {
        switch self {
        case .cameraList: return "video.fill"
        case .imageSettings: return "camera.filters"
        case .encode: return "tv.fill"
        case .cameraName: return "textformat"
        }
    }
    
    var color: Color {
        switch self {
        case .cameraList: return .blue
        case .imageSettings: return .orange
        case .encode: return .purple
        case .cameraName: return .green
        }
    }
}

struct CameraListView: View {
    @State private var cameras: [NVRCamera] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAddCamera = false
    @State private var showingSearchDevices = false
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading cameras...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    
                    Text("Error Loading Cameras")
                        .font(.headline)
                    
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Retry") {
                        Task {
                            await fetchCamerasRPC()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                List {
                    ForEach(cameras) { nvrCamera in
                        NavigationLink(destination: NVRCameraDetailView(camera: nvrCamera)) {
                            NVRCameraCardView(camera: nvrCamera)
                        }
                    }
                }
            }
        }
        .navigationTitle("Camera List")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Refresh") {
                        Task {
                            await fetchCamerasRPC()
                        }
                    }
                    Button("Add Device") {
                        showingAddCamera = true
                    }
                    Button("Search Devices") {
                        showingSearchDevices = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingAddCamera) {
            AddCameraView()
        }
        .sheet(isPresented: $showingSearchDevices) {
            SearchDevicesView()
        }
        .task {
            await fetchCamerasRPC()
        }
    }
    
    private func fetchCamerasRPC() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        guard let rpcService = AuthenticationManager.shared.rpcService,
              rpcService.hasActiveSession else {
            await MainActor.run {
                isLoading = false
                errorMessage = "No active RPC connection to NVR system."
            }
            return
        }
        
        do {
            let fetchedCameras = try await rpcService.camera.getAllCameras()
            await MainActor.run {
                cameras = fetchedCameras
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Failed to load cameras: \(error.localizedDescription)"
            }
        }
    }
    
}

struct NVRCameraCardView: View {
    let camera: NVRCamera
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "video.fill")
                    .foregroundColor(.blue)
                
                Text(camera.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                StatusIndicator(status: camera.enable ? .online : .offline)
            }
            
            HStack {
                Text("IP: \(camera.deviceInfo.address)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Port: \(camera.deviceInfo.httpPort)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Channel: \(camera.uniqueChannel)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(camera.deviceInfo.deviceType)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct NVRCameraDetailView: View {
    @State private var camera: NVRCamera
    @State private var showingEditSheet = false
    
    init(camera: NVRCamera) {
        self._camera = State(initialValue: camera)
    }
    
    var body: some View {
        Form {
            Section("Camera Information") {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(camera.name)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Status")
                    Spacer()
                    StatusIndicator(status: camera.enable ? .online : .offline)
                }
                
                HStack {
                    Text("Device ID")
                    Spacer()
                    Text(camera.deviceID)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Channel")
                    Spacer()
                    Text("\(camera.uniqueChannel)")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Device Information") {
                HStack {
                    Text("IP Address")
                    Spacer()
                    Text(camera.deviceInfo.address)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("HTTP Port")
                    Spacer()
                    Text("\(camera.deviceInfo.httpPort)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Protocol")
                    Spacer()
                    Text(camera.deviceInfo.protocolType)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Device Type")
                    Spacer()
                    Text(camera.deviceInfo.deviceType)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Serial Number")
                    Spacer()
                    Text(camera.deviceInfo.serialNo)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("MAC Address")
                    Spacer()
                    Text(camera.deviceInfo.mac)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Firmware Version")
                    Spacer()
                    Text(camera.deviceInfo.softwareVersion)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Camera Details")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            CameraEditSheet(camera: $camera)
        }
    }
}

struct CameraCardView: View {
    let camera: CameraDevice
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "video.fill")
                    .foregroundColor(.blue)
                
                Text(camera.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                StatusIndicator(status: camera.status)
            }
            
            HStack {
                Text("IP: \(camera.ipAddress)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Port: \(camera.port)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatusIndicator: View {
    let status: CameraStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
            
            Text(status.rawValue)
                .font(.caption)
                .foregroundColor(status.color)
        }
    }
}

struct CameraDevice: Identifiable {
    let id: Int
    let name: String
    let status: CameraStatus
    let ipAddress: String
    let port: Int
    
    init(id: Int, name: String, status: CameraStatus, ipAddress: String, port: Int = 80) {
        self.id = id
        self.name = name
        self.status = status
        self.ipAddress = ipAddress
        self.port = port
    }
}

enum CameraStatus: String, CaseIterable {
    case online = "Online"
    case offline = "Offline"
    case connecting = "Connecting"
    
    var color: Color {
        switch self {
        case .online: return .green
        case .offline: return .red
        case .connecting: return .orange
        }
    }
}

struct ImageSettingsView: View {
    @State private var brightness: Double = 50
    @State private var contrast: Double = 50
    @State private var saturation: Double = 50
    @State private var sharpness: Double = 50
    @State private var mirrorEnabled = false
    @State private var flipEnabled = false
    @State private var dayNightMode: DayNightMode = .auto
    
    var body: some View {
        Form {
            Section("Image Adjustment") {
                SliderRow(title: "Brightness", value: $brightness, range: 0...100)
                SliderRow(title: "Contrast", value: $contrast, range: 0...100)
                SliderRow(title: "Saturation", value: $saturation, range: 0...100)
                SliderRow(title: "Sharpness", value: $sharpness, range: 0...100)
            }
            
            Section("Image Orientation") {
                Toggle("Mirror", isOn: $mirrorEnabled)
                Toggle("Flip", isOn: $flipEnabled)
            }
            
            Section("Day/Night Mode") {
                Picker("Mode", selection: $dayNightMode) {
                    ForEach(DayNightMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
        .navigationTitle("Image Settings")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                
                Spacer()
                
                Text("\(Int(value))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Slider(value: $value, in: range)
                .accentColor(.blue)
        }
        .padding(.vertical, 4)
    }
}

enum DayNightMode: String, CaseIterable {
    case auto = "Auto"
    case color = "Color"
    case blackWhite = "B&W"
}

struct EncodeSettingsView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("Settings", selection: $selectedTab) {
                Text("Audio/Video").tag(0)
                Text("Snapshot").tag(1)
                Text("Overlay").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            TabView(selection: $selectedTab) {
                AudioVideoSettingsView()
                    .tag(0)
                
                SnapshotSettingsView()
                    .tag(1)
                
                OverlaySettingsView()
                    .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .navigationTitle("Encode Settings")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct AudioVideoSettingsView: View {
    @State private var mainStreamResolution = "1920x1080"
    @State private var mainStreamCompression = "H.264"
    @State private var mainStreamFrameRate = 30
    @State private var subStreamResolution = "704x576"
    @State private var subStreamCompression = "H.264"
    @State private var subStreamFrameRate = 15
    
    var body: some View {
        Form {
            Section("Main Stream") {
                StreamSettingsCard(
                    resolution: $mainStreamResolution,
                    compression: $mainStreamCompression,
                    frameRate: $mainStreamFrameRate
                )
            }
            
            Section("Sub Stream") {
                StreamSettingsCard(
                    resolution: $subStreamResolution,
                    compression: $subStreamCompression,
                    frameRate: $subStreamFrameRate
                )
            }
        }
    }
}

struct StreamSettingsCard: View {
    @Binding var resolution: String
    @Binding var compression: String
    @Binding var frameRate: Int
    
    let resolutionOptions = ["1920x1080", "1280x720", "704x576", "352x288"]
    let compressionOptions = ["H.264", "H.265", "MJPEG"]
    let frameRateOptions = [30, 25, 20, 15, 10, 5]
    
    var body: some View {
        VStack(spacing: 12) {
            PickerRow(title: "Resolution", selection: $resolution, options: resolutionOptions)
            PickerRow(title: "Compression", selection: $compression, options: compressionOptions)
            PickerRow(title: "Frame Rate", selection: $frameRate, options: frameRateOptions)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct PickerRow<T: Hashable>: View {
    let title: String
    @Binding var selection: T
    let options: [T]
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            
            Spacer()
            
            Menu {
                ForEach(options, id: \.self) { option in
                    Button("\(option)") {
                        selection = option
                    }
                }
            } label: {
                HStack {
                    Text("\(selection)")
                        .foregroundColor(.blue)
                    Image(systemName: "chevron.down")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
            }
        }
    }
}

struct SnapshotSettingsView: View {
    var body: some View {
        Form {
            Section("Snapshot Configuration") {
                Text("Snapshot settings will be implemented here")
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct OverlaySettingsView: View {
    var body: some View {
        Form {
            Section("Overlay Configuration") {
                Text("Overlay settings will be implemented here")
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct CameraNameView: View {
    var body: some View {
        Form {
            Section("Camera Names") {
                Text("Camera naming settings will be implemented here")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Camera Name")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct CameraDetailView: View {
    let camera: CameraDevice
    
    var body: some View {
        Form {
            Section("Camera Information") {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(camera.name)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Status")
                    Spacer()
                    StatusIndicator(status: camera.status)
                }
                
                HStack {
                    Text("IP Address")
                    Spacer()
                    Text(camera.ipAddress)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Port")
                    Spacer()
                    Text("\(camera.port)")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Actions") {
                Button("Edit Settings") {
                    // Edit camera settings
                }
                
                Button("Delete Camera") {
                    // Delete camera
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Camera Details")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct AddCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var deviceName = ""
    @State private var ipAddress = ""
    @State private var port = "80"
    
    var body: some View {
        NavigationView {
            Form {
                Section("Device Information") {
                    TextField("Device Name", text: $deviceName)
                    TextField("IP Address", text: $ipAddress)
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Add Camera")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        dismiss()
                    }
                    .disabled(deviceName.isEmpty || ipAddress.isEmpty)
                }
            }
        }
    }
}

struct SearchDevicesView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Search for Devices")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Device search functionality will be implemented here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
            }
            .navigationTitle("Search Devices")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        CameraSettingsView()
    }
}