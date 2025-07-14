//
//  ContentView.swift
//  DahuaNVR
//
//  Created by Leo on 13/7/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @StateObject private var loginViewModel = LoginViewModel()
    @StateObject private var authService = DahuaNVRAuthService()
    
    var body: some View {
        Group {
            if viewModel.isInitializing {
                ProgressView("Initializing...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            } else if viewModel.isAuthenticated {
                SettingsDashboardView()
                    .environmentObject(authService)
                    .environmentObject(viewModel)
            } else {
                LoginView(viewModel: loginViewModel)
            }
        }
        .task {
            await loginViewModel.attemptAutoLogin()
        }
    }
}

#Preview {
    ContentView()
}
