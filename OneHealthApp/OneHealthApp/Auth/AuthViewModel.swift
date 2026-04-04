import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var role: String = ""
    @Published var userName: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    init() {
        if let token = TokenStore.shared.token, !token.isEmpty {
            role = TokenStore.shared.role ?? ""
            userName = TokenStore.shared.userName ?? ""
            isLoggedIn = true
        }
    }

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await APIService.shared.login(email: email, password: password)
            TokenStore.shared.token = response.accessToken
            TokenStore.shared.role = response.role
            TokenStore.shared.userId = response.userId
            TokenStore.shared.userName = response.name
            role = response.role
            userName = response.name
            isLoggedIn = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func register(
        name: String, email: String, password: String, role: String,
        licenseNumber: String? = nil, specialty: String? = nil,
        dateOfBirth: String? = nil, allergies: String? = nil
    ) async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await APIService.shared.register(
                name: name, email: email, password: password, role: role,
                licenseNumber: licenseNumber, specialty: specialty,
                dateOfBirth: dateOfBirth, allergies: allergies
            )
            TokenStore.shared.token = response.accessToken
            TokenStore.shared.role = response.role
            TokenStore.shared.userId = response.userId
            TokenStore.shared.userName = response.name
            self.role = response.role
            userName = response.name
            isLoggedIn = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func logout() {
        TokenStore.shared.clear()
        isLoggedIn = false
        role = ""
        userName = ""
    }
}
