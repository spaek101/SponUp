import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct CreateRetailerChallengeView: View {
    @AppStorage("userID") var userID: String = ""
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var tournamentName = ""
    @State private var tournamentLink = ""
    @State private var reward = ""
    @State private var sponsorID = ""
    @State private var assignedAthletesInput = ""
    @State private var eventID = ""
    @State private var achievements: [ChallengeAchievement] = []
    @State private var newAchievementType = ""
    @State private var newAchievementQty = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var promoVideoLink = ""
    @State private var showSuccess = false
    @State private var targetedAthleteCount: Int = 0

    let allGroups = ["All Age Groups", "6u", "7u", "8u", "9u", "10u", "11u", "12u", "13u", "14u", "15u", "16u", "17u", "18u"]
    @State private var selectedAgeGroups: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Create Master Challenge")
                    .font(.title)
                    .bold()

                // Age Groups
                VStack(alignment: .leading, spacing: 10) {
                    Text("Desired Age Group(s)").font(.headline)

                    Button(action: { toggleAgeGroup("All Age Groups") }) {
                        Text("All Age Groups")
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .background(selectedAgeGroups.contains("All Age Groups") ? Color.blue : Color.gray.opacity(0.2))
                            .foregroundColor(selectedAgeGroups.contains("All Age Groups") ? .white : .black)
                            .cornerRadius(8)
                    }

                    let filteredGroups = allGroups.filter { $0 != "All Age Groups" }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 10) {
                        ForEach(filteredGroups, id: \.self) { group in
                            Button(action: { toggleAgeGroup(group) }) {
                                Text(group)
                                    .padding(8)
                                    .frame(maxWidth: .infinity)
                                    .background(selectedAgeGroups.contains(group) ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedAgeGroups.contains(group) ? .white : .black)
                                    .cornerRadius(8)
                            }
                        }
                    }

                    Text("🎯 Targeted Athletes: \(targetedAthleteCount)")
                        .foregroundColor(.gray)
                        .font(.subheadline)
                }

                // Text Fields
                Group {
                    TextField("Challenge Title", text: $title).textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("Tournament Name", text: $tournamentName).textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("Tournament Link", text: $tournamentLink).textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("Reward", text: $reward).textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("Sponsor ID (optional)", text: $sponsorID).textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("Event ID (optional)", text: $eventID).textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("Assigned Athletes (comma-separated IDs)", text: $assignedAthletesInput).textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("Promo Video Link", text: $promoVideoLink).textFieldStyle(RoundedBorderTextFieldStyle())
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                }

                // Achievements Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Achievements").font(.headline)

                    ForEach(achievements.indices, id: \.self) { index in
                        let achievement = achievements[index]
                        HStack {
                            Text("🏆 \(achievement.type) ×\(achievement.quantity)")
                            Spacer()
                            Button("Remove") {
                                achievements.remove(at: index)
                            }.foregroundColor(.red)
                        }
                    }

                    HStack {
                        TextField("Type (e.g. HR, RBI)", text: $newAchievementType)
                        TextField("Qty", text: $newAchievementQty)
                            .keyboardType(.numberPad)
                        Button("Add") {
                            if let qty = Int(newAchievementQty), !newAchievementType.isEmpty {
                                achievements.append(.init(type: newAchievementType, quantity: qty))
                                newAchievementType = ""
                                newAchievementQty = ""
                            }
                        }
                    }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                // Submit
                Button("Post Challenge") {
                    postChallenge()
                }
                .disabled(
                    title.trimmingCharacters(in: .whitespaces).isEmpty ||
                    promoVideoLink.trimmingCharacters(in: .whitespaces).isEmpty ||
                    selectedAgeGroups.isEmpty ||
                    reward.trimmingCharacters(in: .whitespaces).isEmpty
                )
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)

                if showSuccess {
                    Text("✅ Challenge posted successfully!")
                        .foregroundColor(.green)
                }
            }
            .padding()
        }
    }

    // MARK: - Logic

    private func toggleAgeGroup(_ group: String) {
        if group == "All Age Groups" {
            selectedAgeGroups = ["All Age Groups"]
        } else {
            selectedAgeGroups.remove("All Age Groups")
            if selectedAgeGroups.contains(group) {
                selectedAgeGroups.remove(group)
            } else {
                selectedAgeGroups.insert(group)
            }
        }
        fetchTargetedAthleteCount()
    }

    private func fetchTargetedAthleteCount() {
        let db = Firestore.firestore()
        let ref = db.collection("users").whereField("role", isEqualTo: "athlete")

        if selectedAgeGroups.contains("All Age Groups") {
            ref.getDocuments { snapshot, _ in
                self.targetedAthleteCount = snapshot?.documents.count ?? 0
            }
        } else if selectedAgeGroups.isEmpty {
            self.targetedAthleteCount = 0
        } else {
            ref.whereField("ageGroup", in: Array(selectedAgeGroups)).getDocuments { snapshot, _ in
                self.targetedAthleteCount = snapshot?.documents.count ?? 0
            }
        }
    }

    private func postChallenge() {
        let db = Firestore.firestore()
        let calendar = Calendar.current
        let normalizedStart = calendar.startOfDay(for: startDate)

        var endComponents = DateComponents()
        endComponents.day = 1
        endComponents.second = -1
        let normalizedEnd = calendar.date(byAdding: endComponents, to: calendar.startOfDay(for: endDate)) ?? endDate

        let assignedAthletes = assignedAthletesInput
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let achievementsData = achievements.map { ["type": $0.type, "quantity": $0.quantity] }

        let data: [String: Any] = [
            "title": title,
            "tournamentName": tournamentName,
            "tournamentLink": tournamentLink,
            "startDate": Timestamp(date: normalizedStart),
            "endDate": Timestamp(date: normalizedEnd),
            "createdBy": userID,
            "type": "retailer",
            "promoVideoURL": promoVideoLink.trimmingCharacters(in: .whitespaces),
            "desiredAgeGroups": Array(selectedAgeGroups),
            "reward": reward.trimmingCharacters(in: .whitespaces),
            "sponsorID": sponsorID,
            "assignedAthletes": assignedAthletes,
            "eventID": eventID.isEmpty ? NSNull() : eventID,
            "achievements": achievementsData
        ]

        db.collection("challenges").addDocument(data: data) { error in
            if error == nil {
                showSuccess = true
                clearForm()
            } else {
                print("❌ Error posting challenge: \(error!.localizedDescription)")
            }
        }
    }

    private func clearForm() {
        title = ""
        tournamentName = ""
        tournamentLink = ""
        reward = ""
        sponsorID = ""
        eventID = ""
        assignedAthletesInput = ""
        promoVideoLink = ""
        startDate = Date()
        endDate = Date()
        selectedAgeGroups.removeAll()
        achievements.removeAll()
        targetedAthleteCount = 0
    }
}
