import SwiftUI
import PhotosUI

struct ScanMedicineView: View {
    @ObservedObject var patientVM: PatientViewModel
    @Environment(\.dismiss) var dismiss

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var selectedImage: UIImage?
    @State private var extracted: ExtractedMedicine?
    @State private var isScanning = false
    @State private var errorMessage: String?
    @State private var showAddForm = false

    // Editable fields after extraction
    @State private var name = ""
    @State private var genericName = ""
    @State private var dosage = ""
    @State private var frequency = ""
    @State private var notes = ""
    @State private var isInternational = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Image picker
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 220)
                                .cornerRadius(12)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                                    .frame(height: 180)
                                VStack(spacing: 8) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.blue)
                                    Text("Tap to select medicine photo")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .onChange(of: selectedItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                selectedImageData = data
                                selectedImage = UIImage(data: data)
                                await scanImage(data: data)
                            }
                        }
                    }

                    if isScanning {
                        HStack {
                            ProgressView()
                            Text("Analyzing medicine packaging...")
                                .foregroundColor(.secondary)
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    // Extracted results form
                    if extracted != nil || showAddForm {
                        extractedForm
                    }
                }
                .padding()
            }
            .navigationTitle("Scan Medicine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var extractedForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Medicine Details")
                .font(.headline)

            if extracted != nil {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Details extracted from image")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Group {
                LabeledTextField("Brand Name *", text: $name)
                LabeledTextField("Generic Name", text: $genericName)
                LabeledTextField("Dosage (e.g. 500mg)", text: $dosage)
                LabeledTextField("Frequency (e.g. twice daily)", text: $frequency)
                LabeledTextField("Notes", text: $notes)
            }

            Toggle("International Medicine", isOn: $isInternational)

            Button {
                Task { await save() }
            } label: {
                if patientVM.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Add to My Medicines")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(name.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .disabled(name.isEmpty || patientVM.isLoading)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func scanImage(data: Data) async {
        isScanning = true
        errorMessage = nil
        do {
            let response = try await APIService.shared.scanMedicine(imageData: data)
            extracted = response.extracted
            // Pre-fill form fields
            name = response.extracted.brandName ?? ""
            genericName = response.extracted.genericName ?? ""
            dosage = response.extracted.dosageStrength ?? ""
            isInternational = response.extracted.isInternational ?? false
        } catch {
            errorMessage = "Scan failed: \(error.localizedDescription)"
        }
        isScanning = false
        showAddForm = true
    }

    private func save() async {
        let success = await patientVM.addMedicine(
            name: name,
            genericName: genericName.isEmpty ? nil : genericName,
            dosage: dosage.isEmpty ? nil : dosage,
            frequency: frequency.isEmpty ? nil : frequency,
            notes: notes.isEmpty ? nil : notes,
            isInternational: isInternational
        )
        if success { dismiss() }
    }
}

struct LabeledTextField: View {
    let label: String
    @Binding var text: String

    init(_ label: String, text: Binding<String>) {
        self.label = label
        self._text = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            TextField(label, text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}
