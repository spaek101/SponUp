import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct ChallengeSubmissionsDetailView: View {
    let challenge: Challenge
    var onDelete: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = true
    @State private var athleteNames: [String: String] = [:]
    @State private var submissionStatuses: [String: SubmissionStatus?] = [:]
    @State private var showDeleteAlert = false
    @State private var deleteMessage = "This action cannot be undone and it will also be removed from the Athlete's view."

    let achievementDescriptions: [String: String] = [
        "1B": "Single", "2B": "Double", "3B": "Triple", "HR": "Home Run", "RBI": "Runs Batted In",
        "BB": "Walk", "HBP": "Hit By Pitch", "K": "Strikeout", "AVG": "Batting Average", "OBP": "On-Base Percentage", "SLG": "Slugging Percentage",
        "IP": "Innings Pitched", "K-P": "Pitcher Strikeouts", "BB-P": "Walks Allowed", "ER": "Earned Runs",
        "CG": "Complete Game", "QS": "Quality Start", "W": "Win", "SV": "Save",
        "ERA": "Earned Run Average", "WHIP": "Walks+Hits/IP", "POFF": "Pitcher Pickoff",
        "PickedOff": "Picked Off", "PO": "Putout", "A": "Assist", "E": "Error", "DP": "Double Play", "U": "Unassisted",
        "CSF": "Caught Stealing Field", "FPCT": "Fielding %", "ThrowOut": "Runner Thrown Out",
        "PB": "Passed Ball", "SB-Allowed": "Stolen Bases Allowed", "CS-Catcher": "Caught Stealing (Catcher)",
        "R": "Runs", "SB": "Stolen Base", "Cycle": "1B, 2B, 3B, HR", "DIV": "Diving Play",
        "SHO": "Shutout", "NH": "No-Hitter", "TO": "Runner Thrown Out"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(challenge.title)
                    .font(.title)
                    .bold()

                Text("🏆 Reward: \(challenge.reward)")
                Text("📆 Start: \(challenge.startDate.formatted(date: .abbreviated, time: .omitted))")
                Text("📆 End: \(challenge.endDate.formatted(date: .abbreviated, time: .omitted))")

                Text("📋 Achievements required:")
                    .font(.headline)

                ForEach(challenge.achievements, id: \.self) { achievement in
                    AchievementText(achievement: achievement, descriptions: achievementDescriptions)
                }

                Divider()

                Text("📸 Submission Status")
                    .font(.title3)
                    .bold()

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                } else {
                    ForEach(challenge.assignedAthletes, id: \.self) { athleteID in
                        let name = athleteNames[athleteID] ?? "Unknown Athlete"
                        let status = submissionStatuses[athleteID] ?? nil

                        HStack {
                            Text(name)
                                .font(.subheadline)
                            Spacer()
                            Text(status?.rawValue ?? "Empty")
                                .font(.subheadline)
                                .foregroundColor(color(for: status))
                        }
                    }
                }

                if challenge.assignedAthletes.isEmpty {
                    Text("No athletes assigned yet.")
                        .italic()
                        .foregroundColor(.gray)
                }

                Divider()

                Button(action: {
                    showDeleteAlert = true
                }) {
                    Text("Delete Challenge")
                        .foregroundColor(.red)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                }
                .padding(.top)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadAthletes()
        }
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("Are you sure you want to delete this challenge?"),
                message: Text(deleteMessage),
                primaryButton: .destructive(Text("Delete")) {
                    deleteChallenge()
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func deleteChallenge() {
        let db = Firestore.firestore()
        db.collection("challenges").document(challenge.id ?? "").delete { error in
            if let error = error {
                print("❌ Error deleting challenge: \(error.localizedDescription)")
            } else {
                print("✅ Challenge deleted successfully")
                onDelete?()
                dismiss()
            }
        }
    }

    private func loadAthletes() {
        let db = Firestore.firestore()

        for athleteID in challenge.assignedAthletes {
            db.collection("users").document(athleteID).getDocument { doc, error in
                if let doc = doc, let data = doc.data() {
                    let firstName = data["firstName"] as? String ?? "Unknown"
                    let lastName = data["lastName"] as? String ?? "Unknown"
                    athleteNames[athleteID] = "\(firstName) \(lastName)"
                }
            }

            db.collection("submissions")
                .whereField("athleteID", isEqualTo: athleteID)
                .whereField("challengeID", isEqualTo: challenge.id ?? "")
                .getDocuments { snapshot, error in
                    if let docs = snapshot?.documents, let firstDoc = docs.first {
                        let status = SubmissionStatus(rawValue: firstDoc["status"] as? String ?? "")
                        submissionStatuses[athleteID] = status
                    } else {
                        submissionStatuses[athleteID] = nil // No submission = "Empty"
                    }
                }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isLoading = false
        }
    }

    private func color(for status: SubmissionStatus?) -> Color {
        switch status {
        case .pending: return .orange
        case .approved: return .blue
        case .rejected: return .red
        case .rewarded: return .green
        case .none: return .gray // No submission
        }
    }
}

struct AchievementText: View {
    let achievement: ChallengeAchievement
    let descriptions: [String: String]

    var body: some View {
        let description = descriptions[achievement.type] ?? ""
        Text("- \(achievement.quantity)x \(achievement.type)\(description.isEmpty ? "" : " (\(description))")")
            .font(.subheadline)
    }
}
