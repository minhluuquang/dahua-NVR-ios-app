//
//  ContentView.swift
//  DahuaNVR
//
//  Created by Leo on 13/7/25.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var authManager = AuthenticationManager.shared
    @State private var isInitializing = true
    @State private var showingNVRList = false
    @State private var connectionFailed = false
    
    var body: some View {
        Group {
            if isInitializing {
                ProgressView("Initializing...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            } else if authManager.isAuthenticated {
                MainAppView()
            } else if authManager.nvrManager.nvrSystems.isEmpty {
                LoginView(viewModel: LoginViewModel())
            } else {
                NVRListView()
            }
        }
        .task {
            await initializeApp()
        }
        .alert("Connection Failed", isPresented: $connectionFailed) {
            Button("OK") {
                connectionFailed = false
            }
        } message: {
            Text("Failed to connect to the default NVR system. Please select an NVR system from the list.")
        }
    }
    
    private func initializeApp() async {
        if authManager.nvrManager.nvrSystems.isEmpty {
            await MainActor.run {
                isInitializing = false
            }
            return
        }
        
        if let defaultNVR = authManager.nvrManager.defaultNVR {
            do {
                try await authManager.connectToNVR(defaultNVR)
                await MainActor.run {
                    isInitializing = false
                }
            } catch {
                await MainActor.run {
                    connectionFailed = true
                    isInitializing = false
                }
            }
        } else {
            await MainActor.run {
                isInitializing = false
            }
        }
    }
}

#Preview {
    ContentView()
}
