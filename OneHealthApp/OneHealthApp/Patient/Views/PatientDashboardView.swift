import SwiftUI

struct PatientDashboardView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = PatientViewModel()
    @State private var showAddMedicine = false
    @State private var showScan = false
    @State private var showSafetyCheck = false
    @State private var showChatbot = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.medicines.isEmpty {
                    ProgressView("Loading your medicines...")
                } else if vm.medicines.isEmpty {
                    emptyState
                } else {
                    medicineList
                }
            }
            .navigationTitle("My Medicines")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Sign Out") { authVM.logout() }
                        .foregroundColor(.red)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { showScan = true } label: {
                            Label("Scan Packaging", systemImage: "camera")
                        }
                        Button { showAddMedicine = true } label: {
                            Label("Add Manually", systemImage: "plus")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { bottomActions }
            .sheet(isPresented: $showAddMedicine) {
                AddMedicineView(vm: vm)
            }
            .sheet(isPresented: $showScan) {
                ScanMedicineView(patientVM: vm)
            }
            .sheet(isPresented: $showSafetyCheck) {
                SafetyCheckView()
            }
            .sheet(isPresented: $showChatbot) {
                ChatbotView()
            }
            .task { await vm.loadMedicines() }
            .alert("Error", isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )) {
                Button("OK") { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
    }

    private var medicineList: some View {
        List {
            ForEach(vm.medicines) { medicine in
                MedicineRowView(medicine: medicine)
            }
            .onDelete { indexSet in
                Task {
                    for index in indexSet {
                        await vm.removeMedicine(entryId: vm.medicines[index].id)
                    }
                }
            }
        }
        .refreshable { await vm.loadMedicines() }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "pills.circle")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            Text("No medicines added yet")
                .font(.headline)
            Text("Scan a medicine label or add manually")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var bottomActions: some View {
        HStack(spacing: 12) {
            Button {
                showSafetyCheck = true
            } label: {
                Label("Safety Check", systemImage: "checkmark.shield")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }

            Button {
                showChatbot = true
            } label: {
                Label("Ask AI", systemImage: "bubble.left.and.bubble.right")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

struct MedicineRowView: View {
    let medicine: Medicine

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(medicine.name)
                    .font(.headline)
                Spacer()
                if medicine.isInternational == true {
                    Label("International", systemImage: "globe")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            if let generic = medicine.genericName {
                Text(generic)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack(spacing: 12) {
                if let dosage = medicine.dosage {
                    Label(dosage, systemImage: "pills")
                        .font(.caption)
                }
                if let frequency = medicine.frequency {
                    Label(frequency, systemImage: "clock")
                        .font(.caption)
                }
            }
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
