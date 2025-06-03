import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct SponsoredAthletesView: View {
    @AppStorage("userID") var userID: String = ""
    @Binding var sponsoredAthletes: [Athlete]

    @State private var athleteIDToAdd = ""
    @State private var pendingAthletes: [Athlete] = []
    @State private var athleteToDelete: Athlete?
    @State private var showDeleteAlert = false
    @State private var deletePending = false
    @State private var errorMessage = ""
    @State private var isLoading = true
    @State private var selectedTab = 0 // 0 = Approved, 1 = Pending
    @State private var toastMessage = ""
    @State private var showToast = false
    @State private var selectedAthleteIDs: Set<String> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("My Athletes")
                    .font(.title)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                VStack(spacing: 12) {
                    TextField("Enter Athlete ID", text: $athleteIDToAdd)
                        .textContentType(.none)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)

                    Button(action: addAthlete) {
                        Text("Add Athlete")
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.black)
                            .cornerRadius(10)
                    }

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)

                Picker("", selection: $selectedTab) {
                    Text("Approved").tag(0)
                    Text("Pending").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)

                if selectedTab == 0 {
                    if sponsoredAthletes.isEmpty {
                        Spacer()
                        Text("No approved athletes yet.")
                            .foregroundColor(.gray)
                        Spacer()
                    } else {
                        List {
                            ForEach(sponsoredAthletes.sorted(by: sortByName)) { athlete in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("\(athlete.firstName) \(athlete.lastName)")
                                        .font(.headline)
                                    Text("ID: \(athlete.id)")
                                        .font(.footnote)
                                        .foregroundColor(.gray)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        athleteToDelete = athlete
                                        deletePending = false
                                        showDeleteAlert = true
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                } else {
                    if pendingAthletes.isEmpty {
                        Spacer()
                        Text("No pending athletes.")
                            .foregroundColor(.gray)
                        Spacer()
                    } else {
                        VStack(spacing: 8) {
                            if !selectedAthleteIDs.isEmpty {
                                HStack(spacing: 16) {
                                    Button("Accept All") {
                                        acceptAllPendingAthletes()
                                    }
                                    .font(.footnote)
                                    .buttonStyle(.borderedProminent)

                                    Button("Decline All") {
                                        declineAllPendingAthletes()
                                    }
                                    .font(.footnote)
                                    .buttonStyle(.bordered)
                                }
                                .padding(.horizontal)
                            }

                            List {
                                ForEach(pendingAthletes.sorted(by: sortByName)) { athlete in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Button(action: {
                                            toggleSelection(for: athlete.id)
                                        }) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("\(athlete.firstName) \(athlete.lastName)")
                                                    .font(.headline)
                                                Text("ID: \(athlete.id)")
                                                    .font(.footnote)
                                                    .foregroundColor(.gray)
                                            }
                                            .padding()
                                            .background(
                                                selectedAthleteIDs.contains(athlete.id) ? Color.gray.opacity(0.3) : Color.clear
                                            )
                                            .cornerRadius(10)
                                        }

                                        HStack {
                                            Button("Accept") {
                                                acceptAthlete(athlete)
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .font(.footnote)

                                            Button("Decline") {
                                                declineAthlete(athlete)
                                            }
                                            .buttonStyle(.bordered)
                                            .font(.footnote)
                                        }
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            athleteToDelete = athlete
                                            deletePending = true
                                            showDeleteAlert = true
                                        } label: {
                                            Label("Remove", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .listStyle(.plain)
                        }
                    }
                }
            }
            .onAppear(perform: fetchAthletes)
            .alert("Remove Athlete", isPresented: $showDeleteAlert, presenting: athleteToDelete) { athlete in
                Button("Remove", role: .destructive) {
                    if deletePending {
                        declineAthlete(athlete)
                    } else {
                        deleteConfirmedAthlete(athlete)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { athlete in
                Text("Are you sure you want to remove \(athlete.firstName) \(athlete.lastName)?")
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
                                    withAnimation {
                                        showToast = false
                                    }
                                }
                            }
                            .padding(.bottom, 40)
                    }
                }, alignment: .bottom
            )
        }
    }

    private func sortByName(_ a: Athlete, _ b: Athlete) -> Bool {
        if a.firstName.localizedCaseInsensitiveCompare(b.firstName) == .orderedSame {
            return a.lastName.localizedCaseInsensitiveCompare(b.lastName) == .orderedAscending
        }
        return a.firstName.localizedCaseInsensitiveCompare(b.firstName) == .orderedAscending
    }

    private func fetchAthletes() {
        isLoading = true
        let db = Firestore.firestore()

        db.collection("users").document(userID).getDocument { document, error in
            isLoading = false
            if let document = document, document.exists,
               let data = document.data() {
                let confirmedIDs = data["sponsoredAthletes"] as? [String] ?? []
                let pendingIDs = data["pendingAthletes"] as? [String] ?? []
                var loadedConfirmed: [Athlete] = []
                var loadedPending: [Athlete] = []
                let group = DispatchGroup()

                for id in confirmedIDs {
                    group.enter()
                    db.collection("users").document(id).getDocument { doc, _ in
                        if let data = doc?.data() {
                            let firstName = data["firstName"] as? String ?? "Unknown"
                            let lastName = data["lastName"] as? String ?? "Unknown"
                            loadedConfirmed.append(Athlete(id: id, firstName: firstName, lastName: lastName))
                        }
                        group.leave()
                    }
                }

                for id in pendingIDs where !confirmedIDs.contains(id) {
                    group.enter()
                    db.collection("users").document(id).getDocument { doc, _ in
                        if let data = doc?.data() {
                            let firstName = data["firstName"] as? String ?? "Unknown"
                            let lastName = data["lastName"] as? String ?? "Unknown"
                            loadedPending.append(Athlete(id: id, firstName: firstName, lastName: lastName))
                        }
                        group.leave()
                    }
                }

                group.notify(queue: .main) {
                    self.sponsoredAthletes = loadedConfirmed
                    self.pendingAthletes = loadedPending
                }
            }
        }
    }

    private func addAthlete() {
        guard !athleteIDToAdd.isEmpty else { return }

        if sponsoredAthletes.contains(where: { $0.id == athleteIDToAdd }) {
            errorMessage = "This athlete is already approved."
            return
        }
        if pendingAthletes.contains(where: { $0.id == athleteIDToAdd }) {
            errorMessage = "This athlete is already pending."
            return
        }

        let db = Firestore.firestore()
        let athleteRef = db.collection("users").document(athleteIDToAdd)
        let sponsorRef = db.collection("users").document(userID)

        athleteRef.getDocument { document, error in
            if let document = document, document.exists,
               let data = document.data(),
               data["role"] as? String == "athlete" {

                sponsorRef.updateData([
                    "sponsoredAthletes": FieldValue.arrayUnion([athleteIDToAdd])
                ]) { error in
                    if error == nil {
                        athleteRef.updateData([
                            "pendingSponsors": FieldValue.arrayUnion([userID])
                        ]) { error in
                            if error == nil {
                                fetchAthletes()
                                athleteIDToAdd = ""
                                errorMessage = ""
                                showToastMessage("Athlete added and request sent!")
                            }
                        }
                    }
                }
            } else {
                errorMessage = "Athlete not found."
            }
        }
    }

    private func acceptAthlete(_ athlete: Athlete) {
        let db = Firestore.firestore()
        db.collection("users").document(userID).updateData([
            "sponsoredAthletes": FieldValue.arrayUnion([athlete.id]),
            "pendingAthletes": FieldValue.arrayRemove([athlete.id])
        ]) { _ in
            db.collection("users").document(athlete.id).updateData([
                "approvedSponsors": FieldValue.arrayUnion([userID])
            ]) { _ in fetchAthletes() }
        }
    }

    private func declineAthlete(_ athlete: Athlete) {
        let db = Firestore.firestore()
        db.collection("users").document(userID).updateData([
            "pendingAthletes": FieldValue.arrayRemove([athlete.id])
        ])
        db.collection("users").document(athlete.id).updateData([
            "pendingSponsors": FieldValue.arrayRemove([userID])
        ]) { _ in fetchAthletes() }
    }

    private func deleteConfirmedAthlete(_ athlete: Athlete) {
        let db = Firestore.firestore()
        db.collection("users").document(userID).updateData([
            "sponsoredAthletes": FieldValue.arrayRemove([athlete.id]),
            "pendingAthletes": FieldValue.arrayRemove([athlete.id])
        ]) { _ in
            db.collection("users").document(athlete.id).updateData([
                "approvedSponsors": FieldValue.arrayRemove([userID]),
                "pendingSponsors": FieldValue.arrayRemove([userID])
            ]) { _ in fetchAthletes() }
        }
    }

    private func showToastMessage(_ message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }
    }

    private func acceptAllPendingAthletes() {
        for athlete in pendingAthletes {
            acceptAthlete(athlete)
        }
    }

    private func declineAllPendingAthletes() {
        for athlete in pendingAthletes {
            declineAthlete(athlete)
        }
    }

    private func toggleSelection(for athleteID: String) {
        if selectedAthleteIDs.contains(athleteID) {
            selectedAthleteIDs.remove(athleteID)
        } else {
            selectedAthleteIDs.insert(athleteID)
        }
    }
}
