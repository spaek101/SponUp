import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct TaskItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: () -> Void
}

struct TasksView: View {
    var hasPendingSponsors: Bool
    var hasEvents: Bool
    var hasApprovedSponsors: Bool
    var hasRejectedSubmissions: Bool

    @State private var selectedChallengeID: String? = nil
    @State private var loadedChallenge: Challenge? = nil
    @State private var challengeTasks: [TaskItem] = []
    @State private var isPresentingEventView = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(tasks + challengeTasks) { task in
                        Button(action: {
                            task.action()
                        }) {
                            taskCard(task)
                        }
                    }

                    // Navigation to Challenge Detail
                    NavigationLink(
                        tag: loadedChallenge?.id ?? "",
                        selection: $selectedChallengeID,
                        destination: {
                            if let challenge = loadedChallenge {
                                ChallengeDetailViewAthlete(challenge: challenge)
                            } else {
                                EmptyView()
                            }
                        },
                        label: { EmptyView() }
                    ).hidden()

                    // Navigation to Add Event View
                    NavigationLink(
                        destination: AddEventCalendarView(),
                        isActive: $isPresentingEventView
                    ) {
                        EmptyView()
                    }
                    .hidden()
                }
                .padding(.vertical)
                .padding(.horizontal)
            }
            .navigationTitle("Tasks")
            .onAppear {
                self.loadedChallenge = nil
                self.selectedChallengeID = nil
                generateChallengeTasks()
            }
        }
    }

    private var tasks: [TaskItem] {
        var items: [TaskItem] = []

        if !hasEvents {
            items.append(TaskItem(
                title: "Add an Event",
                description: "Add your next event.",
                icon: "calendar.badge.plus",
                color: .blue,
                action: {
                    isPresentingEventView = true
                }
            ))
        }

        if !hasApprovedSponsors {
            items.append(TaskItem(
                title: "Add a Sponsor",
                description: "Add your first sponsor.",
                icon: "person.crop.circle.badge.plus",
                color: .purple,
                action: { navigateToView(AnyView(AddSponsorView(hasApprovedSponsors: .constant(false)))) }
            ))
        }

        if hasPendingSponsors {
            items.append(TaskItem(
                title: "Pending Sponsor Request",
                description: "Approve sponsor connection.",
                icon: "person.crop.circle.badge.questionmark",
                color: .orange,
                action: { navigateToView(AnyView(AddSponsorView(startOnPending: true, hasApprovedSponsors: .constant(true)))) }
            ))
        }

        if hasRejectedSubmissions {
            items.append(TaskItem(
                title: "Rejected Submission",
                description: "Tap to resubmit your result.",
                icon: "tray.and.arrow.up.fill",
                color: .red,
                action: { loadFirstRejectedChallenge() }
            ))
        }

        return items
    }

    private func generateChallengeTasks() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let now = Date()

        var newTasks: [TaskItem] = []
        let dispatchGroup = DispatchGroup()

        db.collection("challenges")
            .whereField("assignedAthletes", arrayContains: userID)
            .getDocuments { snapshot, error in
                guard let documents = snapshot?.documents, error == nil else { return }

                for doc in documents {
                    let data = doc.data()
                    let id = doc.documentID
                    let title = data["title"] as? String ?? "Untitled"
                    let startDate = (data["startDate"] as? Timestamp)?.dateValue() ?? Date()
                    let endDate = (data["endDate"] as? Timestamp)?.dateValue() ?? Date()

                    let challenge = Challenge.fromFirestore(data, id: id)

                    dispatchGroup.enter()

                    db.collection("submissions")
                        .whereField("challengeID", isEqualTo: id)
                        .whereField("athleteID", isEqualTo: userID)
                        .getDocuments { subSnap, _ in
                            let hasSubmitted = (subSnap?.documents.count ?? 0) > 0
                            let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: startDate) ?? startDate
                            let fiveDaysAfter = endDate.addingTimeInterval(5 * 86400)

                            let calendar = Calendar.current
                            let startOfToday = calendar.startOfDay(for: now)
                            let startOfChallenge = calendar.startOfDay(for: startDate)
                            let dayBeforeStart = calendar.date(byAdding: .day, value: -1, to: startOfChallenge)!
                            let endOfTomorrow = calendar.date(byAdding: .day, value: 1, to: dayBeforeStart)!

                            if now < dayBeforeStart {
                                newTasks.append(TaskItem(
                                    title: "New Challenge",
                                    description: title,
                                    icon: "flag.circle.fill",
                                    color: .green,
                                    action: {
                                        openChallenge(challenge)
                                    }
                                ))
                            }

                            if calendar.isDate(now, inSameDayAs: dayBefore) {
                                newTasks.append(TaskItem(
                                    title: "Starts Tomorrow",
                                    description: title,
                                    icon: "clock.fill",
                                    color: .orange,
                                    action: {
                                        openChallenge(challenge)
                                    }
                                ))
                            }

                            if now >= startDate && now <= endDate {
                                newTasks.append(TaskItem(
                                    title: "Challenge Ongoing",
                                    description: title,
                                    icon: "bolt.fill",
                                    color: .blue,
                                    action: {
                                        openChallenge(challenge)
                                    }
                                ))
                            }

                            if now > endDate && now <= fiveDaysAfter && !hasSubmitted {
                                newTasks.append(TaskItem(
                                    title: "Upload Challenge Result",
                                    description: title,
                                    icon: "tray.and.arrow.up.fill",
                                    color: .purple,
                                    action: {
                                        openChallenge(challenge)
                                    }
                                ))
                            }

                            dispatchGroup.leave()
                        }
                }

                dispatchGroup.notify(queue: .main) {
                    self.challengeTasks = newTasks
                }
            }
    }

    private func openChallenge(_ challenge: Challenge) {
        self.loadedChallenge = challenge
        self.selectedChallengeID = challenge.id
    }

    private func navigateToView(_ view: AnyView) {
        DispatchQueue.main.async {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = scene.windows.first,
               let rootVC = window.rootViewController {

                if let nav = rootVC as? UINavigationController {
                    nav.pushViewController(UIHostingController(rootView: view), animated: true)
                } else {
                    let nav = UINavigationController(rootViewController: UIHostingController(rootView: view))
                    rootVC.present(nav, animated: true)
                }
            }
        }
    }

    private func taskCard(_ task: TaskItem) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(task.color.opacity(0.2))
                    .frame(width: 48, height: 48)
                Image(systemName: task.icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(task.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.black)

                Text(task.description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 3)
        )
    }

    private func loadFirstRejectedChallenge() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()

        db.collection("challenges")
            .whereField("assignedAthletes", arrayContains: userID)
            .getDocuments { snapshot, _ in
                guard let documents = snapshot?.documents else { return }

                for doc in documents {
                    let data = doc.data()
                    let challengeID = doc.documentID

                    db.collection("submissions")
                        .whereField("challengeID", isEqualTo: challengeID)
                        .whereField("athleteID", isEqualTo: userID)
                        .whereField("status", isEqualTo: "Rejected")
                        .limit(to: 1)
                        .getDocuments { subSnap, _ in
                            guard let _ = subSnap?.documents.first else { return }

                            let challenge = Challenge(
                                id: challengeID,
                                title: data["title"] as? String ?? "Untitled",
                                startDate: (data["startDate"] as? Timestamp)?.dateValue() ?? Date(),
                                endDate: (data["endDate"] as? Timestamp)?.dateValue() ?? Date(),
                                sponsorID: data["sponsorID"] as? String ?? "",
                                createdBy: data["createdBy"] as? String ?? "",
                                assignedAthletes: data["assignedAthletes"] as? [String] ?? [],
                                eventID: data["eventID"] as? String,
                                desiredAgeGroups: data["desiredAgeGroups"] as? [String],
                                type: data["type"] as? String,
                                logoURL: data["logoURL"] as? String
                            )

                            DispatchQueue.main.async {
                                self.loadedChallenge = challenge
                                self.selectedChallengeID = challenge.id
                            }
                        }
                }
            }
    }
}
