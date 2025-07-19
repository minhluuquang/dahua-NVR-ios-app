import SwiftUI

struct NVRListView: View {
    @ObservedObject private var authManager = AuthenticationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddNVR = false
    @State private var isConnecting = false
    @State private var connectionError: String?
    
    var body: some View {
        VStack {
            #if DEBUG
            let _ = print("🔍 [NVRListView] NVR Systems Count: \(authManager.nvrManager.nvrSystems.count)")
            let _ = print("🔍 [NVRListView] Current NVR: \(authManager.nvrManager.currentNVR?.name ?? "nil")")
            let _ = print("🔍 [NVRListView] NVR Systems: \(authManager.nvrManager.nvrSystems.map { $0.name })")
            #endif
            
            if authManager.nvrManager.nvrSystems.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("No NVR Systems")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("Add your first NVR system to get started.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Add NVR System") {
                        showingAddNVR = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                List {
                    ForEach(authManager.nvrManager.nvrSystems) { nvr in
                        NVRRowView(
                            nvr: nvr,
                            isSelected: authManager.nvrManager.currentNVR?.id == nvr.id,
                            isConnecting: isConnecting
                        ) {
                            Task {
                                await connectToNVR(nvr)
                            }
                        } onSetDefault: {
                            authManager.nvrManager.setDefaultNVR(nvr)
                        }
                    }
                    .onDelete(perform: deleteNVRSystems)
                }
            }
        }
        .navigationTitle("NVR Systems")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Close") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add") {
                    showingAddNVR = true
                }
            }
        }
        .sheet(isPresented: $showingAddNVR) {
            NavigationView {
                AddNVRView()
            }
        }
        .alert("Connection Error", isPresented: .constant(connectionError != nil)) {
            Button("OK") {
                connectionError = nil
            }
        } message: {
            Text(connectionError ?? "")
        }
    }
    
    private func connectToNVR(_ nvr: NVRSystem) async {
        isConnecting = true
        connectionError = nil
        
        do {
            try await authManager.connectToNVR(nvr)
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                connectionError = error.localizedDescription
            }
        }
        
        isConnecting = false
    }
    
    private func deleteNVRSystems(at offsets: IndexSet) {
        for index in offsets {
            let nvr = authManager.nvrManager.nvrSystems[index]
            authManager.nvrManager.removeNVRSystem(nvr)
        }
    }
}

struct NVRRowView: View {
    let nvr: NVRSystem
    let isSelected: Bool
    let isConnecting: Bool
    let onConnect: () -> Void
    let onSetDefault: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(nvr.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if nvr.isDefault {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                }
                
                Text(nvr.credentials.serverURL)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("User: \(nvr.credentials.username)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                if isSelected {
                    Text("Connected")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                } else {
                    Button(isConnecting ? "Connecting..." : "Connect") {
                        onConnect()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(isConnecting)
                }
                
                if !nvr.isDefault {
                    Button("Set Default") {
                        onSetDefault()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddNVRView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authManager = AuthenticationManager.shared
    @State private var nvrName = ""
    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isDefault = false
    @State private var isConnecting = false
    @State private var connectionError: String?
    
    var body: some View {
        Form {
            Section("NVR Information") {
                TextField("NVR Name", text: $nvrName)
                TextField("Server URL", text: $serverURL)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                TextField("Username", text: $username)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                SecureField("Password", text: $password)
            }
            
            Section("Settings") {
                Toggle("Set as Default NVR", isOn: $isDefault)
            }
            
            Section {
                Button(isConnecting ? "Connecting..." : "Add NVR System") {
                    Task {
                        await addNVRSystem()
                    }
                }
                .disabled(!isFormValid || isConnecting)
            }
        }
        .navigationTitle("Add NVR System")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .alert("Connection Error", isPresented: .constant(connectionError != nil)) {
            Button("OK") {
                connectionError = nil
            }
        } message: {
            Text(connectionError ?? "")
        }
    }
    
    private var isFormValid: Bool {
        !nvrName.isEmpty && !serverURL.isEmpty && !username.isEmpty && !password.isEmpty
    }
    
    private func addNVRSystem() async {
        isConnecting = true
        connectionError = nil
        
        let credentials = NVRCredentials(
            serverURL: serverURL,
            username: username,
            password: password
        )
        
        let nvrSystem = NVRSystem(
            name: nvrName,
            credentials: credentials,
            isDefault: isDefault
        )
        
        do {
            try await authManager.connectToNVR(nvrSystem)
            
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                connectionError = error.localizedDescription
            }
        }
        
        isConnecting = false
    }
}

#Preview {
    NVRListView()
}