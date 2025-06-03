import SwiftUI
import FirebaseFirestoreSwift

// Define the Athlete struct
struct Athlete: Identifiable, Codable, Hashable {
    var id: String           // Unique identifier for the athlete
    var firstName: String    // Athlete's first name
    var lastName: String     // Athlete's last name
    
    // You can add additional properties for athlete data if needed
}
