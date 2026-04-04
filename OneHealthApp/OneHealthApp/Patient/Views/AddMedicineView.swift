import SwiftUI

struct AddMedicineView: View {
    @ObservedObject var vm: PatientViewModel
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var genericName = ""
    @State private var dosage = ""
    @State private var frequency = ""
    @State private var timesPerDay = ""
    @State private var timeOfDay = ""
    @State private var startDate = ""
    @State private var notes = ""
    @State private var isInternational = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Medicine") {
                    TextField("Brand Name *", text: $name)
                    TextField("Generic Name", text: $genericName)
                    Toggle("International Medicine", isOn: $isInternational)
                }

                Section("Dosage & Schedule") {
                    TextField("Dosage (e.g. 500mg)", text: $dosage)
                    TextField("Frequency (e.g. twice daily)", text: $frequency)
                    TextField("Times Per Day (e.g. 2)", text: $timesPerDay)
                        .keyboardType(.numberPad)
                    TextField("Time of Day (e.g. morning, evening)", text: $timeOfDay)
                    TextField("Start Date (YYYY-MM-DD)", text: $startDate)
                }

                Section("Notes") {
                    TextField("Additional notes", text: $notes, axis: .vertical)
                        .lineLimit(3)
                }

                if let error = vm.errorMessage {
                    Section {
                        Text(error).foregroundColor(.red).font(.caption)
                    }
                }

                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        if vm.isLoading {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Add Medicine")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(name.isEmpty || vm.isLoading)
                }
            }
            .navigationTitle("Add Medicine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func save() async {
        let success = await vm.addMedicine(
            name: name,
            genericName: genericName.isEmpty ? nil : genericName,
            dosage: dosage.isEmpty ? nil : dosage,
            frequency: frequency.isEmpty ? nil : frequency,
            timesPerDay: Int(timesPerDay),
            timeOfDay: timeOfDay.isEmpty ? nil : timeOfDay,
            startDate: startDate.isEmpty ? nil : startDate,
            notes: notes.isEmpty ? nil : notes,
            isInternational: isInternational
        )
        if success { dismiss() }
    }
}
