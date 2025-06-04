import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct AthleteChallengesView: View {
    @AppStorage("userRole") private var userRole: String = "athlete"
    @AppStorage("userID") private var userID: String = ""
    @AppStorage("ageGroup") private var ageGroup: String = ""
    @AppStorage("viewedSponsorChallengeIDs") private var viewedSponsorChallengeIDsRaw: String = ""

    @State private var challenges: [Challenge] = []
    @State private var submissionStatuses: [String: String] = [:]
    @State private var sponsorNames: [String: String] = [:]
    @State private var sponsorImages: [String: String] = [:]
    @State private var selectedChallenge: Challenge?
    @State private var showExpired = false
    @State private var viewedChallengeIDs: Set<String> = []

    var body: some View {
        if userRole == "athlete" {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {

                        

                        Divider().padding(.top)

                        

                        sponsorChallengeListView(challenges: showExpired ? expiredSponsorChallenges : currentSponsorChallenges)
                            .id(showExpired)
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.3), value: showExpired)
                    }
                }

                Text(showExpired ? "View Current Challenges" : "View Expired Challenges")
                    .font(.footnote)
                    .foregroundColor(.blue)
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(Color(UIColor.systemBackground))
                    .onTapGesture {
                        withAnimation {
                            showExpired.toggle()
                        }
                    }
            }
            .navigationTitle("My Challenges")
            .onAppear {
                fetchAssignedChallenges()
                viewedChallengeIDs = Set(viewedSponsorChallengeIDsRaw.split(separator: ",").map { String($0) })
            }
            .navigationDestination(item: $selectedChallenge) { challenge in
                ChallengeDetailViewAthlete(challenge: challenge)
            }
        } else {
            Text("You must be logged in as an athlete.")
        }
    }

    private func sponsorChallengeListView(challenges: [Challenge]) -> some View {
        VStack(spacing: 0) {
            ForEach(challenges.indices, id: \.self) { index in
                let challenge = challenges[index]
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        if let urlString = sponsorImages[challenge.createdBy], let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView().frame(width: 48, height: 48)
                                case .success(let image):
                                    image.resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 48, height: 48)
                                        .clipShape(Circle())
                                case .failure:
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable()
                                        .frame(width: 48, height: 48)
                                        .foregroundColor(.gray)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .frame(width: 48, height: 48)
                                .foregroundColor(.gray)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(challenge.title)
                                .font(.headline)
                                .foregroundColor(.black)

                            Text(sponsorNames[challenge.createdBy] ?? "Loading...")
                                .font(.caption)
                                .foregroundColor(.gray)


                            let timeText = timeRemaining(challenge)
                            Text(timeText)
                                .font(.caption)
                                .foregroundColor(
                                    timeText.starts(with: "Deadline") ? .red :
                                    timeText == "In progress..." ? .green :
                                    .gray
                                )


                            .font(.caption)
                            .labelStyle(.titleAndIcon)



                            if let status = submissionStatuses[challenge.id ?? ""] {
                                Text(status)
                                    .font(.caption)
                                    .foregroundColor(colorForStatus(status))
                            }
                        }


                        Spacer()

                        NavigationLink(
                            destination: ChallengeDetailViewAthlete(challenge: challenge)
                                .onAppear {
                                    if let id = challenge.id {
                                        viewedChallengeIDs.insert(id)
                                        viewedSponsorChallengeIDsRaw = viewedChallengeIDs.joined(separator: ",")
                                    }
                                },
                            label: {
                                Text(viewedChallengeIDs.contains(challenge.id ?? "") ? "View" : "New")
                                    .font(.footnote)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 14)
                                    .background(viewedChallengeIDs.contains(challenge.id ?? "") ? Color.gray : Color.black)
                                    .cornerRadius(8)

                            }
                        )
                    }
                    .padding(.horizontal)

                    if index != challenges.indices.last {
                        Divider()
                            .padding(.vertical, 10)
                            .padding(.horizontal)
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private func fetchAssignedChallenges() {
        let db = Firestore.firestore()
        db.collection("challenges").getDocuments { snapshot, error in
            guard let documents = snapshot?.documents else { return }

            var allChallenges: [Challenge] = []
            for doc in documents {
                do {
                    let decoded = try doc.data(as: Challenge.self)
                    allChallenges.append(decoded)
                } catch {
                    print("❌ Failed to decode challenge: \(error)")
                }
            }

            let retailerChallenges = allChallenges.filter { $0.type == "retailer" }
            let matchingRetailer = retailerChallenges.filter {
                let groups = ($0.desiredAgeGroups ?? []).map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
                let normalized = ageGroup.lowercased().trimmingCharacters(in: .whitespaces)
                return groups.isEmpty || groups.contains("all age groups") || groups.contains(normalized)
            }

            self.challenges = allChallenges.filter {
                if $0.type == "retailer" {
                    return matchingRetailer.contains(where: { $0.id == $0.id })
                } else {
                    return $0.assignedAthletes.contains(userID)
                }
            }

            self.fetchStatuses(for: self.challenges)
            self.loadSponsorNames(for: self.challenges)
        }
    }

    private func fetchStatuses(for challenges: [Challenge]) {
        let db = Firestore.firestore()
        db.collection("submissions").whereField("athleteID", isEqualTo: userID)
            .getDocuments { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                var statuses: [String: String] = [:]
                for doc in docs {
                    let data = doc.data()
                    if let cid = data["challengeID"] as? String,
                       let status = data["status"] as? String {
                        statuses[cid] = status
                    }
                }
                self.submissionStatuses = statuses
            }
    }

    private func loadSponsorNames(for challenges: [Challenge]) {
        let db = Firestore.firestore()
        let sponsorIDs = Set(challenges.map { $0.createdBy })
        for sponsorID in sponsorIDs {
            if sponsorNames[sponsorID] == nil || sponsorImages[sponsorID] == nil {
                db.collection("users").document(sponsorID).getDocument { doc, _ in
                    if let data = doc?.data() {
                        let firstName = data["firstName"] as? String ?? ""
                        let lastName = data["lastName"] as? String ?? ""
                        let profileImageURL = data["profileImageURL"] as? String ?? ""

                        DispatchQueue.main.async {
                            sponsorNames[sponsorID] = "\(firstName) \(lastName)"
                            sponsorImages[sponsorID] = profileImageURL
                        }
                    }
                }
            }
        }
    }

    private func timeRemaining(_ challenge: Challenge) -> String {
        let now = Date()
        let fiveDayGrace = Calendar.current.date(byAdding: .day, value: 5, to: challenge.endDate)!
        
        if now < challenge.startDate {
            let diff = Calendar.current.dateComponents([.day, .hour, .minute], from: now, to: challenge.startDate)
            return "Starts in: \(diff.day ?? 0)d \(diff.hour ?? 0)h \(diff.minute ?? 0)m"
        } else if now >= challenge.startDate && now <= challenge.endDate {
            return "In progress..."
        } else if now > challenge.endDate && now <= fiveDayGrace {
            let diff = Calendar.current.dateComponents([.day, .hour, .minute], from: now, to: fiveDayGrace)
            return "Deadline: \(diff.day ?? 0)d \(diff.hour ?? 0)h \(diff.minute ?? 0)m"
        } else {
            return "Expired"
        }
    }


    private var currentChallenges: [Challenge] {
        let now = Date()
        return challenges.filter {
            Calendar.current.date(byAdding: .day, value: 5, to: $0.endDate)! > now
        }
    }

    private var expiredChallenges: [Challenge] {
        let now = Date()
        return challenges
            .filter { Calendar.current.date(byAdding: .day, value: 5, to: $0.endDate)! <= now }
            .sorted { $0.endDate > $1.endDate }
    }

    

    private var currentSponsorChallenges: [Challenge] {
        currentChallenges
            .filter { $0.type != "retailer" }
            .sorted { $0.endDate < $1.endDate }
    }

    private var expiredSponsorChallenges: [Challenge] {
        expiredChallenges.filter { $0.type != "retailer" }
    }
}
    private func colorForStatus(_ status: String) -> Color {
        switch status.lowercased() {
        case "approved": return .green
        case "rewarded": return .green
        case "rejected": return .red
        case "pending": return .orange
        default: return .gray
    }
}







struct ChallengeCardView: View {
    let challenge: Challenge
    let status: String?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black)
                .frame(height: 200)
            VStack(spacing: 10) {
                Text(challenge.title)
                    .foregroundColor(.white)
                    .font(.title2)
                    .bold()
                Text("🏆 \(challenge.reward ?? "Reward")")
                    .foregroundColor(.orange)
                if let msg = statusMessage {
                    Text(msg.text)
                        .foregroundColor(msg.color)
                } else {
                    Text("⏳ Time Left: \(timeRemaining)")
                        .foregroundColor(.gray)
                }
            }
            .padding()
        }
        .padding(.horizontal)
    }

    private var timeRemaining: String {
        let adjusted = Calendar.current.date(byAdding: .day, value: 5, to: challenge.endDate)!
        let diff = Calendar.current.dateComponents([.day, .hour, .minute], from: Date(), to: adjusted)
        let days = diff.day ?? 0
        let hours = diff.hour ?? 0
        let minutes = diff.minute ?? 0
        return "\(days)d \(hours)h \(minutes)m"
    }

    private var statusMessage: (text: String, color: Color)? {
        switch status?.lowercased() {
        case "approved": return ("✅ Approved", .green)
        case "rewarded": return ("🎁 Rewarded", .green)
        case "rejected": return ("‼️ Rejected", .red)
        case "pending": return ("📝 Pending Review", .white)
        default: return nil
        }
    }
}

struct RetailerChallengeCardView: View {
    let challenge: Challenge
    let status: String?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black)


            VStack {
                Spacer()

                VStack(spacing: 12) {
                    Text(challenge.title)
                        .foregroundColor(.white)
                        .font(.title2)
                        .bold()

                    Text("🏷️ Retailer Challenge")
                        .foregroundColor(.white)

                    if let rewardText = challenge.reward {
                        Text("🏆 \(rewardText)")
                            .foregroundColor(.white)
                    }

                    if let msg = statusMessage {
                        Text(msg.text)
                            .foregroundColor(msg.color)
                    } else {
                        Text("⏳ Time Left: \(timeRemaining)")
                            .foregroundColor(.yellow)
                    }
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())

                Spacer()
            }
            .padding()
        }
        .frame(height: 200)
        .padding(.horizontal)
    }

    private var timeRemaining: String {
        let adjusted = Calendar.current.date(byAdding: .day, value: 5, to: challenge.endDate)!
        let diff = Calendar.current.dateComponents([.day, .hour, .minute], from: Date(), to: adjusted)
        return "\(diff.day ?? 0)d \(diff.hour ?? 0)h \(diff.minute ?? 0)m"
    }

    private var statusMessage: (text: String, color: Color)? {
        switch status?.lowercased() {
        case "approved": return ("✅ Approved", .green)
        case "rewarded": return ("🎁 Rewarded", .green)
        case "rejected": return ("‼️ Rejected", .red)
        case "pending": return ("📝 Pending Review", .black)
        default: return nil
        }
    }
}






struct ChallengeCarouselView: View {
    let challenges: [Challenge]
    let submissionStatuses: [String: String]
    @State private var selectedIndex = 0

    var body: some View {
        TabView(selection: $selectedIndex) {
            ForEach(challenges.indices, id: \.self) { index in
                let c = challenges[index]
                NavigationLink(destination: ChallengeDetailViewAthlete(challenge: c)) {
                    if c.type == "retailer" {
                        RetailerChallengeCardView(challenge: c, status: submissionStatuses[c.id ?? ""])
                    } else {
                        ChallengeCardView(challenge: c, status: submissionStatuses[c.id ?? ""])
                    }
                }
                .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        
    }
    
}
