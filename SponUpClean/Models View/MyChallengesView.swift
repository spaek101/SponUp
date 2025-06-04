import SwiftUI
import FirebaseFirestore

struct MyChallengesView: View {
    @AppStorage("userRole") var userRole: String = ""
    @AppStorage("userID") var userID: String = ""

    @State var challenges: [Challenge] = []

    @State private var selectedFilter: ChallengeFilter = .current
    @State private var timers: [String: Timer] = [:]
    @State private var remainingTimes: [String: String] = [:]

    enum ChallengeFilter: String, CaseIterable {
        case current = "Current"
        case expired = "Expired"
    }

    private var filteredChallenges: [Challenge] {
        let now = Date()
        return challenges.filter { challenge in
            guard challenge.createdBy == userID else { return false }
            let expired = challenge.endDate.addingTimeInterval(5 * 86400) <= now
            let rewarded = !challenge.submissions.isEmpty && challenge.submissions.allSatisfy { $0.status == .rewarded }

            switch selectedFilter {
            case .current: return !rewarded && !expired
            case .expired: return rewarded || expired
            }
        }.sorted { $0.endDate < $1.endDate }
    }

    var body: some View {
        NavigationView {
            TabView(selection: $selectedFilter) {
                ForEach(ChallengeFilter.allCases, id: \.self) { filter in
                    VStack {
                        if filteredChallenges.isEmpty {
                            Text("You don't have any challenges to display.")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .padding(.top, 50)
                        } else {
                            List {
                                ForEach(filteredChallenges) { challenge in
                                    NavigationLink(
                                        destination: ChallengeSubmissionsDetailView(
                                            challenge: challenge,
                                            onDelete: {
                                                challenges.removeAll { $0.id == challenge.id }
                                            }
                                        )
                                    ) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(challenge.title)
                                                .font(.headline)
                                                .foregroundColor(.black)

                                            Text("Reward: \(challenge.reward ?? "")")

                                                .font(.subheadline)

                                            Text(assignedToText(for: challenge))
                                                .font(.footnote)
                                                .foregroundColor(.gray)

                                            HStack {
                                                Text("Time Left: \(remainingTimes[challenge.id ?? ""] ?? "Calculating...")")
                                                    .font(.subheadline)
                                                    .foregroundColor(.red)
                                                Spacer() // Pushes content left
                                            }
                                        }
                                        .padding(.vertical, 4)

                                    }
                                }
                            }
                            .listStyle(InsetGroupedListStyle())
                        }
                    }
                    .tabItem {
                        if filter == .current {
                            Label("Current", systemImage: "circle.fill")
                        } else {
                            Label("Expired", systemImage: "circle.slash.fill")
                        }
                    }
                    .tag(filter)
                }
            }
            .navigationTitle("My Challenges")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                startTimers()
            }
            .onDisappear {
                invalidateTimers()
            }
        }
    }

    func assignedToText(for challenge: Challenge) -> String {
        let count = challenge.assignedAthletes.count
        guard count > 0 else { return "Assigned to: None" }

        let firstAthleteLabel = "Athlete"
        
        if count == 1 {
            return "Assigned to: \(firstAthleteLabel)"
        } else {
            return "Assigned to: \(firstAthleteLabel) +\(count - 1) athlete\(count - 1 > 1 ? "s" : "")"
        }
    }

    func startTimers() {
        for challenge in challenges {
            let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                updateRemainingTime(for: challenge)
            }
            timers[challenge.id ?? ""] = timer
        }
    }

    func updateRemainingTime(for challenge: Challenge) {
        let now = Date()
        let adjustedEndDate = challenge.endDate.addingTimeInterval(5 * 86400)
        let timeRemaining = adjustedEndDate.timeIntervalSince(now)

        if !challenge.submissions.isEmpty && challenge.submissions.allSatisfy({ $0.status == .rewarded }) {
            remainingTimes[challenge.id ?? ""] = "Closed"
        } else if timeRemaining <= 0 {
            remainingTimes[challenge.id ?? ""] = "Expired"
        } else {
            let days = Int(timeRemaining) / 86400
            let hours = (Int(timeRemaining) % 86400) / 3600
            let minutes = (Int(timeRemaining) % 3600) / 60
            remainingTimes[challenge.id ?? ""] = String(format: "%dd %02dh %02dm", days, hours, minutes)
        }
    }

    func invalidateTimers() {
        for timer in timers.values {
            timer.invalidate()
        }
        timers.removeAll()
    }
}
