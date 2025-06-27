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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(tasks) { task in
                        Button(action: {
                            task.action()
                        }) {
                            taskCard(task)
                        }
                    }

                    NavigationLink(
                        tag: loadedChallenge?.id ?? "",
                        selection: $selectedChallengeID,
                        destination: {
                            ChallengeDetailViewAthlete(challenge: loadedChallenge ?? Challenge.placeholder)
                        },
                        label: {
                            EmptyView()
                        }
                    )
                    .hidden()
                }
                .padding(.vertical)
                .padding(.horizontal)
            }
        }
        .navigationTitle("Tasks")
        .onAppear {
            // Reset navigation state when returning
            self.loadedChallenge = nil
            self.selectedChallengeID = nil
        }
    }


    private var tasks: [TaskItem] {
        var items: [TaskItem] = []

        if !hasEvents {
            items.append(
                TaskItem(
                    title: "Add an Event",
                    description: "Add your next event.",
                    icon: "calendar.badge.plus",
                    color: .blue,
                    action: {
                        navigateToView(AnyView(AddEventCalendarView()))
                    }
                )
            )
        }

        if !hasApprovedSponsors {
            items.append(
                TaskItem(
                    title: "Add a Sponsor",
                    description: "Add your first sponsor.",
                    icon: "person.crop.circle.badge.plus",
                    color: .purple,
                    action: {
                        navigateToView(AnyView(AddSponsorView(hasApprovedSponsors: .constant(false))))
                    }
                )
            )
        }

        if hasPendingSponsors {
            items.append(
                TaskItem(
                    title: "Pending Sponsor Request",
                    description: "Approve sponsor connection.",
                    icon: "person.crop.circle.badge.questionmark",
                    color: .orange,
                    action: {
                        navigateToView(AnyView(AddSponsorView(startOnPending: true, hasApprovedSponsors: .constant(false))))
                    }
                )
            )
        }

        if hasRejectedSubmissions {
            items.append(
                TaskItem(
                    title: "Rejected Submission",
                    description: "Tap to resubmit your result.",
                    icon: "tray.and.arrow.up.fill",
                    color: .red,
                    action: {
                        loadFirstRejectedChallenge()
                    }
                )
            )
        }

        items.append(
            TaskItem(
                title: "Upload Challenge Result",
                description: "Upload your challenge result.",
                icon: "tray.and.arrow.up.fill",
                color: .green,
                action: {
                    navigateToView(AnyView(SubmissionsTabContent()))
                }
            )
        )

        return items
    }

    private func navigateToView(_ view: AnyView) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.present(UIHostingController(rootView: view), animated: true)
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
                    .lineLimit(1)

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
            .getDocuments { snapshot, error in
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

                            let title = data["title"] as? String ?? "Untitled"
                            let startDate = (data["startDate"] as? Timestamp)?.dateValue() ?? Date()
                            let endDate = (data["endDate"] as? Timestamp)?.dateValue() ?? Date()

                            let challenge = Challenge(
                                id: challengeID,
                                title: title,
                                startDate: startDate,
                                endDate: endDate,
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
