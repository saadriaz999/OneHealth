import SwiftUI

struct PatientMedicinesView: View {
    let patient: Patient
    @State private var medicines: [Medicine] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showPrescribe = false

    var body: some View {
        Group {
            if isLoading && medicines.isEmpty {
                ProgressView("Loading medicines...")
            } else if medicines.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "pills.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No medicines on file")
                        .font(.headline)
                }
            } else {
                List(medicines) { medicine in
                    MedicineRowView(medicine: medicine)
                }
            }
        }
        .navigationTitle(patient.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showPrescribe = true
                } label: {
                    Label("Prescribe", systemImage: "plus.circle")
                }
            }
        }
        .sheet(isPresented: $showPrescribe) {
            PrescribeView(patient: patient, currentMedicines: medicines)
        }
        .task { await loadMedicines() }
        .refreshable { await loadMedicines() }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func loadMedicines() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await APIService.shared.getPatientMedicines(patientId: patient.patientId)
            medicines = response.medicines
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
