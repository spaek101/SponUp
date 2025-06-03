import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ReviewSubmissionsView: View {
    @State private var challengeSubmissions: [ChallengeWithSubmissions] = []
    @State private var filteredOpenSubmissions: [ChallengeWithSubmissions] = []
    @State private var filteredPastSubmissions: [ChallengeWithSubmissions] = []
    @State private var isLoading = true
    @Binding var challenges: [Challenge]  // Ensure this is a binding

    var body: some View {
        NavigationView {
            TabView {
                // Open Submissions Tab
                VStack {
                    if isLoading {
                        ProgressView("Loading submissions...")
                            .padding()
                    } else if filteredOpenSubmissions.isEmpty {
                        // Display message when no open submissions
                        Text("You don't have any open submissions.")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .padding(.top, 50)
                    } else {
                        List {
                            ForEach(filteredOpenSubmissions) { challenge in
                                Section(header: Text(challenge.title)) {
                                    ForEach(challenge.submissions) { submission in
                                        NavigationLink(
                                            destination: ReviewSubmissionDetailView(
                                                challengeID: challenge.id,
                                                submission: submission
                                            )
                                        ) {
                                            HStack {
                                                Text(submission.athleteName)
                                                Spacer()
                                                Text(submission.status.capitalized)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(InsetGroupedListStyle())
                    }
                }
                .tabItem {
                    Label("Open", systemImage: "circle.fill") // Same icon as in AthleteChallengesView
                }

                // Past Submissions Tab
                VStack {
                    if isLoading {
                        ProgressView("Loading submissions...")
                            .padding()
                    } else if filteredPastSubmissions.isEmpty {
                        // Display message when no past submissions
                        Text("You don't have any past submissions.")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .padding(.top, 50)
                    } else {
                        List {
                            ForEach(filteredPastSubmissions) { challenge in
                                Section(header: Text(challenge.title)) {
                                    ForEach(challenge.submissions) { submission in
                                        NavigationLink(
                                            destination: ReviewSubmissionDetailView(
                                                challengeID: challenge.id,
                                                submission: submission
                                            )
                                        ) {
                                            HStack {
                                                Text(submission.athleteName)
                                                Spacer()
                                                Text(submission.status.capitalized)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(InsetGroupedListStyle())
                    }
                }
                .tabItem {
                    Label("Past", systemImage: "circle.slash.fill") // Same icon as in AthleteChallengesView
                }
            }
            .navigationTitle("Review Submissions")
            .onAppear(perform: loadSubmissions)
        }
    }

    private func loadSubmissions() {
        guard let sponsorID = Auth.auth().currentUser?.uid else {
            print("❌ No sponsor logged in")
            return
        }

        print("📢 Current sponsorID: \(sponsorID)")

        let db = Firestore.firestore()
        db.collection("challenges")
            .whereField("createdBy", isEqualTo: sponsorID)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error fetching challenges: \(error.localizedDescription)")
                    self.isLoading = false
                    return
                }

                guard let docs = snapshot?.documents else {
                    print("⚠️ No challenges found for sponsorID: \(sponsorID)")
                    self.isLoading = false
                    return
                }

                print("✅ Found \(docs.count) challenges created by sponsor.")

                let challenges = docs.map {
                    ChallengeWithSubmissions(
                        id: $0.documentID,
                        title: $0.data()["title"] as? String ?? "Untitled",
                        endDate: ($0.data()["endDate"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }

                let group = DispatchGroup()
                var fullResults: [ChallengeWithSubmissions] = []

                for var challenge in challenges {
                    group.enter()

                    db.collection("submissions")
                        .whereField("challengeID", isEqualTo: challenge.id)
                        .getDocuments { snap, err in
                            if let err = err {
                                print("❌ Error fetching submissions: \(err.localizedDescription)")
                                group.leave()
                                return
                            }

                            guard let submissionDocs = snap?.documents else {
                                print("⚠️ No submissions for challengeID: \(challenge.id)")
                                group.leave()
                                return
                            }

                            print("📦 Found \(submissionDocs.count) submissions for challengeID: \(challenge.id)")

                            let submissions = submissionDocs.compactMap { doc -> ReviewedSubmission? in
                                let data = doc.data()
                                let athleteID = data["athleteID"] as? String ?? "unknown"
                                let status = (data["status"] as? String ?? "Pending").capitalized
                                let imageURLs = data["imageURLs"] as? [String] ?? [] // Expecting an array of image URLs
                                let submittedAt = (data["submittedAt"] as? Timestamp)?.dateValue() ?? Date()

                                return ReviewedSubmission(
                                    id: doc.documentID,
                                    challengeID: challenge.id,
                                    athleteID: athleteID,
                                    athleteName: "", // We'll resolve the athlete name later
                                    status: status,
                                    imageURLs: imageURLs, // Pass the array of URLs
                                    submittedAt: submittedAt
                                )
                            }

                            let athleteGroup = DispatchGroup()
                            var submissionsWithNames: [ReviewedSubmission] = submissions

                            for i in submissions.indices {
                                athleteGroup.enter()
                                let athleteID = submissions[i].athleteID

                                db.collection("users").document(athleteID).getDocument { userDoc, _ in
                                    if let userData = userDoc?.data() {
                                        let first = userData["firstName"] as? String ?? ""
                                        let last = userData["lastName"] as? String ?? ""
                                        submissionsWithNames[i].athleteName = "\(first) \(last)"
                                        print("👤 Resolved athlete name: \(first) \(last)")
                                    } else {
                                        print("⚠️ No user found for athleteID: \(athleteID)")
                                    }
                                    athleteGroup.leave()
                                }
                            }

                            athleteGroup.notify(queue: .main) {
                                challenge.submissions = submissionsWithNames

                                print("🔎 DEBUG — Submissions with names for \(challenge.title):")
                                for s in challenge.submissions {
                                    print("➡️ Athlete: \(s.athleteName), Status: \(s.status)")
                                }

                                if !challenge.submissions.isEmpty {
                                    print("✅ Challenge '\(challenge.title)' has \(challenge.submissions.count) valid submissions.")
                                    fullResults.append(challenge)
                                } else {
                                    print("🚫 Challenge '\(challenge.title)' has NO valid submissions.")
                                }

                                group.leave()
                            }

                        }
                }

                group.notify(queue: .main) {
                    fullResults.sort {
                        let timeRemaining1 = $0.endDate.timeIntervalSinceNow
                        let timeRemaining2 = $1.endDate.timeIntervalSinceNow
                        return timeRemaining1 < timeRemaining2
                    }

                    self.challengeSubmissions = fullResults
                    self.filterSubmissions()
                    self.isLoading = false
                }
            }
    }

    private func filterSubmissions() {
        let currentDate = Date()
        let gracePeriod: TimeInterval = 5 * 24 * 60 * 60 // 5 days in seconds

        filteredOpenSubmissions = challengeSubmissions.filter { challenge in
            let cutoffDate = challenge.endDate.addingTimeInterval(gracePeriod)
            return cutoffDate > currentDate
        }

        filteredPastSubmissions = challengeSubmissions.filter { challenge in
            let cutoffDate = challenge.endDate.addingTimeInterval(gracePeriod)
            return cutoffDate <= currentDate
        }

        print("🧪 filterSubmissions - total open: \(filteredOpenSubmissions.count), total past: \(filteredPastSubmissions.count)")

        for c in filteredOpenSubmissions {
            print("📌 Open Challenge: \(c.title) | Submissions: \(c.submissions.count)")
        }

        for c in filteredPastSubmissions {
            print("📌 Past Challenge: \(c.title) | Submissions: \(c.submissions.count)")
        }
    }

}

// MARK: - Models

struct ChallengeWithSubmissions: Identifiable {
    var id: String
    var title: String
    var endDate: Date
    var submissions: [ReviewedSubmission] = []
}
