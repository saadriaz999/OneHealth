import SwiftUI

struct SafetyCheckView: View {
    @Environment(\.dismiss) var dismiss
    @State private var medicineName = ""
    @State private var result: SafetyCheckResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Check a new medicine")
                            .font(.headline)
                        Text("Enter any medicine you're considering — OTC or prescribed — to check if it's safe with your current medications.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            TextField("Medicine name", text: $medicineName)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                            Button {
                                Task { await check() }
                            } label: {
                                if isLoading {
                                    ProgressView()
                                        .frame(width: 44, height: 44)
                                } else {
                                    Image(systemName: "magnifyingglass.circle.fill")
                                        .font(.title)
                                        .foregroundColor(.blue)
                                }
                            }
                            .disabled(medicineName.isEmpty || isLoading)
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    if let result = result {
                        safetyResult(result)
                    }
                }
                .padding()
            }
            .navigationTitle("Safety Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func safetyResult(_ result: SafetyCheckResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Safety badge
            HStack {
                Image(systemName: result.isSafe ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .font(.title)
                    .foregroundColor(result.isSafe ? .green : .red)
                VStack(alignment: .leading) {
                    Text(result.isSafe ? "Appears Safe" : "Interaction Detected")
                        .font(.headline)
                        .foregroundColor(result.isSafe ? .green : .red)
                    Text("\(result.interactionsFound) interaction(s) found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(result.isSafe ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
            .cornerRadius(12)

            // AI explanation
            VStack(alignment: .leading, spacing: 8) {
                Text("What this means")
                    .font(.headline)
                Text(result.explanation)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            // Interaction details
            if !result.interactions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Interactions Found")
                        .font(.headline)
                    ForEach(result.interactions) { interaction in
                        InteractionRowView(interaction: interaction)
                    }
                }
            }

            Text("Always consult your doctor before starting a new medicine.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
    }

    private func check() async {
        isLoading = true
        errorMessage = nil
        result = nil
        do {
            result = try await APIService.shared.safetyCheck(medicineName: medicineName)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct InteractionRowView: View {
    let interaction: DDIInteraction

    var severityColor: Color {
        switch interaction.severity.lowercased() {
        case "contraindicated": return .red
        case "major": return .orange
        case "moderate": return .yellow
        default: return .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(interaction.drugA) + \(interaction.drugB)")
                    .font(.subheadline.bold())
                Spacer()
                Text(interaction.severity.uppercased())
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(severityColor.opacity(0.2))
                    .foregroundColor(severityColor)
                    .cornerRadius(6)
            }
            Text(interaction.description)
                .font(.caption)
                .foregroundColor(.secondary)
            if let management = interaction.management, !management.isEmpty {
                Text("Management: \(management)")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}
