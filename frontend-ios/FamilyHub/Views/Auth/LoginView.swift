import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var username = ""
    @State private var password = ""
    @State private var showRegister = false
    @State private var showServerConfig = false
    @State private var serverURL = APIClient.shared.baseURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: 60)

                    // Logo
                    VStack(spacing: 12) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.indigo)
                        Text("FamilyHub")
                            .font(.largeTitle.bold())
                        Text("Your family workspace")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // Form
                    VStack(spacing: 16) {
                        TextField("Username", text: $username)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)

                        if let error = authViewModel.error {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                        }

                        Button(action: {
                            Task { await authViewModel.login(username: username, password: password) }
                        }) {
                            Group {
                                if authViewModel.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Sign In")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.indigo)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(authViewModel.isLoading || username.isEmpty || password.isEmpty)
                    }
                    .padding(.horizontal)

                    Button("Don't have an account? Register") {
                        showRegister = true
                    }
                    .foregroundColor(.indigo)

                    Spacer().frame(height: 40)

                    // Server config
                    Button(action: { showServerConfig = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "server.rack")
                                .font(.caption)
                            Text("Server: \(APIClient.shared.baseURL)")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding(.bottom)
                }
            }
            .navigationDestination(isPresented: $showRegister) {
                RegisterView().environmentObject(authViewModel)
            }
            .sheet(isPresented: $showServerConfig) {
                ServerConfigView(serverURL: $serverURL)
            }
        }
    }
}

struct ServerConfigView: View {
    @Binding var serverURL: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Unraid Server URL") {
                    TextField("http://192.168.1.100:8000", text: $serverURL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                Section {
                    Text("Enter the local IP and port of your Unraid server running the FamilyHub backend.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Server Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        APIClient.shared.baseURL = serverURL
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
