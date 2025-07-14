import SwiftUI

struct AccountSettingsView: View {
    var body: some View {
        List {
            ForEach(AccountSettingsSection.allCases, id: \.self) { section in
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
        .navigationTitle("Account Settings")
        .navigationBarTitleDisplayMode(.large)
    }
    
    @ViewBuilder
    private func destinationView(for section: AccountSettingsSection) -> some View {
        switch section {
        case .users:
            UserManagementView()
        case .groups:
            GroupManagementView()
        case .permissions:
            PermissionsView()
        case .security:
            SecuritySettingsView()
        }
    }
}

enum AccountSettingsSection: CaseIterable {
    case users
    case groups
    case permissions
    case security
    
    var title: String {
        switch self {
        case .users: return "User Management"
        case .groups: return "Group Management"
        case .permissions: return "Permissions"
        case .security: return "Security Settings"
        }
    }
    
    var description: String {
        switch self {
        case .users: return "Manage user accounts and profiles"
        case .groups: return "Configure user groups and roles"
        case .permissions: return "Set access permissions and restrictions"
        case .security: return "Password policies and security settings"
        }
    }
    
    var icon: String {
        switch self {
        case .users: return "person.circle.fill"
        case .groups: return "person.3.fill"
        case .permissions: return "key.fill"
        case .security: return "shield.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .users: return .green
        case .groups: return .blue
        case .permissions: return .orange
        case .security: return .red
        }
    }
}

struct UserManagementView: View {
    @State private var users: [User] = [
        User(username: "admin", role: .administrator, isActive: true, lastLogin: "2024-01-15 14:30"),
        User(username: "operator", role: .operator, isActive: true, lastLogin: "2024-01-15 10:15"),
        User(username: "viewer", role: .viewer, isActive: false, lastLogin: "2024-01-10 16:45")
    ]
    @State private var showingAddUser = false
    
    var body: some View {
        List {
            ForEach(users) { user in
                NavigationLink(destination: UserDetailView(user: user)) {
                    UserRowView(user: user)
                }
            }
            .onDelete(perform: deleteUsers)
        }
        .navigationTitle("User Management")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add User") {
                    showingAddUser = true
                }
            }
        }
        .sheet(isPresented: $showingAddUser) {
            AddUserView(users: $users)
        }
    }
    
    private func deleteUsers(offsets: IndexSet) {
        users.remove(atOffsets: offsets)
    }
}

struct User: Identifiable {
    let id = UUID()
    let username: String
    let role: UserRole
    let isActive: Bool
    let lastLogin: String
}

enum UserRole: String, CaseIterable {
    case administrator = "Administrator"
    case `operator` = "Operator"
    case viewer = "Viewer"
    
    var color: Color {
        switch self {
        case .administrator: return .red
        case .`operator`: return .orange
        case .viewer: return .green
        }
    }
    
    var icon: String {
        switch self {
        case .administrator: return "crown.fill"
        case .`operator`: return "wrench.fill"
        case .viewer: return "eye.fill"
        }
    }
}

struct UserRowView: View {
    let user: User
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: user.role.icon)
                        .foregroundColor(user.role.color)
                    
                    Text(user.username)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Text(user.role.rawValue)
                    .font(.caption)
                    .foregroundColor(user.role.color)
                
                Text("Last login: \(user.lastLogin)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Circle()
                    .fill(user.isActive ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                
                Text(user.isActive ? "Active" : "Inactive")
                    .font(.caption)
                    .foregroundColor(user.isActive ? .green : .red)
            }
        }
        .padding(.vertical, 4)
    }
}

struct UserDetailView: View {
    let user: User
    @State private var isActive = true
    @State private var selectedRole: UserRole = .viewer
    @State private var showingPasswordReset = false
    
    var body: some View {
        Form {
            Section("User Information") {
                HStack {
                    Text("Username")
                    Spacer()
                    Text(user.username)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Status")
                    Spacer()
                    Toggle("", isOn: $isActive)
                }
                
                Picker("Role", selection: $selectedRole) {
                    ForEach(UserRole.allCases, id: \.self) { role in
                        Text(role.rawValue).tag(role)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                HStack {
                    Text("Last Login")
                    Spacer()
                    Text(user.lastLogin)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Security") {
                Button("Reset Password") {
                    showingPasswordReset = true
                }
                .foregroundColor(.orange)
                
                Button("Force Logout") {
                    // Force logout user
                }
                .foregroundColor(.red)
            }
            
            Section("Permissions") {
                UserPermissionsCard(role: selectedRole)
            }
        }
        .navigationTitle("User Details")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            isActive = user.isActive
            selectedRole = user.role
        }
        .alert("Reset Password", isPresented: $showingPasswordReset) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                // Reset password
            }
        } message: {
            Text("This will generate a new temporary password for the user.")
        }
    }
}

struct UserPermissionsCard: View {
    let role: UserRole
    
    var permissions: [Permission] {
        switch role {
        case .administrator:
            return [
                Permission(name: "System Configuration", granted: true),
                Permission(name: "User Management", granted: true),
                Permission(name: "Camera Control", granted: true),
                Permission(name: "Playback", granted: true),
                Permission(name: "Export", granted: true)
            ]
        case .`operator`:
            return [
                Permission(name: "System Configuration", granted: false),
                Permission(name: "User Management", granted: false),
                Permission(name: "Camera Control", granted: true),
                Permission(name: "Playback", granted: true),
                Permission(name: "Export", granted: true)
            ]
        case .viewer:
            return [
                Permission(name: "System Configuration", granted: false),
                Permission(name: "User Management", granted: false),
                Permission(name: "Camera Control", granted: false),
                Permission(name: "Playback", granted: true),
                Permission(name: "Export", granted: false)
            ]
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Role Permissions")
                .font(.headline)
                .foregroundColor(.primary)
            
            ForEach(permissions, id: \.name) { permission in
                HStack {
                    Image(systemName: permission.granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(permission.granted ? .green : .red)
                    
                    Text(permission.name)
                        .font(.caption)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct Permission {
    let name: String
    let granted: Bool
}

struct AddUserView: View {
    @Binding var users: [User]
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var selectedRole: UserRole = .viewer
    @State private var isActive = true
    
    var body: some View {
        NavigationView {
            Form {
                Section("User Information") {
                    TextField("Username", text: $username)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                    
                    SecureField("Confirm Password", text: $confirmPassword)
                    
                    Picker("Role", selection: $selectedRole) {
                        ForEach(UserRole.allCases, id: \.self) { role in
                            Text(role.rawValue).tag(role)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Toggle("Active", isOn: $isActive)
                }
                
                Section("Role Permissions") {
                    UserPermissionsCard(role: selectedRole)
                }
            }
            .navigationTitle("Add User")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let newUser = User(
                            username: username,
                            role: selectedRole,
                            isActive: isActive,
                            lastLogin: "Never"
                        )
                        users.append(newUser)
                        dismiss()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !username.isEmpty && !password.isEmpty && password == confirmPassword
    }
}

struct GroupManagementView: View {
    @State private var groups: [UserGroup] = [
        UserGroup(name: "Administrators", memberCount: 2, permissions: ["All"]),
        UserGroup(name: "Operators", memberCount: 5, permissions: ["Camera Control", "Playback"]),
        UserGroup(name: "Viewers", memberCount: 10, permissions: ["Playback"])
    ]
    @State private var showingAddGroup = false
    
    var body: some View {
        List {
            ForEach(groups) { group in
                NavigationLink(destination: GroupDetailView(group: group)) {
                    GroupRowView(group: group)
                }
            }
            .onDelete(perform: deleteGroups)
        }
        .navigationTitle("Group Management")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add Group") {
                    showingAddGroup = true
                }
            }
        }
        .sheet(isPresented: $showingAddGroup) {
            AddGroupView(groups: $groups)
        }
    }
    
    private func deleteGroups(offsets: IndexSet) {
        groups.remove(atOffsets: offsets)
    }
}

struct UserGroup: Identifiable {
    let id = UUID()
    let name: String
    let memberCount: Int
    let permissions: [String]
}

struct GroupRowView: View {
    let group: UserGroup
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "person.3.fill")
                    .foregroundColor(.blue)
                
                Text(group.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(group.memberCount) members")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(group.permissions.joined(separator: ", "))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

struct GroupDetailView: View {
    let group: UserGroup
    
    var body: some View {
        Form {
            Section("Group Information") {
                HStack {
                    Text("Group Name")
                    Spacer()
                    Text(group.name)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Members")
                    Spacer()
                    Text("\(group.memberCount)")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Permissions") {
                ForEach(group.permissions, id: \.self) { permission in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        
                        Text(permission)
                            .font(.body)
                    }
                }
            }
        }
        .navigationTitle("Group Details")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct AddGroupView: View {
    @Binding var groups: [UserGroup]
    @Environment(\.dismiss) private var dismiss
    @State private var groupName = ""
    @State private var selectedPermissions: Set<String> = []
    
    let availablePermissions = [
        "System Configuration",
        "User Management",
        "Camera Control",
        "Playback",
        "Export",
        "Network Settings",
        "Storage Management"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Group Information") {
                    TextField("Group Name", text: $groupName)
                }
                
                Section("Permissions") {
                    ForEach(availablePermissions, id: \.self) { permission in
                        HStack {
                            Button(action: {
                                if selectedPermissions.contains(permission) {
                                    selectedPermissions.remove(permission)
                                } else {
                                    selectedPermissions.insert(permission)
                                }
                            }) {
                                Image(systemName: selectedPermissions.contains(permission) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedPermissions.contains(permission) ? .green : .gray)
                            }
                            
                            Text(permission)
                                .font(.body)
                            
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Add Group")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let newGroup = UserGroup(
                            name: groupName,
                            memberCount: 0,
                            permissions: Array(selectedPermissions)
                        )
                        groups.append(newGroup)
                        dismiss()
                    }
                    .disabled(groupName.isEmpty)
                }
            }
        }
    }
}

struct PermissionsView: View {
    var body: some View {
        Form {
            Section("Permission Overview") {
                Text("Permissions matrix and detailed access control settings will be implemented here")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Permissions")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct SecuritySettingsView: View {
    @State private var passwordMinLength = 8
    @State private var requireNumbers = true
    @State private var requireSpecialChars = true
    @State private var requireUppercase = true
    @State private var passwordExpiration = 90
    @State private var maxLoginAttempts = 5
    @State private var lockoutDuration = 15
    @State private var sessionTimeout = 30
    @State private var enableTwoFactor = false
    
    var body: some View {
        Form {
            Section("Password Policy") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Minimum Length")
                        .font(.headline)
                    
                    Slider(value: Binding(
                        get: { Double(passwordMinLength) },
                        set: { passwordMinLength = Int($0) }
                    ), in: 6...20, step: 1)
                    .accentColor(.blue)
                    
                    Text("\(passwordMinLength) characters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Toggle("Require Numbers", isOn: $requireNumbers)
                Toggle("Require Special Characters", isOn: $requireSpecialChars)
                Toggle("Require Uppercase Letters", isOn: $requireUppercase)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password Expiration (days)")
                        .font(.headline)
                    
                    Slider(value: Binding(
                        get: { Double(passwordExpiration) },
                        set: { passwordExpiration = Int($0) }
                    ), in: 30...365, step: 30)
                    .accentColor(.blue)
                    
                    Text("\(passwordExpiration) days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Login Security") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Max Login Attempts")
                        .font(.headline)
                    
                    Slider(value: Binding(
                        get: { Double(maxLoginAttempts) },
                        set: { maxLoginAttempts = Int($0) }
                    ), in: 3...10, step: 1)
                    .accentColor(.blue)
                    
                    Text("\(maxLoginAttempts) attempts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Lockout Duration (minutes)")
                        .font(.headline)
                    
                    Slider(value: Binding(
                        get: { Double(lockoutDuration) },
                        set: { lockoutDuration = Int($0) }
                    ), in: 5...60, step: 5)
                    .accentColor(.blue)
                    
                    Text("\(lockoutDuration) minutes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Session Timeout (minutes)")
                        .font(.headline)
                    
                    Slider(value: Binding(
                        get: { Double(sessionTimeout) },
                        set: { sessionTimeout = Int($0) }
                    ), in: 10...120, step: 10)
                    .accentColor(.blue)
                    
                    Text("\(sessionTimeout) minutes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Two-Factor Authentication") {
                Toggle("Enable 2FA", isOn: $enableTwoFactor)
                
                if enableTwoFactor {
                    Text("Two-factor authentication setup will be implemented here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Security Settings")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationView {
        AccountSettingsView()
    }
}