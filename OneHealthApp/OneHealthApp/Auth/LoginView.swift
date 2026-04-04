import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: "cross.case.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.blue)
                    Text("OneHealth")
                        .font(.largeTitle.bold())
                    Text("Smart medication safety")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)

                    if let error = authVM.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    Button {
                        Task { await authVM.login(email: email, password: password) }
                    } label: {
                        Group {
                            if authVM.isLoading {
                                ProgressView()
                            } else {
                                Text("Sign In")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(authVM.isLoading || email.isEmpty || password.isEmpty)
                }

                Button("Don't have an account? Register") {
                    showRegister = true
                }
                .foregroundColor(.blue)

                Spacer()
            }
            .padding(.horizontal, 28)
            .sheet(isPresented: $showRegister) {
                RegisterView()
                    .environmentObject(authVM)
            }
        }
    }
}
