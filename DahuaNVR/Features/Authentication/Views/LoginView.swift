import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel: LoginViewModel
    
    init(viewModel: LoginViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

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

                        TextField("http://cam.lab", text: $viewModel.serverURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .keyboardType(.URL)
                            .disabled(viewModel.isLoading)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(.headline)
                            .foregroundColor(.primary)

                        TextField("admin", text: $viewModel.username)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disabled(viewModel.isLoading)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.headline)
                            .foregroundColor(.primary)

                        SecureField("Enter password", text: $viewModel.password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disabled(viewModel.isLoading)
                    }
                }
                .padding(.horizontal)

                Button(action: {
                    Task {
                        await viewModel.login()
                    }
                }) {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        }

                        Text(viewModel.isLoading ? "Connecting..." : "Connect")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(viewModel.isFormValid ? Color.blue : Color.gray)
                    )
                }
                .disabled(!viewModel.isFormValid || viewModel.isLoading)
                .padding(.horizontal)
                .padding(.top, 20)
                
                if viewModel.hasPersistedCredentials {
                    Button(action: {
                        viewModel.loadPersistedCredentials()
                    }) {
                        HStack {
                            Image(systemName: "key.fill")
                            Text("Load Saved Credentials")
                        }
                        .font(.footnote)
                        .foregroundColor(.blue)
                    }
                    .padding(.top, 8)
                }

                if let errorMessage = viewModel.errorMessage {
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
        .alert("Connection Error", isPresented: $viewModel.showingAlert) {
            Button("OK") {
                viewModel.dismissAlert()
            }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error occurred")
        }
    }
}

#Preview {
    LoginView(viewModel: LoginViewModel())
}
