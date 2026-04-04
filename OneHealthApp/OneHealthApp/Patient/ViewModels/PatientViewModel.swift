import SwiftUI

@MainActor
final class PatientViewModel: ObservableObject {
    @Published var medicines: [Medicine] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    func loadMedicines() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await APIService.shared.getMyMedicines()
            medicines = response.medicines
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func addMedicine(
        name: String, genericName: String? = nil, dosage: String? = nil,
        frequency: String? = nil, timesPerDay: Int? = nil, timeOfDay: String? = nil,
        startDate: String? = nil, notes: String? = nil, isInternational: Bool = false
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await APIService.shared.addMedicine(
                name: name, genericName: genericName, dosage: dosage,
                frequency: frequency, timesPerDay: timesPerDay, timeOfDay: timeOfDay,
                startDate: startDate, notes: notes, isInternational: isInternational
            )
            await loadMedicines()
            successMessage = "\(name) added successfully"
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    func removeMedicine(entryId: String) async {
        do {
            try await APIService.shared.removeMedicine(entryId: entryId)
            medicines.removeAll { $0.id == entryId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
