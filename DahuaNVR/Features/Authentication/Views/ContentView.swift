//
//  ContentView.swift
//  DahuaNVR
//
//  Created by Leo on 13/7/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authService = DahuaNVRAuthService()
    @StateObject private var viewModel: ContentViewModel
    
    init() {
        let authService = DahuaNVRAuthService()
        self._authService = StateObject(wrappedValue: authService)
        self._viewModel = StateObject(wrappedValue: ContentViewModel(authService: authService))
    }
    
    var body: some View {
        Group {
            if viewModel.isAuthenticated {
                SettingsDashboardView()
                    .environmentObject(authService)
            } else {
                LoginView(viewModel: LoginViewModel(authService: authService))
                    .environmentObject(authService)
            }
        }
    }
}

#Preview {
    ContentView()
}
