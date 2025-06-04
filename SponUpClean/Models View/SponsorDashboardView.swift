import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SponsorDashboardView: View {
    @State private var showSignOutAlert = false
    @State private var sponsoredAthletes: [Athlete] = []
    @State private var challenges: [Challenge] = []
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @AppStorage("userID") var userID: String = ""
    @AppStorage("userRole") var userRole: String = ""
    @State private var isSignedOut = false

    @State private var pendingCount = 0
    @State private var hasPendingAthletes = false

    var body: some View {
        NavigationStack {
            VStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        // MARK: - Buttons
                        VStack(spacing: 12) {
                            NavigationLink(destination: ChallengeOptionsView(sponsoredAthletes: $sponsoredAthletes, challenges: $challenges)) {
                                Text("Create Challenge")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                    .shadow(radius: 4)
                            }

                            ZStack(alignment: .topTrailing) {
                                NavigationLink(destination: ReviewSubmissionsView(challenges: $challenges)) {
                                    Text("Review Submissions")
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                        .shadow(radius: 4)
                                }

                                if pendingCount > 0 {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 12, height: 12)
                                        .offset(x: -10, y: 10)
                                }
                            }
                        }
                        .padding(.horizontal)

                        // MARK: - Dashboard Cards
                        VStack(spacing: 16) {
                            NavigationLink(destination: MyChallengesView(challenges: challenges)) {
                                dashboardCard(title: "My Challenges", systemImage: "list.bullet")
                            }

                            ZStack(alignment: .topTrailing) {
                                NavigationLink(destination: SponsoredAthletesView(sponsoredAthletes: $sponsoredAthletes)) {
                                    dashboardCard(title: "Athlete List", systemImage: "person.3.fill")
                                }

                                if hasPendingAthletes {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 12, height: 12)
                                        .offset(x: -10, y: 10)
                                }
                            }

                            NavigationLink(destination: SponsorProfileView(firstName: $firstName, lastName: $lastName)) {
                                dashboardCard(title: "My Profile", systemImage: "person.crop.circle.fill")
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                }

                NavigationLink(destination: SignInView(), isActive: $isSignedOut) {
                    EmptyView()
                }
                .hidden()
            }
            .navigationTitle("My Dashboard")
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    VStack(alignment: .trailing) {
                        Text("Welcome! \(firstName) \(lastName)")
                            .font(.footnote)
                            .foregroundColor(.black)

                        Button("Sign Out") {
                            showSignOutAlert = true
                        }
                        .foregroundColor(.red)
                        .font(.footnote)
                    }
                }
            }
            .alert(isPresented: $showSignOutAlert) {
                Alert(
                    title: Text("Sign Out"),
                    message: Text("Are you sure you want to sign out?"),
                    primaryButton: .destructive(Text("Sign Out")) { signOut() },
                    secondaryButton: .cancel()
                )
            }
            .onAppear {
                fetchUserProfile()
                fetchSponsoredAthletes()
                fetchChallenges()
                fetchSubmissionStats()
            }
        }
    }

    func dashboardCard(title: String, systemImage: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(Color.blue)
                .clipShape(Circle())

            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.black)

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 5)
    }

    private func fetchUserProfile() {
        guard let sponsorID = Auth.auth().currentUser?.uid else { return }

        Firestore.firestore().collection("users").document(sponsorID).getDocument { document, error in
            if let error = error {
                print("❌ Error fetching sponsor profile: \(error.localizedDescription)")
                return
            }

            guard let data = document?.data() else { return }
            self.firstName = data["firstName"] as? String ?? "Unknown"
            self.lastName = data["lastName"] as? String ?? "Unknown"
        }
    }

    private func fetchSponsoredAthletes() {
        guard let sponsorID = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        db.collection("users").document(sponsorID).getDocument { doc, error in
            if let error = error {
                print("❌ Error fetching sponsor document: \(error.localizedDescription)")
                return
            }

            guard let doc = doc, doc.exists,
                  let data = doc.data() else {
                self.sponsoredAthletes = []
                self.hasPendingAthletes = false
                return
            }

            let athleteIDs = data["sponsoredAthletes"] as? [String] ?? []
            let pendingIDs = data["pendingAthletes"] as? [String] ?? []

            let actualPendingIDs = pendingIDs.filter { !athleteIDs.contains($0) }
            self.hasPendingAthletes = !actualPendingIDs.isEmpty

            var loadedAthletes: [Athlete] = []
            let group = DispatchGroup()

            for athleteID in athleteIDs {
                group.enter()
                db.collection("users").document(athleteID).getDocument { athleteDoc, _ in
                    defer { group.leave() }

                    if let data = athleteDoc?.data() {
                        let athlete = Athlete(
                            id: athleteID,
                            firstName: data["firstName"] as? String ?? "Unknown",
                            lastName: data["lastName"] as? String ?? "Unknown"
                        )
                        loadedAthletes.append(athlete)
                    }
                }
            }

            group.notify(queue: .main) {
                self.sponsoredAthletes = loadedAthletes
            }
        }
    }

    private func fetchChallenges() {
        Firestore.firestore().collection("challenges")
            .whereField("sponsorID", isEqualTo: userID)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error fetching challenges: \(error.localizedDescription)")
                    return
                }

                self.challenges = snapshot?.documents.compactMap { try? $0.data(as: Challenge.self) } ?? []
            }
    }

    private func fetchSubmissionStats() {
        let db = Firestore.firestore()

        db.collection("challenges")
            .whereField("sponsorID", isEqualTo: userID)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error fetching challenges for submission stats: \(error.localizedDescription)")
                    return
                }

                let challengeIDs = snapshot?.documents.map { $0.documentID } ?? []
                guard !challengeIDs.isEmpty else { return }

                db.collection("submissions")
                    .whereField("challengeID", in: challengeIDs)
                    .getDocuments { subSnapshot, subError in
                        if let subError = subError {
                            print("❌ Error fetching submissions: \(subError.localizedDescription)")
                            return
                        }

                        let submissions = subSnapshot?.documents ?? []
                        self.pendingCount = submissions.filter { $0["status"] as? String == "Pending" }.count
                    }
            }
    }

    private func signOut() {
        do {
            try Auth.auth().signOut()
            userID = ""
            userRole = ""
            isSignedOut = true
        } catch {
            print("❌ Error signing out: \(error.localizedDescription)")
        }
    }
}
