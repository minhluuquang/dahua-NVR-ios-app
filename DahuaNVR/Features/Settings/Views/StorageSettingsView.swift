import SwiftUI

struct StorageSettingsView: View {
    var body: some View {
        List {
            ForEach(StorageSettingsSection.allCases, id: \.self) { section in
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
        .navigationTitle("Storage Settings")
        .navigationBarTitleDisplayMode(.large)
    }
    
    @ViewBuilder
    private func destinationView(for section: StorageSettingsSection) -> some View {
        switch section {
        case .diskManager:
            DiskManagerView()
        case .schedule:
            ScheduleView()
        case .quota:
            QuotaView()
        }
    }
}

enum StorageSettingsSection: CaseIterable {
    case diskManager
    case schedule
    case quota
    
    var title: String {
        switch self {
        case .diskManager: return "Disk Manager"
        case .schedule: return "Schedule"
        case .quota: return "Quota"
        }
    }
    
    var description: String {
        switch self {
        case .diskManager: return "Manage storage devices and settings"
        case .schedule: return "Configure recording schedules"
        case .quota: return "Set storage quotas and limits"
        }
    }
    
    var icon: String {
        switch self {
        case .diskManager: return "externaldrive.fill"
        case .schedule: return "calendar"
        case .quota: return "chart.pie.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .diskManager: return .orange
        case .schedule: return .blue
        case .quota: return .purple
        }
    }
}

struct DiskManagerView: View {
    @State private var overwriteEnabled = true
    @State private var timeLengthDays = 30
    @State private var deleteExpiredFiles: DeleteExpiredOption = .auto
    
    var body: some View {
        Form {
            Section("Storage Configuration") {
                Toggle("Overwrite when disk is full", isOn: $overwriteEnabled)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Time Length (days)")
                            .font(.headline)
                        
                        Spacer()
                        
                        HStack {
                            Button("-") {
                                if timeLengthDays > 1 {
                                    timeLengthDays -= 1
                                }
                            }
                            .foregroundColor(.blue)
                            
                            Text("\(timeLengthDays)")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .frame(minWidth: 40)
                            
                            Button("+") {
                                if timeLengthDays < 365 {
                                    timeLengthDays += 1
                                }
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    
                    Text("How long to keep recordings before deletion")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Delete Expired Files")
                        .font(.headline)
                    
                    Picker("Delete Expired Files", selection: $deleteExpiredFiles) {
                        ForEach(DeleteExpiredOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding(.vertical, 4)
            }
            
            Section("Disk Information") {
                DiskInfoCard(
                    name: "Main Storage",
                    totalSpace: "2TB",
                    usedSpace: "1.2TB",
                    freeSpace: "800GB",
                    usagePercentage: 0.6
                )
                
                DiskInfoCard(
                    name: "Backup Storage",
                    totalSpace: "1TB",
                    usedSpace: "300GB",
                    freeSpace: "700GB",
                    usagePercentage: 0.3
                )
            }
        }
        .navigationTitle("Disk Manager")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct DiskInfoCard: View {
    let name: String
    let totalSpace: String
    let usedSpace: String
    let freeSpace: String
    let usagePercentage: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "externaldrive.fill")
                    .foregroundColor(.orange)
                
                Text(name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(Int(usagePercentage * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Total: \(totalSpace)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Free: \(freeSpace)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: usagePercentage)
                    .progressViewStyle(LinearProgressViewStyle())
                    .accentColor(usagePercentage > 0.8 ? .red : .blue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

enum DeleteExpiredOption: String, CaseIterable {
    case auto = "Auto"
    case manual = "Manual"
    case never = "Never"
}

struct ScheduleView: View {
    @State private var selectedDay = 0
    @State private var scheduleMatrix = Array(repeating: Array(repeating: false, count: 24), count: 7)
    
    let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("Day", selection: $selectedDay) {
                ForEach(0..<days.count, id: \.self) { index in
                    Text(days[index]).tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                    ForEach(0..<24, id: \.self) { hour in
                        ScheduleHourButton(
                            hour: hour,
                            isSelected: scheduleMatrix[selectedDay][hour]
                        ) {
                            scheduleMatrix[selectedDay][hour].toggle()
                        }
                    }
                }
                .padding()
            }
            
            HStack {
                Button("Select All") {
                    for hour in 0..<24 {
                        scheduleMatrix[selectedDay][hour] = true
                    }
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Clear All") {
                    for hour in 0..<24 {
                        scheduleMatrix[selectedDay][hour] = false
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .navigationTitle("Recording Schedule")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct ScheduleHourButton: View {
    let hour: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(String(format: "%02d:00", hour))
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(String(format: "%02d:59", hour))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct QuotaView: View {
    @State private var totalQuota = 1000.0
    @State private var cameraQuotas: [CameraQuota] = [
        CameraQuota(name: "Front Door", quota: 300, used: 180),
        CameraQuota(name: "Back Yard", quota: 250, used: 120),
        CameraQuota(name: "Garage", quota: 200, used: 80)
    ]
    
    var body: some View {
        Form {
            Section("Total Quota") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Total Storage Quota (GB)")
                            .font(.headline)
                        
                        Spacer()
                        
                        Text(String(format: "%.0f GB", totalQuota))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $totalQuota, in: 100...5000, step: 50)
                        .accentColor(.blue)
                }
                .padding(.vertical, 4)
            }
            
            Section("Camera Quotas") {
                ForEach(cameraQuotas.indices, id: \.self) { index in
                    CameraQuotaRow(quota: $cameraQuotas[index])
                }
            }
            
            Section("Quota Summary") {
                HStack {
                    Text("Allocated")
                    Spacer()
                    Text("\(Int(cameraQuotas.reduce(0) { $0 + $1.quota })) GB")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Used")
                    Spacer()
                    Text("\(Int(cameraQuotas.reduce(0) { $0 + $1.used })) GB")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Available")
                    Spacer()
                    let available = totalQuota - cameraQuotas.reduce(0) { $0 + $1.quota }
                    Text("\(Int(available)) GB")
                        .foregroundColor(available < 0 ? .red : .green)
                }
            }
        }
        .navigationTitle("Storage Quota")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct CameraQuota {
    let name: String
    var quota: Double
    var used: Double
}

struct CameraQuotaRow: View {
    @Binding var quota: CameraQuota
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "video.fill")
                    .foregroundColor(.blue)
                
                Text(quota.name)
                    .font(.headline)
                
                Spacer()
                
                Text("\(Int(quota.quota)) GB")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Used: \(Int(quota.used)) GB")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Free: \(Int(quota.quota - quota.used)) GB")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: quota.used / quota.quota)
                    .progressViewStyle(LinearProgressViewStyle())
                    .accentColor(quota.used / quota.quota > 0.8 ? .red : .blue)
            }
            
            Slider(value: $quota.quota, in: 50...1000, step: 10)
                .accentColor(.blue)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        StorageSettingsView()
    }
}