import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct MySubmissionsView: View {
    @AppStorage("userRole") var userRole: String = "athlete"
    @AppStorage("hasSeenSwipeTip") var hasSeenSwipeTip: Bool = false
    @State private var submissions: [SubmissionDisplay] = []
    @State private var isLoading = true
    @State private var selectedFilter: String = "Show All"
    @State private var hasRejected: Bool = false

    let filterOptions = ["Show All", "Pending", "Approved", "Rejected", "Rewarded"]

    var filteredSubmissions: [SubmissionDisplay] {
        if selectedFilter == "Show All" {
            return submissions
        } else {
            return submissions.filter { $0.submission.status.lowercased() == selectedFilter.lowercased() }
        }
    }

    var body: some View {
        if userRole != "athlete" {
            Text("You need to be logged in as an athlete to view submissions.")
                .padding()
                .foregroundColor(.red)
        } else {
            NavigationStack {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("My Submissions")
                            .font(.largeTitle)
                            .bold()
                            .padding(.horizontal)

                        ZStack {
                            Picker("Filter by:", selection: $selectedFilter) {
                                ForEach(filterOptions, id: \.self) { option in
                                    Text(option).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)

                            if hasRejected {
                                GeometryReader { geo in
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 10, height: 10)
                                        .offset(x: geo.size.width * 0.72, y: -2) // ⬅️ Adjust this value to fine-tune dot position
                                }
                                .allowsHitTesting(false)
                            }
                        }
                        .frame(height: 36)


                    }

                    if !hasSeenSwipeTip && !filteredSubmissions.isEmpty {
                        Text("👈 Swipe left to delete a submission")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                            .transition(.opacity)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                                    withAnimation {
                                        hasSeenSwipeTip = true
                                    }
                                }
                            }
                    }

                    if isLoading {
                        ProgressView("Loading submissions...")
                            .padding()
                        Spacer()
                    } else if filteredSubmissions.isEmpty {
                        Text("No submissions available.")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .padding()
                        Spacer()
                    } else {
                        List {
                            ForEach(filteredSubmissions) { item in
                                if let challenge = item.challenge {
                                    NavigationLink(destination: ChallengeDetailViewAthlete(challenge: challenge)) {
                                        SubmissionCard(item: item)
                                    }
                                } else {
                                    SubmissionCard(item: item)
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                }
                .padding(.top)
                .onAppear(perform: fetchSubmissions)
            }
        }
    }

    private func fetchSubmissions() {
        guard let athleteID = Auth.auth().currentUser?.uid else {
            print("❌ No logged in user")
            self.isLoading = false
            return
        }

        let db = Firestore.firestore()
        db.collection("submissions")
            .whereField("athleteID", isEqualTo: athleteID)
            .getDocuments { snapshot, error in
                defer { self.isLoading = false }

                if let error = error {
                    print("❌ Error fetching submissions: \(error.localizedDescription)")
                    return
                }

                guard let docs = snapshot?.documents else { return }

                var fetched: [SubmissionDisplay] = []
                var foundRejected = false
                let dispatchGroup = DispatchGroup()

                for doc in docs {
                    let data = doc.data()
                    let challengeID = data["challengeID"] as? String ?? "unknown"
                    let imageURLs = data["imageURLs"] as? [String] ?? []
                    let status = data["status"] as? String ?? "Pending"
                    let submittedAt = (data["submittedAt"] as? Timestamp)?.dateValue() ?? Date()

                    if status.lowercased() == "rejected" {
                        foundRejected = true
                    }

                    dispatchGroup.enter()
                    db.collection("challenges").document(challengeID).getDocument { challengeSnap, _ in
                        defer { dispatchGroup.leave() }

                        guard let challengeData = challengeSnap?.data() else { return }

                        let title = challengeData["title"] as? String ?? "Untitled"
                        let reward = challengeData["reward"] as? String ?? "No reward"
                        let achievementsData = challengeData["achievements"] as? [[String: Any]] ?? []
                        let achievements = achievementsData.compactMap { dict -> ChallengeAchievement? in
                            guard let type = dict["type"] as? String,
                                  let quantity = dict["quantity"] as? Int else { return nil }
                            return ChallengeAchievement(type: type, quantity: quantity)
                        }

                        let startDate = (challengeData["startDate"] as? Timestamp)?.dateValue() ?? Date()
                        let endDate = (challengeData["endDate"] as? Timestamp)?.dateValue() ?? Date()
                        let sponsorID = challengeData["sponsorID"] as? String ?? ""
                        let createdBy = challengeData["createdBy"] as? String ?? ""
                        let assignedAthletes = challengeData["assignedAthletes"] as? [String] ?? []

                        let challenge = Challenge(
                            id: challengeSnap?.documentID,
                            title: title,
                            reward: reward,
                            achievements: achievements,
                            startDate: startDate,
                            endDate: endDate,
                            sponsorID: sponsorID,
                            createdBy: createdBy,
                            assignedAthletes: assignedAthletes
                        )

                        let display = SubmissionDisplay(
                            id: doc.documentID,
                            challengeTitle: title,
                            challengeID: challengeID,
                            reward: reward,
                            challenge: challenge,
                            submission: SubmissionInfo(
                                imageURLs: imageURLs,
                                status: status,
                                submittedAt: submittedAt
                            )
                        )

                        fetched.append(display)
                    }
                }

                dispatchGroup.notify(queue: .main) {
                    self.submissions = fetched.sorted { $0.submission.submittedAt > $1.submission.submittedAt }
                    self.hasRejected = foundRejected
                }
            }
    }
}

struct SubmissionCard: View {
    let item: SubmissionDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.challengeTitle)
                .font(.headline)

            Text("Challenge ID: \(item.challengeID)")
                .font(.caption)
                .foregroundColor(.gray)

            Text("Reward: \(item.reward)")
                .font(.subheadline)

            Text("Status: \(item.submission.status)")
                .font(.footnote)
                .foregroundColor(statusColor(for: item.submission.status))
        }
        .padding(.vertical, 6)
    }

    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "pending": return .orange
        case "approved": return .blue
        case "rejected": return .red
        case "rewarded": return .green
        default: return .gray
        }
    }
}

struct SubmissionDisplay: Identifiable {
    var id: String
    var challengeTitle: String
    var challengeID: String
    var reward: String
    var challenge: Challenge?
    var submission: SubmissionInfo
}

struct SubmissionInfo {
    var imageURLs: [String]
    var status: String
    var submittedAt: Date
}
