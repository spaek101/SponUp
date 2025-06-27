import Foundation
import FirebaseFirestoreSwift
import FirebaseFirestore

extension Challenge {
    static let placeholder = Challenge(
        id: "placeholder",
        title: "Loading...",
        startDate: Date(),
        endDate: Date(),
        sponsorID: "",
        createdBy: "",
        assignedAthletes: [],
        eventID: nil,
        desiredAgeGroups: nil,
        type: nil,
        logoURL: nil
    )
}

// MARK: - ChallengeAchievement
struct ChallengeAchievement: Hashable, Codable {
    var type: String       // e.g. "HR", "RBI"
    var quantity: Int
}

// MARK: - SubmissionStatus
enum SubmissionStatus: String, Codable, Hashable, CaseIterable {
    case pending = "Pending"
    case approved = "Approved"
    case rejected = "Rejected"
    case rewarded = "Rewarded"
}

// MARK: - Submission
struct Submission: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var athleteID: String
    var imageURL: String?
    var status: SubmissionStatus
    var submittedAt: Date
}

// MARK: - Challenge
struct Challenge: Identifiable, Codable, Hashable, Equatable {
    @DocumentID var id: String?
    var title: String
    var reward: String? = nil
    var achievements: [ChallengeAchievement] = []        // default value
    var startDate: Date
    var endDate: Date
    var sponsorID: String = ""                            // default value for missing field
    var createdBy: String = ""                            // default value
    var assignedAthletes: [String] = []                   // default value
    var eventID: String? = nil
    var desiredAgeGroups: [String]? = nil                 // will decode if present

    // Optional retailer fields
    var type: String? = nil                               // "sponsor" or "retailer"
    var logoURL: String? = nil                            // Retailer logo URL

    // Local-only field
    var submissions: [Submission] = []                    // not decoded from Firestore

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case reward
        case achievements
        case startDate
        case endDate
        case sponsorID
        case createdBy
        case assignedAthletes
        case eventID
        case desiredAgeGroups
        case type
        case logoURL
        // submissions is intentionally excluded
    }

    static func == (lhs: Challenge, rhs: Challenge) -> Bool {
        return lhs.id == rhs.id &&
               lhs.title == rhs.title &&
               lhs.reward == rhs.reward &&
               lhs.achievements == rhs.achievements &&
               lhs.startDate == rhs.startDate &&
               lhs.endDate == rhs.endDate &&
               lhs.sponsorID == rhs.sponsorID &&
               lhs.createdBy == rhs.createdBy &&
               lhs.assignedAthletes == rhs.assignedAthletes &&
               lhs.eventID == rhs.eventID &&
               lhs.type == rhs.type &&
               lhs.logoURL == rhs.logoURL
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
        hasher.combine(reward)
        hasher.combine(achievements)
        hasher.combine(startDate)
        hasher.combine(endDate)
        hasher.combine(sponsorID)
        hasher.combine(createdBy)
        hasher.combine(assignedAthletes)
        hasher.combine(eventID)
        hasher.combine(type)
        hasher.combine(logoURL)
    }

    // ✅ NEW: Firestore dictionary initializer
    static func fromFirestore(_ data: [String: Any], id: String) -> Challenge {
        return Challenge(
            id: id,
            title: data["title"] as? String ?? "",
            reward: data["reward"] as? String ?? "",
            achievements: (data["achievements"] as? [[String: Any]])?.compactMap {
                guard let type = $0["type"] as? String, let quantity = $0["quantity"] as? Int else { return nil }
                return ChallengeAchievement(type: type, quantity: quantity)
            } ?? [],
            startDate: (data["startDate"] as? Timestamp)?.dateValue() ?? Date(),
            endDate: (data["endDate"] as? Timestamp)?.dateValue() ?? Date(),
            sponsorID: data["sponsorID"] as? String ?? "",
            createdBy: data["createdBy"] as? String ?? "",
            assignedAthletes: data["assignedAthletes"] as? [String] ?? [],
            eventID: data["eventID"] as? String,
            desiredAgeGroups: data["desiredAgeGroups"] as? [String],
            type: data["type"] as? String,
            logoURL: data["logoURL"] as? String
        )
    }
}
