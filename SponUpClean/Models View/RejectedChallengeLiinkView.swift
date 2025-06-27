import SwiftUI
import FirebaseFirestore

struct RejectedChallengeLinkView: View {
    @AppStorage("userID") private var userID: String = ""
    @State private var rejectedSubmission: Submission?
    @State private var challenge: Challenge?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let challenge = challenge {
                ChallengeDetailViewAthlete(challenge: challenge)
            } else if isLoading {
                ProgressView("Loading...")
            } else {
                Text("No rejected challenges found.")
                    .foregroundColor(.gray)
                    .padding()
            }
        }
        .onAppear {
            loadRejectedSubmission()
        }
    }

    private func loadRejectedSubmission() {
        let db = Firestore.firestore()
        db.collection("submissions")
            .whereField("athleteID", isEqualTo: userID)
            .whereField("status", isEqualTo: "rejected")
            .order(by: "submittedAt", descending: true)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                guard let doc = snapshot?.documents.first else {
                    isLoading = false
                    return
                }

                let data = doc.data()
                let challengeID = data["challengeID"] as? String ?? ""
                self.rejectedSubmission = Submission(id: doc.documentID, challengeID: challengeID)

                db.collection("challenges").document(challengeID).getDocument { snap, _ in
                    guard let challengeData = snap?.data() else {
                        isLoading = false
                        return
                    }
                    self.challenge = Challenge.fromFirestore(challengeData, id: challengeID)
                    isLoading = false
                }
            }
    }

    struct Submission {
        let id: String
        let challengeID: String
    }
}
