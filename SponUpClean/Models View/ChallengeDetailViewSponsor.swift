import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseAuth

struct ChallengeDetailViewSponsor: View {
    let challenge: Challenge
    @AppStorage("userRole") var userRole: String = ""
    @State private var athletes: [String] = []
    @State private var showDeleteAlert = false
    @State private var createdChallenges: [String: Bool] = [:]
    @Binding var challenges: [Challenge]

    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(challenge.title)
                    .font(.title)
                    .bold()

                Text("Achievements: \(challenge.achievements.map { "\($0.quantity)x \($0.type)" }.joined(separator: ", "))")
                Text("Reward: \(challenge.reward)")
                Text("Start: \(challenge.startDate.formatted(date: .abbreviated, time: .omitted))")
                Text("End: \(challenge.endDate.formatted(date: .abbreviated, time: .omitted))")

                if challenge.endDate > Date() {
                    Text("Time Left: \(timeRemaining(to: challenge.endDate))")
                        .foregroundColor(.orange)
                } else {
                    Text("Challenge Expired")
                        .foregroundColor(.red)
                }

                Divider()

                Text("Assigned Athletes:")
                    .font(.headline)
                    .padding(.top, 10)

                ForEach(athletes, id: \.self) { athlete in
                    Text(athlete)
                        .font(.subheadline)
                        .padding(.vertical, 2)
                }

                Divider()

                Button("Delete Challenge") {
                    showDeleteAlert = true
                }
                .foregroundColor(.red)
                .padding()
            }
            .padding()
        }
        .navigationBarHidden(true)
        .onAppear {
            fetchAthletes()
            checkIfChallengeExists()
        }
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("Delete Challenge"),
                message: Text("Are you sure you want to delete this challenge? This cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    deleteChallenge()
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func timeRemaining(to endDate: Date) -> String {
        let now = Date()
        let diff = Calendar.current.dateComponents([.day, .hour, .minute], from: now, to: endDate)
        return "\(diff.day ?? 0)d \(diff.hour ?? 0)h \(diff.minute ?? 0)m"
    }

    private func deleteChallenge() {
        guard let challengeID = challenge.id else { return }

        let db = Firestore.firestore()
        db.collection("challenges").document(challengeID).delete { error in
            if let error = error {
                print("❌ Failed to delete challenge: \(error.localizedDescription)")
            } else {
                print("✅ Challenge deleted successfully")
                updateButtonStateForChallengeDeletion(challengeID: challengeID)

                if let index = challenges.firstIndex(where: { $0.id == challengeID }) {
                    challenges.remove(at: index)
                }

                // ✅ Dismiss the view using the modern approach
                dismiss()
            }
        }
    }

    private func fetchAthletes() {
        guard let challengeID = challenge.id else { return }

        let db = Firestore.firestore()
        db.collection("challenges").document(challengeID)
            .getDocument { snapshot, error in
                if let error = error {
                    print("❌ Error fetching athletes: \(error.localizedDescription)")
                    return
                }

                guard let data = snapshot?.data() else { return }
                let assignedAthletes = data["assignedAthletes"] as? [String] ?? []

                var athletesWithNames: [String] = []
                let group = DispatchGroup()

                for athleteID in assignedAthletes {
                    group.enter()
                    db.collection("users").document(athleteID).getDocument { userDoc, _ in
                        if let userData = userDoc?.data() {
                            let firstName = userData["firstName"] as? String ?? ""
                            let lastName = userData["lastName"] as? String ?? ""
                            let fullName = "\(firstName) \(lastName)"
                            athletesWithNames.append(fullName)
                        }
                        group.leave()
                    }
                }

                group.notify(queue: .main) {
                    self.athletes = athletesWithNames
                }
            }
    }

    private func checkIfChallengeExists() {
        guard let challengeID = challenge.id else { return }

        let db = Firestore.firestore()
        db.collection("challenges").document(challengeID).getDocument { snapshot, error in
            if let error = error {
                print("❌ Error checking challenge: \(error.localizedDescription)")
                return
            }

            createdChallenges[challengeID] = snapshot?.exists ?? false
        }
    }

    private func updateButtonStateForChallengeDeletion(challengeID: String) {
        createdChallenges[challengeID] = false
    }
}
