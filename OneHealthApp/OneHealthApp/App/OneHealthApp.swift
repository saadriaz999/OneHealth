import SwiftUI

@main
struct OneHealthApp: App {
    @StateObject private var authVM = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authVM)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        if !authVM.isLoggedIn {
            LoginView()
        } else if authVM.role == "doctor" {
            DoctorDashboardView()
        } else {
            PatientDashboardView()
        }
    }
}
