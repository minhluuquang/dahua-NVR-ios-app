import SwiftUI

struct LoginView: View {
    @StateObject private var authService = DahuaNVRAuthService()
    @State private var serverURL = "http://cam.lab"
    @State private var username = "admin"
    @State private var password = "Minhmeo75321@"
    @State private var showingAlert = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "video.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .padding(.bottom, 20)

                Text("Dahua NVR")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("Connect to your NVR system")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 30)

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Server URL")
                            .font(.headline)
                            .foregroundColor(.primary)

                        TextField("http://cam.lab", text: $serverURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .keyboardType(.URL)
                            .disabled(authService.isLoading)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(.headline)
                            .foregroundColor(.primary)

                        TextField("admin", text: $username)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disabled(authService.isLoading)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.headline)
                            .foregroundColor(.primary)

                        SecureField("Enter password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disabled(authService.isLoading)
                    }
                }
                .padding(.horizontal)

                Button(action: {
                    Task {
                        await authService.authenticate(
                            serverURL: serverURL,
                            username: username,
                            password: password
                        )
                    }
                }) {
                    HStack {
                        if authService.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        }

                        Text(authService.isLoading ? "Connecting..." : "Connect")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isFormValid ? Color.blue : Color.gray)
                    )
                }
                .disabled(!isFormValid || authService.isLoading)
                .padding(.horizontal)
                .padding(.top, 20)

                if let errorMessage = authService.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                VStack(spacing: 8) {
                    Text("Security Tips:")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Text(
                        "• Use HTTPS for secure connections\n• Change default passwords\n• Enable IP filtering if available"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("NVR Login")
            .navigationBarTitleDisplayMode(.inline)
        }
        .fullScreenCover(isPresented: $authService.isAuthenticated) {
            MainView()
        }
        .alert("Connection Error", isPresented: $showingAlert) {
            Button("OK") {}
        } message: {
            Text(authService.errorMessage ?? "Unknown error occurred")
        }
        .onChange(of: authService.errorMessage) { newValue in
            showingAlert = newValue != nil
        }
    }

    private var isFormValid: Bool {
        !serverURL.isEmpty && !username.isEmpty && !password.isEmpty
    }
}

struct MainView: View {
    @StateObject private var authService = DahuaNVRAuthService()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)

                Text("Connected Successfully!")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("You are now connected to your Dahua NVR system")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()

                Button("Logout") {
                    authService.logout()
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .navigationTitle("NVR Dashboard")
            .navigationBarTitleDisplayMode(.inline)
        }
        .fullScreenCover(isPresented: .constant(!authService.isAuthenticated)) {
            LoginView()
        }
    }
}

#Preview {
    LoginView()
}
