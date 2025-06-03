import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct CreateChallengeView: View {
    @AppStorage("userID") var userID: String = ""
    @Binding var sponsoredAthletes: [Athlete]
    @Binding var challenges: [Challenge]

    var event: Event?
    var preselectedAthletes: [Athlete] = []

    @State private var challengeTitle = ""
    @State private var customChallengeInput = ""
    @State private var customChallenges: [String] = []
    @State private var reward = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var assignedAthletes: [String] = []
    @State private var athleteSearch = ""
    @State private var showAlert = false

    var body: some View {
        NavigationView {
            Form {

                Section(header: Text("Challenge Title")) {
                    if event != nil {
                        Text(challengeTitle)
                            .foregroundColor(.primary) // default black/dark based on system mode
                            .onAppear {
                                self.challengeTitle = event?.eventTitle ?? ""
                                self.startDate = event?.startDate ?? Date()
                                self.endDate = event?.endDate ?? Date()
                                self.assignedAthletes = preselectedAthletes.map { $0.id }
                            }
                    } else {
                        TextField("e.g. Weekend Slugger Goal", text: $challengeTitle)
                    }
                }

                Section(header: Text("Challenge Descriptions")) {
                    HStack {
                        TextField("Enter a challenge description", text: $customChallengeInput)
                        
                        Button("Add") {
                            let trimmed = customChallengeInput.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                customChallenges.append(trimmed)
                                customChallengeInput = ""
                            }
                        }
                        .disabled(customChallengeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(customChallengeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }


                    ForEach(Array(customChallenges.enumerated()), id: \.offset) { index, challenge in
                        HStack {
                            Text("• \(challenge)")
                            Spacer()
                            Button(action: {
                                customChallenges.remove(at: index)
                            }) {
                                Image(systemName: "x.circle")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }

                Section(header: Text("Reward")) {
                    TextField("e.g. $25 Gift Card", text: $reward)
                }

                Section {
                    if event != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Start: \(formattedDateOnly(startDate))")
                            Text("End: \(formattedDateOnly(endDate))")
                        }

                    } else {
                        VStack {
                            DatePicker("Start", selection: $startDate, in: Date()..., displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .onChange(of: startDate) { newValue in
                                    if endDate < newValue {
                                        endDate = newValue
                                    }
                                }

                            DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: .date)
                                .datePickerStyle(.compact)
                        }
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("EVENT DATES")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("* Athlete has 5 days to submit results after end date.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .textCase(nil)
                    }
                    .padding(.top, 8)
                }

                Section(header: Text("Search and Add Athletes")) {
                    TextField("Search athlete name or ID", text: $athleteSearch)

                    if filteredAthletes.isEmpty {
                        Text("Name not found.")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(filteredAthletes, id: \.id) { athlete in
                            athleteRow(for: athlete)
                        }
                    }
                }

                if !assignedAthletes.isEmpty {
                    Section(header: Text("Assigned Athletes")) {
                        ForEach(
                            assignedAthletes.compactMap { id in
                                sponsoredAthletes.first(where: { $0.id == id })
                            }
                            .sorted {
                                $0.firstName.localizedCaseInsensitiveCompare($1.firstName) == .orderedAscending ||
                                ($0.firstName == $1.firstName && $0.lastName.localizedCaseInsensitiveCompare($1.lastName) == .orderedAscending)
                            },
                            id: \.id
                        ) { athlete in
                            Text("• \(athlete.firstName) \(athlete.lastName)")
                        }
                    }
                }

                Button("Create Challenge") {
                    saveChallenge()
                }
                .disabled(challengeTitle.isEmpty || reward.isEmpty || customChallenges.isEmpty || assignedAthletes.isEmpty)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(challengeTitle.isEmpty || reward.isEmpty || customChallenges.isEmpty || assignedAthletes.isEmpty ? Color.gray : Color.blue)
                .cornerRadius(8)
            }
            .navigationTitle("Create Challenge")
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Success"),
                    message: Text("Challenge created!"),
                    dismissButton: .default(Text("OK")) {
                        resetForm()
                    }
                )
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func athleteRow(for athlete: Athlete) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text("\(athlete.firstName) \(athlete.lastName)")
                Text("ID: \(athlete.id)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Button(action: {
                if assignedAthletes.contains(athlete.id) {
                    assignedAthletes.removeAll { $0 == athlete.id }
                } else {
                    assignedAthletes.append(athlete.id)
                }
            }) {
                Image(systemName: assignedAthletes.contains(athlete.id) ? "checkmark.circle.fill" : "plus.circle")
                    .foregroundColor(.blue)
            }
            .disabled(preselectedAthletes.contains(where: { $0.id == athlete.id }))
        }
    }

    private var filteredAthletes: [Athlete] {
        sponsoredAthletes
            .filter {
                athleteSearch.isEmpty ||
                $0.firstName.localizedCaseInsensitiveContains(athleteSearch) ||
                $0.lastName.localizedCaseInsensitiveContains(athleteSearch) ||
                $0.id.localizedCaseInsensitiveContains(athleteSearch)
            }
            .sorted {
                $0.firstName.localizedCaseInsensitiveCompare($1.firstName) == .orderedAscending ||
                ($0.firstName == $1.firstName && $0.lastName.localizedCaseInsensitiveCompare($1.lastName) == .orderedAscending)
            }
    }

    private func saveChallenge() {
        let achievementObjects = customChallenges.map {
            ChallengeAchievement(type: $0, quantity: 1)
        }

        let newChallenge = Challenge(
            title: challengeTitle,
            reward: reward,
            achievements: achievementObjects,
            startDate: calendarStartOfDay(date: startDate),
            endDate: calendarEndOfDay(date: endDate),
            sponsorID: userID,
            createdBy: userID,
            assignedAthletes: assignedAthletes,
            eventID: event?.id,
            submissions: []
        )

        let db = Firestore.firestore()
        let data = try! Firestore.Encoder().encode(newChallenge)

        db.collection("challenges").addDocument(data: data) { error in
            if let error = error {
                print("❌ Failed to save challenge: \(error.localizedDescription)")
            } else {
                print("✅ Challenge saved to Firestore!")
                challenges.append(newChallenge)
                showAlert = true
            }
        }
    }

    private func resetForm() {
        if event == nil {
            challengeTitle = ""
        }
        customChallengeInput = ""
        customChallenges = []
        reward = ""
        startDate = Date()
        endDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        assignedAthletes.removeAll()
        athleteSearch = ""
    }


    private func calendarStartOfDay(date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private func calendarEndOfDay(date: Date) -> Date {
        Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date
    }

    private func formattedDateOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
