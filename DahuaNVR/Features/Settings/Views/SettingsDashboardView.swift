import SwiftUI

struct SettingsDashboardView: View {
    @EnvironmentObject private var authService: DahuaNVRAuthService
    @EnvironmentObject private var contentViewModel: ContentViewModel
    @State private var showingLogoutAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerView
                
                ScrollView {
                    LazyVGrid(columns: gridColumns, spacing: 20) {
                        ForEach(SettingsCategory.allCases, id: \.self) { category in
                            NavigationLink(destination: destinationView(for: category)) {
                                SettingsCategoryCard(category: category)
                            }
                        }
                        
                        liveViewCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                
                Spacer()
            }
            .navigationTitle("NVR Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Logout") {
                        showingLogoutAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
            .alert("Logout", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Logout", role: .destructive) {
                    Task {
                        await contentViewModel.logout()
                    }
                }
            } message: {
                Text("Are you sure you want to logout?")
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "video.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            Text("Configuration Dashboard")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
    }
    
    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]
    }
    
    private var liveViewCard: some View {
        NavigationLink(destination: LiveViewPlaceholder()) {
            VStack(spacing: 12) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
                
                Text("Live View")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Monitor cameras")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private func destinationView(for category: SettingsCategory) -> some View {
        switch category {
        case .camera:
            CameraSettingsView()
        case .storage:
            StorageSettingsView()
        case .network:
            NetworkSettingsView()
        case .system:
            SystemSettingsView()
        case .account:
            AccountSettingsView()
        }
    }
}

struct SettingsCategoryCard: View {
    let category: SettingsCategory
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.system(size: 40))
                .foregroundColor(category.color)
            
            Text(category.title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(category.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(category.color.opacity(0.3), lineWidth: 2)
        )
    }
}

enum SettingsCategory: CaseIterable {
    case camera
    case storage
    case network
    case system
    case account
    
    var title: String {
        switch self {
        case .camera: return "Camera"
        case .storage: return "Storage"
        case .network: return "Network"
        case .system: return "System"
        case .account: return "Account"
        }
    }
    
    var description: String {
        switch self {
        case .camera: return "Manage cameras and video settings"
        case .storage: return "Configure recording and storage"
        case .network: return "Network and connectivity settings"
        case .system: return "System configuration and maintenance"
        case .account: return "User accounts and permissions"
        }
    }
    
    var icon: String {
        switch self {
        case .camera: return "video.fill"
        case .storage: return "externaldrive.fill"
        case .network: return "network"
        case .system: return "gearshape.fill"
        case .account: return "person.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .camera: return .blue
        case .storage: return .orange
        case .network: return .purple
        case .system: return .gray
        case .account: return .green
        }
    }
}

struct LiveViewPlaceholder: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("Live View")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Live camera monitoring will be implemented here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .navigationTitle("Live View")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsDashboardView()
        .environmentObject(DahuaNVRAuthService())
        .environmentObject(ContentViewModel())
}