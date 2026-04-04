import SwiftUI

@MainActor
final class DoctorViewModel: ObservableObject {
    @Published var patients: [Patient] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    func loadPatients() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await APIService.shared.getPatients()
            patients = response.patients
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func assignPatient(email: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await APIService.shared.assignPatient(email: email)
            await loadPatients()
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
}
