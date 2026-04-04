import Foundation

// MARK: - Auth

struct AuthResponse: Codable {
    let accessToken: String
    let tokenType: String
    let role: String
    let userId: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case role
        case userId = "user_id"
        case name
    }
}

// MARK: - Medicine

struct Medicine: Codable, Identifiable {
    let id: String
    let name: String
    let genericName: String?
    let dosage: String?
    let frequency: String?
    let timesPerDay: Int?
    let timeOfDay: String?
    let startDate: String?
    let notes: String?
    let addedBy: String?
    let isInternational: Bool?
    let rxnormId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case genericName = "generic_name"
        case dosage
        case frequency
        case timesPerDay = "times_per_day"
        case timeOfDay = "time_of_day"
        case startDate = "start_date"
        case notes
        case addedBy = "added_by"
        case isInternational = "is_international"
        case rxnormId = "rxnorm_id"
    }
}

struct MedicineDashboardResponse: Codable {
    let patient: String
    let medicines: [Medicine]
}

// MARK: - DDI

struct DDIInteraction: Codable, Identifiable {
    var id: String { "\(drugA)-\(drugB)" }
    let drugA: String
    let drugB: String
    let severity: String
    let description: String
    let management: String?
    let source: String?

    enum CodingKeys: String, CodingKey {
        case drugA = "drug_a"
        case drugB = "drug_b"
        case severity
        case description
        case management
        case source
    }
}

struct SafetyCheckResponse: Codable {
    let medicineChecked: String
    let isSafe: Bool
    let interactionsFound: Int
    let interactions: [DDIInteraction]
    let explanation: String

    enum CodingKeys: String, CodingKey {
        case medicineChecked = "medicine_checked"
        case isSafe = "is_safe"
        case interactionsFound = "interactions_found"
        case interactions
        case explanation
    }
}

// MARK: - Doctor

struct Patient: Codable, Identifiable {
    let patientId: String
    let userId: String
    let name: String
    let email: String
    let dateOfBirth: String?
    let allergies: String?

    var id: String { patientId }

    enum CodingKeys: String, CodingKey {
        case patientId = "patient_id"
        case userId = "user_id"
        case name
        case email
        case dateOfBirth = "date_of_birth"
        case allergies
    }
}

struct PatientsResponse: Codable {
    let patients: [Patient]
}

struct PrescribeResponse: Codable {
    let status: String
    let medicine: String?
    let patient: String?
    let interactionsFound: Int?
    let interactions: [DDIInteraction]?
    let clinicalSummary: String?
    let message: String?
    let warning: String?

    enum CodingKeys: String, CodingKey {
        case status
        case medicine
        case patient
        case interactionsFound = "interactions_found"
        case interactions
        case clinicalSummary = "clinical_summary"
        case message
        case warning
    }
}

// MARK: - Extracted Medicine (from scan)

struct ExtractedMedicine: Codable {
    let brandName: String?
    let genericName: String?
    let dosageStrength: String?
    let dosageForm: String?
    let manufacturer: String?
    let activeIngredients: [String]?
    let instructions: String?
    let isInternational: Bool?
    let countryOfOrigin: String?

    enum CodingKeys: String, CodingKey {
        case brandName = "brand_name"
        case genericName = "generic_name"
        case dosageStrength = "dosage_strength"
        case dosageForm = "dosage_form"
        case manufacturer
        case activeIngredients = "active_ingredients"
        case instructions
        case isInternational = "is_international"
        case countryOfOrigin = "country_of_origin"
    }
}

struct ScanResponse: Codable {
    let extracted: ExtractedMedicine
}

// MARK: - Chat

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String   // "user" or "assistant"
    let content: String
}

struct ChatRequest: Codable {
    let message: String
    let conversationHistory: [[String: String]]

    enum CodingKeys: String, CodingKey {
        case message
        case conversationHistory = "conversation_history"
    }
}

struct ChatResponse: Codable {
    let response: String
}

// MARK: - International Lookup

struct InternationalLookupResponse: Codable {
    let drugName: String
    let activeIngredients: [ActiveIngredient]
    let clinicalDescription: String
    let usEquivalents: [USEquivalent]

    enum CodingKeys: String, CodingKey {
        case drugName = "drug_name"
        case activeIngredients = "active_ingredients"
        case clinicalDescription = "clinical_description"
        case usEquivalents = "us_equivalents"
    }
}

struct ActiveIngredient: Codable, Identifiable {
    var id: String { name }
    let name: String
    let strength: String?
    let unit: String?
}

struct USEquivalent: Codable, Identifiable {
    var id: String { setId ?? name }
    let name: String
    let setId: String?

    enum CodingKeys: String, CodingKey {
        case name
        case setId = "set_id"
    }
}
