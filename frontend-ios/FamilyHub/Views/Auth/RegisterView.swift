import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var password2 = ""

    var body: some View {
        VStack(spacing: 24) {
            Text("Create Account")
                .font(.title.bold())

            VStack(spacing: 14) {
                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.newPassword)

                SecureField("Confirm Password", text: $password2)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.newPassword)

                if let error = authViewModel.error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }

                Button(action: {
                    Task {
                        await authViewModel.register(
                            username: username,
                            email: email,
                            password: password,
                            password2: password2
                        )
                    }
                }) {
                    Group {
                        if authViewModel.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Create Account").fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.indigo)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(authViewModel.isLoading || username.isEmpty || email.isEmpty || password.isEmpty || password2.isEmpty)
            }
            .padding(.horizontal)

            Button("Already have an account? Sign In") {
                dismiss()
            }
            .foregroundColor(.indigo)

            Spacer()
        }
        .padding(.top, 32)
        .navigationBarBackButtonHidden(false)
    }
}
