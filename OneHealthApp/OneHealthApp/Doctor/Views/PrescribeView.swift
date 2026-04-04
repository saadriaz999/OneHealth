import SwiftUI

struct PrescribeView: View {
    let patient: Patient
    let currentMedicines: [Medicine]
    @Environment(\.dismiss) var dismiss

    @State private var medicineName = ""
    @State private var dosage = ""
    @State private var frequency = ""
    @State private var duration = ""
    @State private var notes = ""
    @State private var isLoading = false
    @State private var prescribeResult: PrescribeResponse?
    @State private var errorMessage: String?
    @State private var showInteractionAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Current medicines summary
                    if !currentMedicines.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Medications")
                                .font(.headline)
                            ForEach(currentMedicines) { med in
                                HStack {
                                    Image(systemName: "pills.fill")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    Text(med.name)
                                        .font(.subheadline)
                                    Spacer()
                                    if let dosage = med.dosage {
                                        Text(dosage)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    // Prescription form
                    VStack(alignment: .leading, spacing: 12) {
                        Text("New Prescription")
                            .font(.headline)

                        LabeledTextField("Medicine Name *", text: $medicineName)
                        LabeledTextField("Dosage (e.g. 500mg)", text: $dosage)
                        LabeledTextField("Frequency (e.g. twice daily)", text: $frequency)
                        LabeledTextField("Duration (e.g. 7 days)", text: $duration)
                        LabeledTextField("Notes", text: $notes)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    // DDI Result
                    if let result = prescribeResult {
                        ddiResultView(result)
                    }

                    Button {
                        Task { await prescribe(force: false) }
                    } label: {
                        if isLoading {
                            ProgressView().frame(maxWidth: .infinity).padding()
                        } else {
                            HStack {
                                Image(systemName: "checkmark.shield.fill")
                                Text("Check & Prescribe")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(medicineName.isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                    .disabled(medicineName.isEmpty || isLoading)
                }
                .padding()
            }
            .navigationTitle("Prescribe to \(patient.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func ddiResultView(_ result: PrescribeResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Status banner
            let isPrescribed = result.status == "prescribed"
            HStack {
                Image(systemName: isPrescribed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(isPrescribed ? .green : .red)
                    .font(.title2)
                VStack(alignment: .leading) {
                    Text(isPrescribed ? "Prescription Sent" : "Interaction Detected")
                        .font(.headline)
                        .foregroundColor(isPrescribed ? .green : .red)
                    if let count = result.interactionsFound {
                        Text("\(count) interaction(s) found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isPrescribed ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
            .cornerRadius(12)

            // Blocked message
            if let message = result.message {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Clinical summary
            if let summary = result.clinicalSummary {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Clinical Summary")
                        .font(.headline)
                    Text(summary)
                        .font(.body)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

            // Interaction list
            if let interactions = result.interactions, !interactions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Interactions")
                        .font(.headline)
                    ForEach(interactions) { interaction in
                        InteractionRowView(interaction: interaction)
                    }
                }
            }

            // Force override button if blocked
            if result.status == "blocked" {
                Button {
                    Task { await prescribe(force: true) }
                } label: {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Override & Prescribe Anyway")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
        }
    }

    private func prescribe(force: Bool) async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await APIService.shared.prescribe(
                patientId: patient.patientId,
                medicineName: medicineName,
                dosage: dosage.isEmpty ? nil : dosage,
                frequency: frequency.isEmpty ? nil : frequency,
                duration: duration.isEmpty ? nil : duration,
                notes: notes.isEmpty ? nil : notes,
                force: force
            )
            prescribeResult = result
            if result.status == "prescribed" {
                // Auto dismiss after successful prescription
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
