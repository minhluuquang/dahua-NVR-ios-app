//
//  ContentView.swift
//  DahuaNVR
//
//  Created by Leo on 13/7/25.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var authManager = AuthenticationManager.shared
    
    var body: some View {
        Group {
            switch authManager.authenticationState {
            case .idle:
                LoginView(viewModel: LoginViewModel())
                
            case .loading:
                ProgressView("Authenticating...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                
            case .authenticated:
                MainAppView()
                
            case .failed(let error):
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("Authentication Failed")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(error)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: {
                        Task {
                            await authManager.retryAuthentication()
                        }
                    }) {
                        Label("Retry", systemImage: "arrow.clockwise")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            }
        }
    }
}

#Preview {
    ContentView()
}
