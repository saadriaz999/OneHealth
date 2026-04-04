import Foundation
import UIKit

// MARK: - Configuration

enum APIConfig {
    static let baseURL = "https://YOUR_EC2_PUBLIC_IP"  // Replace with your EC2 URL
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case serverError(String)
    case decodingError
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:       return "Invalid URL"
        case .unauthorized:     return "Session expired. Please log in again."
        case .serverError(let msg): return msg
        case .decodingError:    return "Failed to parse server response"
        case .networkError(let e): return e.localizedDescription
        }
    }
}

// MARK: - Token Store

final class TokenStore {
    static let shared = TokenStore()
    private let key = "onehealth_access_token"

    var token: String? {
        get { UserDefaults.standard.string(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    var role: String? {
        get { UserDefaults.standard.string(forKey: "onehealth_role") }
        set { UserDefaults.standard.set(newValue, forKey: "onehealth_role") }
    }

    var userId: String? {
        get { UserDefaults.standard.string(forKey: "onehealth_user_id") }
        set { UserDefaults.standard.set(newValue, forKey: "onehealth_user_id") }
    }

    var userName: String? {
        get { UserDefaults.standard.string(forKey: "onehealth_user_name") }
        set { UserDefaults.standard.set(newValue, forKey: "onehealth_user_name") }
    }

    func clear() {
        token = nil
        role = nil
        userId = nil
        userName = nil
    }
}

// MARK: - API Service

final class APIService {
    static let shared = APIService()
    private let session = URLSession.shared

    // MARK: Core Request

    private func request<T: Decodable>(
        path: String,
        method: String = "GET",
        body: Encodable? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        guard let url = URL(string: "\(APIConfig.baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth, let token = TokenStore.shared.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            req.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: req)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError("No HTTP response")
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        if httpResponse.statusCode >= 400 {
            if let errorBody = try? JSONDecoder().decode([String: String].self, from: data),
               let detail = errorBody["detail"] {
                throw APIError.serverError(detail)
            }
            throw APIError.serverError("Server error \(httpResponse.statusCode)")
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError
        }
    }

    // MARK: Multipart (for image upload)

    private func uploadImage<T: Decodable>(
        path: String,
        imageData: Data,
        mimeType: String = "image/jpeg"
    ) async throws -> T {
        guard let url = URL(string: "\(APIConfig.baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        let boundary = UUID().uuidString
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = TokenStore.shared.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"medicine.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        req.httpBody = body

        let (data, response) = try await session.data(for: req)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError("No response")
        }

        if httpResponse.statusCode >= 400 {
            throw APIError.serverError("Upload failed: \(httpResponse.statusCode)")
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Auth

    func register(
        name: String, email: String, password: String, role: String,
        licenseNumber: String? = nil, specialty: String? = nil,
        dateOfBirth: String? = nil, allergies: String? = nil
    ) async throws -> AuthResponse {
        struct RegisterBody: Encodable {
            let name, email, password, role: String
            let licenseNumber: String?
            let specialty: String?
            let dateOfBirth: String?
            let allergies: String?
            enum CodingKeys: String, CodingKey {
                case name, email, password, role
                case licenseNumber = "license_number"
                case specialty
                case dateOfBirth = "date_of_birth"
                case allergies
            }
        }
        let body = RegisterBody(name: name, email: email, password: password, role: role,
                                licenseNumber: licenseNumber, specialty: specialty,
                                dateOfBirth: dateOfBirth, allergies: allergies)
        return try await request(path: "/auth/register", method: "POST", body: body, requiresAuth: false)
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        struct LoginBody: Encodable { let email, password: String }
        return try await request(path: "/auth/login", method: "POST",
                                 body: LoginBody(email: email, password: password),
                                 requiresAuth: false)
    }

    // MARK: - Patient

    func scanMedicine(imageData: Data) async throws -> ScanResponse {
        return try await uploadImage(path: "/patient/medicines/scan", imageData: imageData)
    }

    func addMedicine(
        name: String, genericName: String? = nil, dosage: String? = nil,
        frequency: String? = nil, timesPerDay: Int? = nil, timeOfDay: String? = nil,
        startDate: String? = nil, notes: String? = nil, isInternational: Bool = false
    ) async throws -> [String: String] {
        struct AddBody: Encodable {
            let name: String
            let genericName: String?
            let dosage: String?
            let frequency: String?
            let timesPerDay: Int?
            let timeOfDay: String?
            let startDate: String?
            let notes: String?
            let isInternational: Bool
            enum CodingKeys: String, CodingKey {
                case name
                case genericName = "generic_name"
                case dosage, frequency
                case timesPerDay = "times_per_day"
                case timeOfDay = "time_of_day"
                case startDate = "start_date"
                case notes
                case isInternational = "is_international"
            }
        }
        let body = AddBody(name: name, genericName: genericName, dosage: dosage,
                           frequency: frequency, timesPerDay: timesPerDay, timeOfDay: timeOfDay,
                           startDate: startDate, notes: notes, isInternational: isInternational)
        return try await request(path: "/patient/medicines/add", method: "POST", body: body)
    }

    func getMyMedicines() async throws -> MedicineDashboardResponse {
        return try await request(path: "/patient/medicines")
    }

    func safetyCheck(medicineName: String) async throws -> SafetyCheckResponse {
        struct Body: Encodable {
            let name: String
        }
        return try await request(path: "/patient/medicines/safety-check", method: "POST",
                                 body: Body(name: medicineName))
    }

    func chat(message: String, history: [[String: String]]) async throws -> ChatResponse {
        let body = ChatRequest(message: message, conversationHistory: history)
        return try await request(path: "/patient/chat", method: "POST", body: body)
    }

    func removeMedicine(entryId: String) async throws {
        struct Empty: Decodable {}
        let _: Empty = try await request(path: "/patient/medicines/\(entryId)", method: "DELETE")
    }

    // MARK: - Doctor

    func getPatients() async throws -> PatientsResponse {
        return try await request(path: "/doctor/patients")
    }

    func getPatientMedicines(patientId: String) async throws -> MedicineDashboardResponse {
        return try await request(path: "/doctor/patients/\(patientId)/medicines")
    }

    func prescribe(
        patientId: String, medicineName: String, dosage: String? = nil,
        frequency: String? = nil, duration: String? = nil, notes: String? = nil,
        force: Bool = false
    ) async throws -> PrescribeResponse {
        struct PrescribeBody: Encodable {
            let patientId: String
            let medicineName: String
            let dosage: String?
            let frequency: String?
            let duration: String?
            let notes: String?
            let force: Bool
            enum CodingKeys: String, CodingKey {
                case patientId = "patient_id"
                case medicineName = "medicine_name"
                case dosage, frequency, duration, notes, force
            }
        }
        let body = PrescribeBody(patientId: patientId, medicineName: medicineName,
                                 dosage: dosage, frequency: frequency, duration: duration,
                                 notes: notes, force: force)
        return try await request(path: "/doctor/prescribe", method: "POST", body: body)
    }

    func assignPatient(email: String) async throws -> [String: String] {
        struct Body: Encodable { let patientEmail: String
            enum CodingKeys: String, CodingKey { case patientEmail = "patient_email" }
        }
        return try await request(path: "/doctor/patients/assign", method: "POST", body: Body(patientEmail: email))
    }

    func internationalLookup(drugName: String) async throws -> InternationalLookupResponse {
        let encoded = drugName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? drugName
        return try await request(path: "/doctor/medicines/international-lookup?name=\(encoded)")
    }
}
