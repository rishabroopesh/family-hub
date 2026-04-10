import SwiftUI
import AuthenticationServices

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var classroomViewModel: ClassroomViewModel
    @State private var serverURL = APIClient.shared.baseURL
    @State private var showDisconnectAlert = false
    @State private var showLogoutAlert = false

    var body: some View {
        NavigationStack {
            Form {
                // Profile
                Section("Account") {
                    if let user = authViewModel.currentUser {
                        LabeledContent("Username", value: user.username)
                        LabeledContent("Email", value: user.email)
                    }
                }

                // Server
                Section {
                    TextField("http://192.168.1.100:8000", text: $serverURL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: serverURL) {
                            APIClient.shared.baseURL = serverURL
                        }
                } header: {
                    Text("Unraid Server URL")
                } footer: {
                    Text("Enter the local IP and port of your Unraid server.")
                }

                // Google Classroom
                Section("Google Classroom") {
                    if classroomViewModel.googleConnected {
                        HStack {
                            Label("Connected", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Spacer()
                            if let email = classroomViewModel.googleEmail {
                                Text(email)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Button("Disconnect Google Account", role: .destructive) {
                            showDisconnectAlert = true
                        }
                    } else {
                        Button("Connect Google Classroom") {
                            Task { await connectGoogle() }
                        }
                    }
                }

                // Sync logs
                if let log = classroomViewModel.syncStatus {
                    Section("Last Sync") {
                        LabeledContent("Status", value: "\(log.statusEmoji) \(log.status.capitalized)")
                        LabeledContent("Courses", value: "\(log.coursesSynced)")
                        LabeledContent("Assignments", value: "\(log.courseworkSynced)")
                        LabeledContent("Started", value: String(log.startedAt.prefix(19)).replacingOccurrences(of: "T", with: " "))
                    }
                }

                // App info
                Section {
                    LabeledContent("Version", value: "1.0.0 MVP")
                    LabeledContent("Build", value: "001")
                }

                // Logout
                Section {
                    Button("Sign Out", role: .destructive) {
                        showLogoutAlert = true
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                serverURL = APIClient.shared.baseURL
                Task {
                    await classroomViewModel.checkGoogleStatus()
                    await classroomViewModel.loadSyncStatus()
                }
            }
            .alert("Disconnect Google?", isPresented: $showDisconnectAlert) {
                Button("Disconnect", role: .destructive) {
                    Task { await classroomViewModel.disconnectGoogle() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your Google Classroom data will no longer sync.")
            }
            .alert("Sign Out?", isPresented: $showLogoutAlert) {
                Button("Sign Out", role: .destructive) {
                    Task { await authViewModel.logout() }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func connectGoogle() async {
        guard let urlString = await classroomViewModel.getGoogleConnectURL(),
              let url = URL(string: urlString) else { return }

        let session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: "familyhub"
        ) { _, error in
            if error == nil {
                Task {
                    await classroomViewModel.checkGoogleStatus()
                }
            }
        }
        session.prefersEphemeralWebBrowserSession = false
        session.start()
    }
}
