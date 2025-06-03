import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct AthleteDashboardView: View {
    @State private var showSignOutAlert = false
    @State private var isSignedOut = false
    @AppStorage("userRole") var userRole: String = ""
    @AppStorage("userID") var userID: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var hasPendingSponsors = false
    @State private var hasRejectedSubmissions = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("My Dashboard")
                    .font(.largeTitle)
                    .bold()
                    .padding(.horizontal)
                    .padding(.top)

                if userRole == "athlete" {
                    ScrollView {
                        VStack(spacing: 16) {
                            VStack(spacing: 20) {
                                NavigationLink(destination: AthleteChallengesView()) {
                                    DashboardButtonCard(text: "View Challenges")
                                }

                                NavigationLink(destination: UploadScheduleView()) {
                                    DashboardButtonCard(text: "Create Event")
                                }

                                // Submissions with red dot
                                ZStack(alignment: .topTrailing) {
                                    NavigationLink(destination: MySubmissionsView()) {
                                        DashboardCardView(title: "My Submissions", systemImage: "tray.full")
                                    }

                                    if hasRejectedSubmissions {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 12, height: 12)
                                            .offset(x: -10, y: 10)
                                    }
                                }

                                // Sponsors with red dot
                                ZStack(alignment: .topTrailing) {
                                    NavigationLink(destination: AddSponsorView()) {
                                        DashboardCardView(title: "Sponsors", systemImage: "person.3.fill")
                                    }

                                    if hasPendingSponsors {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 12, height: 12)
                                            .offset(x: -10, y: 10)
                                    }
                                }

                                NavigationLink(destination: AthleteProfileView()) {
                                    DashboardCardView(title: "My Profile", systemImage: "person.crop.circle")
                                }
                            }
                            .padding()
                        }
                    }
                } else {
                    Text("This dashboard is only available for athletes.")
                        .font(.headline)
                        .foregroundColor(.red)
                        .padding()
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

                ToolbarItem(placement: .principal) {
                    EmptyView()
                }
            }
            .onAppear {
                fetchUserProfile()
                fetchPendingSponsors()
                fetchRejectedSubmissions()
            }
        }
    }

    private func fetchUserProfile() {
        let db = Firestore.firestore()
        guard let userID = Auth.auth().currentUser?.uid else { return }

        db.collection("users").document(userID).getDocument { (document, error) in
            if let document = document, document.exists {
                let data = document.data()
                self.firstName = data?["firstName"] as? String ?? "Unknown"
                self.lastName = data?["lastName"] as? String ?? "Unknown"
            }
        }
    }

    private func fetchPendingSponsors() {
        let db = Firestore.firestore()
        db.collection("users").document(userID).getDocument { docSnapshot, error in
            guard let data = docSnapshot?.data() else { return }

            let approved = data["sponsorIDs"] as? [String] ?? []
            let pending = data["pendingSponsors"] as? [String] ?? []

            let actualPending = pending.filter { !approved.contains($0) }
            self.hasPendingSponsors = !actualPending.isEmpty
        }
    }

    private func fetchRejectedSubmissions() {
        let db = Firestore.firestore()
        db.collection("submissions")
            .whereField("athleteID", isEqualTo: userID)
            .whereField("status", isEqualTo: "Rejected")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error checking rejected submissions: \(error.localizedDescription)")
                    return
                }

                self.hasRejectedSubmissions = !(snapshot?.documents.isEmpty ?? true)
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

// MARK: - Styled DashboardCard
struct DashboardCardView: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(Color.black)
                .clipShape(Circle())

            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.black)

            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Primary Button Card
struct DashboardButtonCard: View {
    let text: String

    var body: some View {
        Text(text)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.black)
            .foregroundColor(.white)
            .cornerRadius(12)
            .shadow(color: .gray.opacity(0.4), radius: 4, x: 0, y: 2)
    }
}
