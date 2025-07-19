import SwiftUI

struct MainAppView: View {
    @ObservedObject private var authManager = AuthenticationManager.shared
    @State private var showingNVRList = false
    
    var body: some View {
        NavigationView {
            TabView {
                CameraTabView()
                    .tabItem {
                        Image(systemName: "camera")
                        Text("Camera")
                    }
                
                PlaceholderTabView(title: "Storage")
                    .tabItem {
                        Image(systemName: "externaldrive")
                        Text("Storage")
                    }
                
                PlaceholderTabView(title: "Network")
                    .tabItem {
                        Image(systemName: "network")
                        Text("Network")
                    }
                
                PlaceholderTabView(title: "Account")
                    .tabItem {
                        Image(systemName: "person")
                        Text("Account")
                    }
                
                PlaceholderTabView(title: "System")
                    .tabItem {
                        Image(systemName: "gear")
                        Text("System")
                    }
            }
            .navigationTitle(currentNVRName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingNVRList = true
                    }) {
                        Image(systemName: "list.bullet")
                    }
                }
            }
            .sheet(isPresented: $showingNVRList) {
                NVRListView()
            }
        }
    }
    
    private var currentNVRName: String {
        let currentNVR = authManager.nvrManager.currentNVR
        let nvrCount = authManager.nvrManager.nvrSystems.count
        
        #if DEBUG
        print("🔍 [MainAppView] Current NVR: \(currentNVR?.name ?? "nil"), NVR Systems Count: \(nvrCount)")
        if nvrCount > 0 {
            print("🔍 [MainAppView] NVR Systems: \(authManager.nvrManager.nvrSystems.map { $0.name })")
        }
        #endif
        
        return currentNVR?.name ?? "No NVR Selected"
    }
}

struct PlaceholderTabView: View {
    let title: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "construction")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("\(title) Feature")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("This feature will be available in a future release.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    MainAppView()
}