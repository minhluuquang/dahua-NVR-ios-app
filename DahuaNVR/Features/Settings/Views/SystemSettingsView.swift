import SwiftUI

struct SystemSettingsView: View {
    var body: some View {
        List {
            ForEach(SystemSettingsSection.allCases, id: \.self) { section in
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
        .navigationTitle("System Settings")
        .navigationBarTitleDisplayMode(.large)
    }
    
    @ViewBuilder
    private func destinationView(for section: SystemSettingsSection) -> some View {
        switch section {
        case .general:
            GeneralSystemView()
        case .dateTime:
            DateTimeView()
        case .maintenance:
            MaintenanceView()
        case .logs:
            LogsView()
        case .backup:
            BackupView()
        }
    }
}

enum SystemSettingsSection: CaseIterable {
    case general
    case dateTime
    case maintenance
    case logs
    case backup
    
    var title: String {
        switch self {
        case .general: return "General"
        case .dateTime: return "Date & Time"
        case .maintenance: return "Maintenance"
        case .logs: return "System Logs"
        case .backup: return "Backup & Restore"
        }
    }
    
    var description: String {
        switch self {
        case .general: return "System information and basic settings"
        case .dateTime: return "Configure date, time, and timezone"
        case .maintenance: return "System maintenance and updates"
        case .logs: return "View system and error logs"
        case .backup: return "Backup and restore configurations"
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .dateTime: return "clock.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        case .logs: return "doc.text.fill"
        case .backup: return "externaldrive.badge.icloud"
        }
    }
    
    var color: Color {
        switch self {
        case .general: return .gray
        case .dateTime: return .blue
        case .maintenance: return .orange
        case .logs: return .purple
        case .backup: return .green
        }
    }
}

struct GeneralSystemView: View {
    @State private var deviceName = "Dahua NVR System"
    @State private var deviceID = "NVR-001"
    @State private var language: SystemLanguage = .english
    @State private var autoReboot = false
    @State private var rebootTime = Date()
    
    var body: some View {
        Form {
            Section("Device Information") {
                TextField("Device Name", text: $deviceName)
                
                HStack {
                    Text("Device ID")
                    Spacer()
                    Text(deviceID)
                        .foregroundColor(.secondary)
                }
                
                Picker("Language", selection: $language) {
                    ForEach(SystemLanguage.allCases, id: \.self) { lang in
                        Text(lang.rawValue).tag(lang)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            Section("System Information") {
                SystemInfoCard()
            }
            
            Section("Auto Reboot") {
                Toggle("Enable Auto Reboot", isOn: $autoReboot)
                
                if autoReboot {
                    DatePicker("Reboot Time", selection: $rebootTime, displayedComponents: .hourAndMinute)
                }
            }
        }
        .navigationTitle("General Settings")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct SystemInfoCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                
                Text("System Information")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(title: "Firmware Version", value: "4.001.0000008.0")
                InfoRow(title: "Build Date", value: "2024-01-15")
                InfoRow(title: "Hardware Version", value: "1.0")
                InfoRow(title: "Serial Number", value: "DH001234567890")
                InfoRow(title: "MAC Address", value: "00:11:22:33:44:55")
                InfoRow(title: "Uptime", value: "15 days, 8 hours")
                InfoRow(title: "CPU Usage", value: "25%")
                InfoRow(title: "Memory Usage", value: "512MB / 2GB")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
}

enum SystemLanguage: String, CaseIterable {
    case english = "English"
    case chinese = "中文"
    case spanish = "Español"
    case french = "Français"
    case german = "Deutsch"
}

struct DateTimeView: View {
    @State private var currentDate = Date()
    @State private var timezone: SystemTimezone = .utc
    @State private var ntpEnabled = true
    @State private var ntpServer = "pool.ntp.org"
    @State private var dateFormat: DateFormat = .mmddyyyy
    @State private var timeFormat: TimeFormat = .hour24
    
    var body: some View {
        Form {
            Section("Current Date & Time") {
                DateTimeCard(date: currentDate)
            }
            
            Section("Time Configuration") {
                Picker("Timezone", selection: $timezone) {
                    ForEach(SystemTimezone.allCases, id: \.self) { tz in
                        Text(tz.rawValue).tag(tz)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Toggle("Enable NTP", isOn: $ntpEnabled)
                
                if ntpEnabled {
                    TextField("NTP Server", text: $ntpServer)
                        .autocapitalization(.none)
                } else {
                    DatePicker("Set Date & Time", selection: $currentDate)
                }
            }
            
            Section("Display Format") {
                Picker("Date Format", selection: $dateFormat) {
                    ForEach(DateFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                Picker("Time Format", selection: $timeFormat) {
                    ForEach(TimeFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
        .navigationTitle("Date & Time")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct DateTimeCard: View {
    let date: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.blue)
                
                Text("Current Date & Time")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(date, style: .date)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(date, style: .time)
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

enum SystemTimezone: String, CaseIterable {
    case utc = "UTC"
    case est = "EST (UTC-5)"
    case pst = "PST (UTC-8)"
    case cst = "CST (UTC+8)"
    case gmt = "GMT (UTC+0)"
}

enum DateFormat: String, CaseIterable {
    case mmddyyyy = "MM/DD/YYYY"
    case ddmmyyyy = "DD/MM/YYYY"
    case yyyymmdd = "YYYY/MM/DD"
}

enum TimeFormat: String, CaseIterable {
    case hour12 = "12 Hour"
    case hour24 = "24 Hour"
}

struct MaintenanceView: View {
    @State private var showingRebootAlert = false
    @State private var showingFactoryResetAlert = false
    @State private var showingUpdateAlert = false
    
    var body: some View {
        List {
            Section("System Maintenance") {
                Button("Reboot System") {
                    showingRebootAlert = true
                }
                .foregroundColor(.orange)
                
                Button("Factory Reset") {
                    showingFactoryResetAlert = true
                }
                .foregroundColor(.red)
                
                Button("Check for Updates") {
                    showingUpdateAlert = true
                }
                .foregroundColor(.blue)
            }
            
            Section("System Status") {
                SystemStatusCard()
            }
            
            Section("Maintenance History") {
                MaintenanceHistoryCard()
            }
        }
        .navigationTitle("Maintenance")
        .navigationBarTitleDisplayMode(.large)
        .alert("Reboot System", isPresented: $showingRebootAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reboot", role: .destructive) {
                // Perform reboot
            }
        } message: {
            Text("Are you sure you want to reboot the system? This will temporarily interrupt all services.")
        }
        .alert("Factory Reset", isPresented: $showingFactoryResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                // Perform factory reset
            }
        } message: {
            Text("This will erase all settings and data. This action cannot be undone.")
        }
        .alert("System Updates", isPresented: $showingUpdateAlert) {
            Button("OK") { }
        } message: {
            Text("System is up to date. No updates available.")
        }
    }
}

struct SystemStatusCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.green)
                
                Text("System Health")
                    .font(.headline)
                
                Spacer()
                
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
                
                Text("Healthy")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                StatusRow(title: "CPU Temperature", value: "45°C")
                StatusRow(title: "Fan Speed", value: "2400 RPM")
                StatusRow(title: "Power Status", value: "Normal")
                StatusRow(title: "Storage Health", value: "Good")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct MaintenanceHistoryCard: View {
    let maintenanceHistory = [
        MaintenanceRecord(date: "2024-01-15", action: "System Reboot", status: "Success"),
        MaintenanceRecord(date: "2024-01-10", action: "Firmware Update", status: "Success"),
        MaintenanceRecord(date: "2024-01-05", action: "Configuration Backup", status: "Success")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(maintenanceHistory, id: \.date) { record in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.action)
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text(record.date)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(record.status)
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct MaintenanceRecord {
    let date: String
    let action: String
    let status: String
}

struct LogsView: View {
    @State private var selectedLogType: LogType = .system
    @State private var logs: [LogEntry] = [
        LogEntry(timestamp: "2024-01-15 14:30:25", level: .info, message: "System started successfully"),
        LogEntry(timestamp: "2024-01-15 14:28:10", level: .warning, message: "Camera 2 connection timeout"),
        LogEntry(timestamp: "2024-01-15 14:25:03", level: .error, message: "Failed to connect to NTP server"),
        LogEntry(timestamp: "2024-01-15 14:20:15", level: .info, message: "User admin logged in"),
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("Log Type", selection: $selectedLogType) {
                ForEach(LogType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            List(logs) { log in
                LogEntryRow(log: log)
            }
        }
        .navigationTitle("System Logs")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Clear") {
                    logs.removeAll()
                }
            }
        }
    }
}

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: String
    let level: LogLevel
    let message: String
}

enum LogType: String, CaseIterable {
    case system = "System"
    case security = "Security"
    case network = "Network"
    case camera = "Camera"
}

enum LogLevel: String, CaseIterable {
    case info = "Info"
    case warning = "Warning"
    case error = "Error"
    
    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}

struct LogEntryRow: View {
    let log: LogEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(log.timestamp)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(log.level.rawValue)
                    .font(.caption)
                    .foregroundColor(log.level.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(log.level.color.opacity(0.1))
                    .cornerRadius(4)
            }
            
            Text(log.message)
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}

struct BackupView: View {
    @State private var autoBackupEnabled = true
    @State private var backupInterval: BackupInterval = .daily
    @State private var backupLocation = "Internal Storage"
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    
    var body: some View {
        Form {
            Section("Backup Configuration") {
                Toggle("Enable Auto Backup", isOn: $autoBackupEnabled)
                
                if autoBackupEnabled {
                    Picker("Backup Interval", selection: $backupInterval) {
                        ForEach(BackupInterval.allCases, id: \.self) { interval in
                            Text(interval.rawValue).tag(interval)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    HStack {
                        Text("Backup Location")
                        Spacer()
                        Text(backupLocation)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Manual Backup") {
                Button("Export Configuration") {
                    showingExportSheet = true
                }
                .foregroundColor(.blue)
                
                Button("Import Configuration") {
                    showingImportSheet = true
                }
                .foregroundColor(.green)
            }
            
            Section("Backup History") {
                BackupHistoryCard()
            }
        }
        .navigationTitle("Backup & Restore")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingExportSheet) {
            ExportConfigurationView()
        }
        .sheet(isPresented: $showingImportSheet) {
            ImportConfigurationView()
        }
    }
}

enum BackupInterval: String, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
}

struct BackupHistoryCard: View {
    let backupHistory = [
        BackupRecord(date: "2024-01-15", type: "Auto", size: "2.5 MB", status: "Success"),
        BackupRecord(date: "2024-01-14", type: "Manual", size: "2.4 MB", status: "Success"),
        BackupRecord(date: "2024-01-13", type: "Auto", size: "2.3 MB", status: "Failed")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(backupHistory, id: \.date) { record in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(record.type) Backup")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text(record.date)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(record.size)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(record.status)
                            .font(.caption)
                            .foregroundColor(record.status == "Success" ? .green : .red)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct BackupRecord {
    let date: String
    let type: String
    let size: String
    let status: String
}

struct ExportConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Export Configuration")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Export system configuration to a backup file")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
            }
            .navigationTitle("Export")
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

struct ImportConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text("Import Configuration")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Import system configuration from a backup file")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
            }
            .navigationTitle("Import")
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
        SystemSettingsView()
    }
}