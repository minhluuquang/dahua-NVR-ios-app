import SwiftUI

struct NetworkSettingsView: View {
    var body: some View {
        List {
            ForEach(NetworkSettingsSection.allCases, id: \.self) { section in
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
        .navigationTitle("Network Settings")
        .navigationBarTitleDisplayMode(.large)
    }
    
    @ViewBuilder
    private func destinationView(for section: NetworkSettingsSection) -> some View {
        switch section {
        case .connection:
            ConnectionSettingsView()
        case .ports:
            PortConfigurationView()
        case .ipFilter:
            IPFilterView()
        case .ddns:
            DDNSSettingsView()
        }
    }
}

enum NetworkSettingsSection: CaseIterable {
    case connection
    case ports
    case ipFilter
    case ddns
    
    var title: String {
        switch self {
        case .connection: return "Connection"
        case .ports: return "Port Configuration"
        case .ipFilter: return "IP Filter"
        case .ddns: return "DDNS"
        }
    }
    
    var description: String {
        switch self {
        case .connection: return "Network connection settings"
        case .ports: return "Configure service ports"
        case .ipFilter: return "Manage IP access controls"
        case .ddns: return "Dynamic DNS configuration"
        }
    }
    
    var icon: String {
        switch self {
        case .connection: return "network"
        case .ports: return "gear"
        case .ipFilter: return "shield.fill"
        case .ddns: return "globe"
        }
    }
    
    var color: Color {
        switch self {
        case .connection: return .purple
        case .ports: return .blue
        case .ipFilter: return .red
        case .ddns: return .green
        }
    }
}

struct ConnectionSettingsView: View {
    @State private var ipAddress = "192.168.1.100"
    @State private var subnetMask = "255.255.255.0"
    @State private var gateway = "192.168.1.1"
    @State private var primaryDNS = "8.8.8.8"
    @State private var secondaryDNS = "8.8.4.4"
    @State private var dhcpEnabled = true
    
    var body: some View {
        Form {
            Section("Network Configuration") {
                Toggle("Enable DHCP", isOn: $dhcpEnabled)
                
                if !dhcpEnabled {
                    TextField("IP Address", text: $ipAddress)
                        .keyboardType(.numbersAndPunctuation)
                    
                    TextField("Subnet Mask", text: $subnetMask)
                        .keyboardType(.numbersAndPunctuation)
                    
                    TextField("Gateway", text: $gateway)
                        .keyboardType(.numbersAndPunctuation)
                }
            }
            
            Section("DNS Settings") {
                TextField("Primary DNS", text: $primaryDNS)
                    .keyboardType(.numbersAndPunctuation)
                
                TextField("Secondary DNS", text: $secondaryDNS)
                    .keyboardType(.numbersAndPunctuation)
            }
            
            Section("Network Status") {
                NetworkStatusCard()
            }
        }
        .navigationTitle("Connection Settings")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct NetworkStatusCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "wifi")
                    .foregroundColor(.green)
                
                Text("Network Status")
                    .font(.headline)
                
                Spacer()
                
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
                
                Text("Connected")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                StatusRow(title: "IP Address", value: "192.168.1.100")
                StatusRow(title: "MAC Address", value: "00:11:22:33:44:55")
                StatusRow(title: "Connection Speed", value: "100 Mbps")
                StatusRow(title: "Uptime", value: "5 days, 12 hours")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct StatusRow: View {
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

struct PortConfigurationView: View {
    @State private var webPort = 80
    @State private var httpsPort = 443
    @State private var rtspPort = 554
    @State private var tcpPort = 37777
    @State private var udpPort = 37778
    
    var body: some View {
        Form {
            Section("Service Ports") {
                PortRow(title: "Web (HTTP)", port: $webPort)
                PortRow(title: "HTTPS", port: $httpsPort)
                PortRow(title: "RTSP", port: $rtspPort)
                PortRow(title: "TCP", port: $tcpPort)
                PortRow(title: "UDP", port: $udpPort)
            }
            
            Section("Port Status") {
                PortStatusCard(service: "Web", port: webPort, isOpen: true)
                PortStatusCard(service: "HTTPS", port: httpsPort, isOpen: true)
                PortStatusCard(service: "RTSP", port: rtspPort, isOpen: false)
                PortStatusCard(service: "TCP", port: tcpPort, isOpen: true)
                PortStatusCard(service: "UDP", port: udpPort, isOpen: true)
            }
        }
        .navigationTitle("Port Configuration")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct PortRow: View {
    let title: String
    @Binding var port: Int
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            
            Spacer()
            
            TextField("Port", value: $port, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
    }
}

struct PortStatusCard: View {
    let service: String
    let port: Int
    let isOpen: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(service)
                    .font(.headline)
                
                Text("Port \(port)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Circle()
                    .fill(isOpen ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                
                Text(isOpen ? "Open" : "Closed")
                    .font(.caption)
                    .foregroundColor(isOpen ? .green : .red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct IPFilterView: View {
    @State private var filterEnabled = false
    @State private var filterType: FilterType = .whitelist
    @State private var ipRules: [IPRule] = [
        IPRule(ip: "192.168.1.0/24", type: .allow, description: "Local Network"),
        IPRule(ip: "10.0.0.100", type: .deny, description: "Blocked IP")
    ]
    @State private var showingAddRule = false
    
    var body: some View {
        List {
            Section("IP Filter Configuration") {
                Toggle("Enable IP Filter", isOn: $filterEnabled)
                
                if filterEnabled {
                    Picker("Filter Type", selection: $filterType) {
                        Text("Whitelist (Allow only listed IPs)").tag(FilterType.whitelist)
                        Text("Blacklist (Block listed IPs)").tag(FilterType.blacklist)
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }
            
            if filterEnabled {
                Section("IP Rules") {
                    ForEach(ipRules) { rule in
                        IPRuleRow(rule: rule)
                    }
                    .onDelete(perform: deleteRules)
                }
            }
        }
        .navigationTitle("IP Filter")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if filterEnabled {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        showingAddRule = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddRule) {
            AddIPRuleView(ipRules: $ipRules)
        }
    }
    
    private func deleteRules(offsets: IndexSet) {
        ipRules.remove(atOffsets: offsets)
    }
}

struct IPRule: Identifiable {
    let id = UUID()
    let ip: String
    let type: RuleType
    let description: String
}

enum FilterType: CaseIterable {
    case whitelist
    case blacklist
}

enum RuleType: CaseIterable {
    case allow
    case deny
    
    var color: Color {
        switch self {
        case .allow: return .green
        case .deny: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .allow: return "checkmark.circle.fill"
        case .deny: return "xmark.circle.fill"
        }
    }
}

struct IPRuleRow: View {
    let rule: IPRule
    
    var body: some View {
        HStack {
            Image(systemName: rule.type.icon)
                .foregroundColor(rule.type.color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(rule.ip)
                    .font(.headline)
                
                Text(rule.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(rule.type == .allow ? "Allow" : "Deny")
                .font(.caption)
                .foregroundColor(rule.type.color)
        }
        .padding(.vertical, 4)
    }
}

struct AddIPRuleView: View {
    @Binding var ipRules: [IPRule]
    @Environment(\.dismiss) private var dismiss
    @State private var ipAddress = ""
    @State private var ruleType: RuleType = .allow
    @State private var description = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Rule Information") {
                    TextField("IP Address or Range", text: $ipAddress)
                        .keyboardType(.numbersAndPunctuation)
                    
                    Picker("Action", selection: $ruleType) {
                        Text("Allow").tag(RuleType.allow)
                        Text("Deny").tag(RuleType.deny)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    TextField("Description", text: $description)
                }
            }
            .navigationTitle("Add IP Rule")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let newRule = IPRule(
                            ip: ipAddress,
                            type: ruleType,
                            description: description
                        )
                        ipRules.append(newRule)
                        dismiss()
                    }
                    .disabled(ipAddress.isEmpty)
                }
            }
        }
    }
}

struct DDNSSettingsView: View {
    @State private var ddnsEnabled = false
    @State private var ddnsProvider: DDNSProvider = .noip
    @State private var hostname = ""
    @State private var username = ""
    @State private var password = ""
    @State private var updateInterval = 300
    
    var body: some View {
        Form {
            Section("DDNS Configuration") {
                Toggle("Enable DDNS", isOn: $ddnsEnabled)
                
                if ddnsEnabled {
                    Picker("DDNS Provider", selection: $ddnsProvider) {
                        ForEach(DDNSProvider.allCases, id: \.self) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    TextField("Hostname", text: $hostname)
                        .autocapitalization(.none)
                    
                    TextField("Username", text: $username)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Update Interval (seconds)")
                            .font(.headline)
                        
                        Slider(value: Binding(
                            get: { Double(updateInterval) },
                            set: { updateInterval = Int($0) }
                        ), in: 60...3600, step: 60)
                        .accentColor(.blue)
                        
                        Text("\(updateInterval) seconds")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if ddnsEnabled {
                Section("DDNS Status") {
                    DDNSStatusCard()
                }
            }
        }
        .navigationTitle("DDNS Settings")
        .navigationBarTitleDisplayMode(.large)
    }
}

enum DDNSProvider: String, CaseIterable {
    case noip = "No-IP"
    case dyndns = "DynDNS"
    case changeip = "ChangeIP"
    case dnsexit = "DNSExit"
}

struct DDNSStatusCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(.green)
                
                Text("DDNS Status")
                    .font(.headline)
                
                Spacer()
                
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
                
                Text("Active")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                StatusRow(title: "Hostname", value: "mydahua.ddns.net")
                StatusRow(title: "External IP", value: "203.0.113.1")
                StatusRow(title: "Last Update", value: "2 minutes ago")
                StatusRow(title: "Next Update", value: "In 3 minutes")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    NavigationView {
        NetworkSettingsView()
    }
}