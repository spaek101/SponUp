import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct AddSponsorView: View {
    @AppStorage("userID") var userID: String = ""
    @State private var sponsorID = ""
    @State private var sponsors: [Sponsor] = []
    @State private var pendingSponsors: [Sponsor] = []
    @State private var sponsorToDelete: Sponsor?
    @State private var showDeleteAlert = false
    @State private var deletePending = false
    @State private var toastMessage = ""
    @State private var showToast = false
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
               

                // Sponsor Input
                VStack(spacing: 10) {
                    TextField("Enter Sponsor ID", text: $sponsorID)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .contextMenu {
                            Button("Paste") {
                                if let string = UIPasteboard.general.string {
                                    sponsorID = string
                                }
                            }
                        }

                    Button(action: addSponsor) {
                        Text("Add Sponsor")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)

                // Tabs with red dot
                ZStack(alignment: .topTrailing) {
                    Picker("View", selection: $selectedTab) {
                        Text("Approved").tag(0)
                        Text("Pending").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)

                    if !pendingSponsors.isEmpty {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .offset(x: -24, y: 6)
                    }
                }

                

                // Sponsor Lists
                if selectedTab == 0 {
                    if sponsors.isEmpty {
                        Spacer()
                        Text("No approved sponsors yet.")
                            .foregroundColor(.gray)
                        Spacer()
                    } else {
                        List {
                            ForEach(sponsors.sorted(by: sortByName)) { sponsor in
                                sponsorRow(sponsor)
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            sponsorToDelete = sponsor
                                            deletePending = false
                                            showDeleteAlert = true
                                        } label: {
                                            Label("Remove", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                } else {
                    if pendingSponsors.isEmpty {
                        Spacer()
                        Text("No pending sponsors.")
                            .foregroundColor(.gray)
                        Spacer()
                    } else {
                        List {
                            ForEach(pendingSponsors.sorted(by: sortByName)) { sponsor in
                                VStack(alignment: .leading, spacing: 8) {
                                    sponsorRow(sponsor)

                                    HStack {
                                        Button("Accept") {
                                            acceptSponsor(sponsor)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color.black)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)

                                        Button("Decline") {
                                            declineSponsor(sponsor)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color(.systemGray6))
                                        .foregroundColor(.black)
                                        .cornerRadius(10)
                                    }
                                }
                                .padding(.vertical, 4)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        sponsorToDelete = sponsor
                                        deletePending = true
                                        showDeleteAlert = true
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                }

                Spacer()
            }
            .alert("Remove Sponsor", isPresented: $showDeleteAlert, presenting: sponsorToDelete) { sponsor in
                Button("Remove", role: .destructive) {
                    if deletePending {
                        declineSponsor(sponsor)
                    } else {
                        deleteConfirmedSponsor(sponsor)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { sponsor in
                Text("Are you sure you want to remove \(sponsor.firstName) \(sponsor.lastName)?")
            }
            .onAppear {
                fetchSponsors()
            }
            .overlay(
                Group {
                    if showToast {
                        Text(toastMessage)
                            .padding()
                            .background(Color.black.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .transition(.opacity)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation { showToast = false }
                                }
                            }
                            .padding(.bottom, 40)
                    }
                },
                alignment: .bottom
            )
        }
    }

    // MARK: - Helper Views

    private func sponsorRow(_ sponsor: Sponsor) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(sponsor.firstName) \(sponsor.lastName)")
                .font(.headline)
            Text("🆔 \(sponsor.id)")
                .font(.footnote)
                .foregroundColor(.gray)
        }
    }

    // MARK: - Firestore Logic

    private func fetchSponsors() {
        let db = Firestore.firestore()
        db.collection("users").document(userID).getDocument { doc, _ in
            guard let data = doc?.data() else { return }

            let approved = data["sponsorIDs"] as? [String] ?? []
            let pending = data["pendingSponsors"] as? [String] ?? []

            let actualPending = pending.filter { !approved.contains($0) }

            var loadedApproved: [Sponsor] = []
            var loadedPending: [Sponsor] = []
            let group = DispatchGroup()

            for id in approved {
                group.enter()
                db.collection("users").document(id).getDocument { sponsorDoc, _ in
                    if let sponsor = sponsorDoc?.data() {
                        loadedApproved.append(Sponsor(
                            id: id,
                            firstName: sponsor["firstName"] as? String ?? "First",
                            lastName: sponsor["lastName"] as? String ?? "Last"
                        ))
                    }
                    group.leave()
                }
            }

            for id in actualPending {
                group.enter()
                db.collection("users").document(id).getDocument { sponsorDoc, _ in
                    if let sponsor = sponsorDoc?.data() {
                        loadedPending.append(Sponsor(
                            id: id,
                            firstName: sponsor["firstName"] as? String ?? "First",
                            lastName: sponsor["lastName"] as? String ?? "Last"
                        ))
                    }
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                sponsors = loadedApproved
                pendingSponsors = loadedPending
            }
        }
    }

    private func addSponsor() {
        guard !sponsorID.isEmpty else { return }

        if sponsors.contains(where: { $0.id == sponsorID }) {
            toastMessage = "This user is already approved."
            showToastMessage()
            return
        }
        if pendingSponsors.contains(where: { $0.id == sponsorID }) {
            toastMessage = "This user is already pending."
            showToastMessage()
            return
        }

        let db = Firestore.firestore()
        let sponsorRef = db.collection("users").document(sponsorID)
        let userRef = db.collection("users").document(userID)

        sponsorRef.getDocument { doc, _ in
            guard let data = doc?.data(),
                  let role = data["role"] as? String,
                  role.lowercased() == "sponsor" || role.lowercased() == "retailer" else {
                toastMessage = "This user is not a sponsor or retailer."
                showToastMessage()
                return
            }

            sponsorRef.updateData([
                "pendingAthletes": FieldValue.arrayUnion([userID])
            ]) { error in
                guard error == nil else { return }

                userRef.updateData([
                    "sponsorIDs": FieldValue.arrayUnion([sponsorID])
                ]) { error in
                    if error == nil {
                        sponsorID = ""
                        fetchSponsors()
                        toastMessage = "\(role.capitalized) successfully added!"
                        showToastMessage()
                    }
                }
            }
        }
    }

    private func acceptSponsor(_ sponsor: Sponsor) {
        let db = Firestore.firestore()
        db.collection("users").document(userID).updateData([
            "sponsorIDs": FieldValue.arrayUnion([sponsor.id]),
            "pendingSponsors": FieldValue.arrayRemove([sponsor.id])
        ]) { _ in fetchSponsors() }
    }

    private func declineSponsor(_ sponsor: Sponsor) {
        let db = Firestore.firestore()
        db.collection("users").document(userID).updateData([
            "pendingSponsors": FieldValue.arrayRemove([sponsor.id])
        ])
        db.collection("users").document(sponsor.id).updateData([
            "pendingAthletes": FieldValue.arrayRemove([userID])
        ]) { _ in fetchSponsors() }
    }

    private func deleteConfirmedSponsor(_ sponsor: Sponsor) {
        let db = Firestore.firestore()
        db.collection("users").document(userID).updateData([
            "sponsorIDs": FieldValue.arrayRemove([sponsor.id]),
            "pendingSponsors": FieldValue.arrayRemove([sponsor.id])
        ]) { _ in
            db.collection("users").document(sponsor.id).updateData([
                "approvedAthletes": FieldValue.arrayRemove([userID]),
                "pendingAthletes": FieldValue.arrayRemove([userID])
            ]) { _ in fetchSponsors() }
        }
    }

    private func sortByName(_ a: Sponsor, _ b: Sponsor) -> Bool {
        if a.firstName == b.firstName {
            return a.lastName < b.lastName
        }
        return a.firstName < b.firstName
    }

    private func showToastMessage() {
        withAnimation { showToast = true }
    }
}

struct Sponsor: Identifiable, Equatable {
    let id: String
    let firstName: String
    let lastName: String
}
