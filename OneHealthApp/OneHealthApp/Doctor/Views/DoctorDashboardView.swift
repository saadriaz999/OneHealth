import SwiftUI

struct DoctorDashboardView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = DoctorViewModel()
    @State private var showAssignPatient = false
    @State private var showInternationalLookup = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.patients.isEmpty {
                    ProgressView("Loading patients...")
                } else if vm.patients.isEmpty {
                    emptyState
                } else {
                    patientList
                }
            }
            .navigationTitle("My Patients")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Sign Out") { authVM.logout() }
                        .foregroundColor(.red)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showAssignPatient = true
                        } label: {
                            Label("Add Patient", systemImage: "person.badge.plus")
                        }
                        Button {
                            showInternationalLookup = true
                        } label: {
                            Label("International Lookup", systemImage: "globe")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showAssignPatient) {
                AssignPatientView(vm: vm)
            }
            .sheet(isPresented: $showInternationalLookup) {
                InternationalLookupView()
            }
            .task { await vm.loadPatients() }
            .refreshable { await vm.loadPatients() }
            .alert("Error", isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )) {
                Button("OK") { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
    }

    private var patientList: some View {
        List(vm.patients) { patient in
            NavigationLink {
                PatientMedicinesView(patient: patient)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(patient.name)
                        .font(.headline)
                    Text(patient.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let dob = patient.dateOfBirth {
                        Text("DOB: \(dob)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if let allergies = patient.allergies, !allergies.isEmpty {
                        Label(allergies, systemImage: "exclamationmark.triangle")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.circle")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            Text("No patients assigned")
                .font(.headline)
            Text("Add a patient by their registered email")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button {
                showAssignPatient = true
            } label: {
                Label("Add Patient", systemImage: "person.badge.plus")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
    }
}

struct AssignPatientView: View {
    @ObservedObject var vm: DoctorViewModel
    @Environment(\.dismiss) var dismiss
    @State private var email = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Patient Email") {
                    TextField("patient@email.com", text: $email)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                if let error = vm.errorMessage {
                    Section {
                        Text(error).foregroundColor(.red).font(.caption)
                    }
                }
                Section {
                    Button {
                        Task {
                            let success = await vm.assignPatient(email: email)
                            if success { dismiss() }
                        }
                    } label: {
                        if vm.isLoading {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Assign Patient").frame(maxWidth: .infinity).fontWeight(.semibold)
                        }
                    }
                    .disabled(email.isEmpty || vm.isLoading)
                }
            }
            .navigationTitle("Add Patient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
