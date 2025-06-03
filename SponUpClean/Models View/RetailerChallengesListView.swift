import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct RetailerChallengesListView: View {
    @AppStorage("userID") var userID: String = ""
    @State private var challenges: [ChallengeInfo] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("My Posted Challenges")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top)

                ForEach(challenges, id: \.title) { challenge in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(challenge.title)
                            .font(.headline)

                        Text("Reward: \(challenge.reward)")
                        Text("Start: \(challenge.startDate.formatted(date: .abbreviated, time: .omitted))")
                        Text("End: \(challenge.endDate.formatted(date: .abbreviated, time: .omitted))")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }

                if challenges.isEmpty {
                    Text("No challenges posted yet.")
                        .foregroundColor(.gray)
                }
            }
            .padding()
        }
        .onAppear {
            fetchChallenges()
        }
    }

    private func fetchChallenges() {
        let db = Firestore.firestore()
        print("🔍 Fetching challenges for userID: \(userID)")

        db.collection("challenges")
            .whereField("createdBy", isEqualTo: userID)
            .order(by: "startDate", descending: true)
            .getDocuments { (querySnapshot, error) in
                if let error = error {
                    print("❌ Firestore query error: \(error.localizedDescription)")
                } else if let querySnapshot = querySnapshot {
                    print("✅ Query executed. Documents found: \(querySnapshot.documents.count)")

                    self.challenges = querySnapshot.documents.compactMap { doc in
                        let data = doc.data()
                        return ChallengeInfo(
                            title: data["title"] as? String ?? "",
                            reward: data["reward"] as? String ?? "",
                            achievements: [],
                            startDate: (data["startDate"] as? Timestamp)?.dateValue() ?? Date(),
                            endDate: (data["endDate"] as? Timestamp)?.dateValue() ?? Date()
                        )
                    }
                }
            }
    }

}
