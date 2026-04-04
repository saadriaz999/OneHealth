import SwiftUI

struct InternationalLookupView: View {
    @Environment(\.dismiss) var dismiss
    @State private var drugName = ""
    @State private var result: InternationalLookupResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Look up a foreign or international medicine to find its composition and US equivalent.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            TextField("International medicine name", text: $drugName)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                            Button {
                                Task { await lookup() }
                            } label: {
                                if isLoading {
                                    ProgressView().frame(width: 44, height: 44)
                                } else {
                                    Image(systemName: "magnifyingglass.circle.fill")
                                        .font(.title)
                                        .foregroundColor(.blue)
                                }
                            }
                            .disabled(drugName.isEmpty || isLoading)
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    if let result = result {
                        lookupResult(result)
                    }
                }
                .padding()
            }
            .navigationTitle("International Lookup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func lookupResult(_ result: InternationalLookupResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Drug name header
            Text(result.drugName)
                .font(.title2.bold())

            // Active ingredients
            if !result.activeIngredients.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Ingredients")
                        .font(.headline)
                    ForEach(result.activeIngredients) { ingredient in
                        HStack {
                            Image(systemName: "flask.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text(ingredient.name)
                            Spacer()
                            if let strength = ingredient.strength {
                                Text("\(strength) \(ingredient.unit ?? "")")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

            // Clinical description
            VStack(alignment: .leading, spacing: 8) {
                Text("Clinical Overview")
                    .font(.headline)
                Text(result.clinicalDescription)
                    .font(.body)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            // US equivalents
            if !result.usEquivalents.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("US Equivalents")
                        .font(.headline)
                    ForEach(result.usEquivalents) { equivalent in
                        HStack {
                            Image(systemName: "flag.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text(equivalent.name)
                                .font(.subheadline)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.08))
                .cornerRadius(12)
            } else {
                Text("No US equivalents found. Consider consulting a pharmacist.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func lookup() async {
        isLoading = true
        errorMessage = nil
        result = nil
        do {
            result = try await APIService.shared.internationalLookup(drugName: drugName)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
