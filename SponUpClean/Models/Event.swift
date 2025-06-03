import SwiftUI
import FirebaseFirestoreSwift

struct Event: Identifiable, Codable {
    @DocumentID var id: String?
    var eventTitle: String
    var startDate: Date
    var endDate: Date
    var athleteID: String
}

// MARK: - Sample Data for Preview
extension Event {
    static let sampleEvent = Event(
        id: "event001",
        eventTitle: "Spring Invitational",
        startDate: Date(),
        endDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date(),
        athleteID: "athlete001"
    )
}
