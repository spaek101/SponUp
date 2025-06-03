import Foundation

struct ReviewedSubmission: Identifiable {
    var id: String
    var challengeID: String
    var athleteID: String
    var athleteName: String
    var status: String
    var imageURLs: [String]
    var submittedAt: Date
}
