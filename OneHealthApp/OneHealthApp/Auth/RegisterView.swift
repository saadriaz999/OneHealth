import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var selectedRole = "patient"
    // Doctor fields
    @State private var licenseNumber = ""
    @State private var specialty = ""
    // Patient fields
    @State private var dateOfBirth = ""
    @State private var allergies = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    TextField("Full Name", text: $name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    SecureField("Password", text: $password)

                    Picker("I am a", selection: $selectedRole) {
                        Text("Patient").tag("patient")
                        Text("Doctor").tag("doctor")
                    }
                    .pickerStyle(.segmented)
                }

                if selectedRole == "doctor" {
                    Section("Doctor Details") {
                        TextField("US License Number", text: $licenseNumber)
                        TextField("Specialty (optional)", text: $specialty)
                    }
                } else {
                    Section("Patient Details") {
                        TextField("Date of Birth (YYYY-MM-DD)", text: $dateOfBirth)
                        TextField("Known Allergies (optional)", text: $allergies)
                    }
                }

                if let error = authVM.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button {
                        Task {
                            await authVM.register(
                                name: name, email: email, password: password,
                                role: selectedRole,
                                licenseNumber: selectedRole == "doctor" ? licenseNumber : nil,
                                specialty: selectedRole == "doctor" ? specialty : nil,
                                dateOfBirth: selectedRole == "patient" ? dateOfBirth : nil,
                                allergies: selectedRole == "patient" ? allergies : nil
                            )
                            if authVM.isLoggedIn { dismiss() }
                        }
                    } label: {
                        if authVM.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Create Account")
                                .frame(maxWidth: .infinity)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(authVM.isLoading || name.isEmpty || email.isEmpty || password.isEmpty)
                }
            }
            .navigationTitle("Register")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
