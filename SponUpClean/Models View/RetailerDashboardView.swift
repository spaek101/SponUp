import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct RetailerDashboardView: View {
    @AppStorage("userID") var userID: String = ""
    @AppStorage("userRole") var userRole: String = ""

    @State private var firstName: String = ""
    @State private var companyName: String = ""
    @State private var totalChallenges = 0
    @State private var totalSubmissions = 0
    @State private var totalRewardsGiven = 0
    @State private var showSignOutAlert = false
    @State private var isSignedOut = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                // MARK: - Page Title
                Text("Retailer Dashboard")
                    .font(.largeTitle)
                    .bold()
                    .padding(.horizontal)
                    .padding(.top)

                ScrollView {
                    VStack(spacing: 20) {
                        // Analytics Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("📊 Analytics for \(companyName.isEmpty ? "Retail Company" : companyName)")
                                .font(.headline)
                                .padding(.horizontal)


                            HStack(spacing: 16) {
                                statCard(title: "Challenges", value: totalChallenges, color: .blue)
                                statCard(title: "Submissions", value: totalSubmissions, color: .purple)
                                statCard(title: "Rewards", value: totalRewardsGiven, color: .orange)
                            }
                            .padding(.horizontal)
                        }

                        // Action Buttons
                        VStack(spacing: 16) {
                            NavigationLink(destination: CreateRetailerChallengeView()) {
                                dashboardCard(title: "Create Master Challenge", icon: "plus.circle.fill", color: .green)
                            }

                            NavigationLink(destination: RetailerChallengesListView()) {
                                dashboardCard(title: "View Posted Challenges", icon: "doc.plaintext", color: .blue)
                            }

                            NavigationLink(destination: RetailerProfileView()) {
                                dashboardCard(title: "Edit Profile", icon: "person.crop.circle.fill", color: .gray)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                NavigationLink(destination: SignInView(), isActive: $isSignedOut) {
                    EmptyView()
                }
                .hidden()
            }
            .background(Color.white)
            .alert(isPresented: $showSignOutAlert) {
                Alert(
                    title: Text("Sign Out"),
                    message: Text("Are you sure you want to sign out?"),
                    primaryButton: .destructive(Text("Sign Out")) {
                        signOut()
                    },
                    secondaryButton: .cancel()
                )
            }
            .navigationBarBackButtonHidden(true)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Welcome! \(firstName)")
                            .font(.footnote)
                            .foregroundColor(.black)

                        Button("Sign Out") {
                            showSignOutAlert = true
                        }
                        .foregroundColor(.red)
                        .font(.footnote)
                    }
                }

                ToolbarItem(placement: .principal) {
                    EmptyView()
                }
            }
            .onAppear {
                fetchRetailerInfo()
                fetchRetailerAnalytics()
            }
        }
    }

    // MARK: - UI Components

    func statCard(title: String, value: Int, color: Color) -> some View {
        VStack {
            Text("\(value)")
                .font(.title)
                .bold()
                .foregroundColor(color)

            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 4)
    }

    func dashboardCard(title: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.white)
                .padding()
                .background(color)
                .clipShape(Circle())

            Text(title)
                .font(.headline)
                .foregroundColor(.black)

            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Firestore

    func fetchRetailerInfo() {
        Firestore.firestore().collection("users").document(userID).getDocument { doc, _ in
            if let data = doc?.data() {
                self.firstName = data["firstName"] as? String ?? "Retailer"
                self.companyName = data["companyName"] as? String ?? ""
            }
        }
    }

    func fetchRetailerAnalytics() {
        let db = Firestore.firestore()

        db.collection("challenges")
            .whereField("createdBy", isEqualTo: userID)
            .getDocuments { snapshot, _ in
                guard let documents = snapshot?.documents else { return }
                self.totalChallenges = documents.count

                var allSubmissions = 0
                var rewardCount = 0

                let group = DispatchGroup()

                for doc in documents {
                    let challengeID = doc.documentID

                    group.enter()
                    db.collection("submissions")
                        .whereField("challengeID", isEqualTo: challengeID)
                        .getDocuments { submissionSnap, _ in
                            if let submissions = submissionSnap?.documents {
                                allSubmissions += submissions.count
                                rewardCount += submissions.filter {
                                    ($0["status"] as? String)?.lowercased() == "rewarded"
                                }.count
                            }
                            group.leave()
                        }
                }

                group.notify(queue: .main) {
                    self.totalSubmissions = allSubmissions
                    self.totalRewardsGiven = rewardCount
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
