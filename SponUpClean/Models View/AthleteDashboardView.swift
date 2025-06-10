import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct AthleteDashboardView: View {
    enum Tab: String, CaseIterable {
        case events, challenges, submissions, sponsors

        var iconName: String {
            switch self {
            case .events: return "calendar"
            case .challenges: return "flag.fill"
            case .submissions: return "tray.full"
            case .sponsors: return "person.3.fill"
            }
        }
    }

    struct EventItem: Identifiable {
        var id: String
        var eventTitle: String
        var startDate: Date
        var endDate: Date
        var firstName: String
        var lastName: String
    }

    @State private var selectedTab: Tab = .events
    @AppStorage("userRole") var userRole: String = ""
    @AppStorage("userID") var userID: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var hasPendingSponsors = false
    @State private var hasRejectedSubmissions = false
    @State private var isSignedOut = false
    @State private var selectedEventTab: String = "open"
    @State private var showSignOutAlert = false
    @State private var showAddEventSheet = false
    @State private var events: [EventItem] = []
    @State private var isLoadingEvents = true
    @State private var selectedEventForEdit: EventItem? = nil
    @State private var isEditingEvent = false
    @State private var eventToEdit: EventItem? = nil
    @State private var challenges: [Challenge] = []
    @State private var selectedChallenge: Challenge? = nil








    var currentEvents: [EventItem] {
        events
            .filter { $0.endDate >= Date() }
            .sorted { $0.startDate < $1.startDate }
    }


    var expiredEvents: [EventItem] {
        events
            .filter { $0.endDate < Date() }
            .sorted { $0.startDate > $1.startDate }
    }

    private var filteredChallenges: [Challenge] {
        let now = Date()
        return challenges.filter {
            let isExpired = Calendar.current.date(byAdding: .day, value: 5, to: $0.endDate)! <= now
            return selectedEventTab == "open" ? !isExpired : isExpired
        }
    }


    var body: some View {
        NavigationStack {
            ZStack {
                // Background image with black overlay
                VStack(spacing: 0) {
                    ZStack {
                        Image("baseball_bg")
                            .resizable()
                            .scaledToFill()
                            .frame(height: 300)
                            .clipped()

                        Color.black.opacity(0.7)
                            .frame(height: 300)
                    }
                    Spacer()
                }
                .ignoresSafeArea()

                // Gradient overlay blending from transparent to blue
                LinearGradient(colors: [Color.clear, Color.blue.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                // Main content
                VStack(spacing: 0) {
                    HStack {
                        Spacer()

                        NavigationLink(destination: AthleteProfileView()) {
                            Image(systemName: "person.crop.circle")
                                .resizable()
                                .frame(width: 28, height: 28)
                                .foregroundColor(.white)
                        }
                        .padding()
                    }

                    Text(selectedTab.rawValue.capitalized)
                        .font(.title3)
                        .bold()
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 4)

                    HStack(spacing: 28) {
                        ForEach(Tab.allCases, id: \.self) { tab in
                            Circle()
                                .fill(selectedTab == tab ? Color.white : Color.white.opacity(0.4))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: tab.iconName)
                                        .foregroundColor(selectedTab == tab ? .orange : .white.opacity(0.7))
                                        .font(.system(size: 22))
                                )
                                .onTapGesture {
                                    selectedTab = tab
                                }
                        }
                    }
                    .padding(.top)

                    Spacer()

                    ZStack {
                        RoundedRectangle(cornerRadius: 30)
                            .fill(Color.white)
                            .ignoresSafeArea(edges: .bottom)

                        VStack(alignment: .leading, spacing: 16) {
                            Group {
                                switch selectedTab {
                                case .events:
                                    VStack(spacing: 16) {
                                        Picker("Event Filter", selection: $selectedEventTab) {
                                            Text("Open Events").tag("open")
                                            Text("Closed Events").tag("closed")
                                        }
                                        .pickerStyle(SegmentedPickerStyle())
                                        .padding(.top)
                                        .padding(.horizontal)

                                        ScrollView {
                                            VStack(alignment: .leading, spacing: 24) {
                                                if isLoadingEvents {
                                                    ProgressView()
                                                        .padding()
                                                } else {
                                                    if selectedEventTab == "open" {
                                                        let groupedOpen = Dictionary(grouping: currentEvents) { event -> Date in
                                                            let calendar = Calendar.current
                                                            let components = calendar.dateComponents([.year, .month], from: event.startDate)
                                                            return calendar.date(from: components)!
                                                        }

                                                        let sortedOpenKeys = groupedOpen.keys.sorted(by: <) // ASCENDING: upcoming months first

                                                        if groupedOpen.isEmpty {
                                                            Text("No open events found.")
                                                                .foregroundColor(.gray)
                                                                .padding(.top)
                                                        } else {
                                                            ForEach(sortedOpenKeys, id: \.self) { monthDate in
                                                                let eventsInMonth = groupedOpen[monthDate]!.sorted(by: { $0.startDate < $1.startDate }) // ASCENDING within month

                                                                VStack(alignment: .leading, spacing: 12) {
                                                                    Text(monthName(from: monthDate)) // ✅ Only month name
                                                                        .font(.title3)
                                                                        .bold()
                                                                        .padding(.horizontal)

                                                                    ForEach(Array(eventsInMonth.enumerated()), id: \.element.id) { index, event in
                                                                        HStack(alignment: .top, spacing: 12) {
                                                                            VStack(spacing: 2) {
                                                                                Text(dayNumber(from: event.startDate))
                                                                                    .font(.title2)
                                                                                    .bold()
                                                                                    .foregroundColor(.black)
                                                                                Text(dayName(from: event.startDate))
                                                                                    .font(.caption)
                                                                                    .foregroundColor(.gray)
                                                                            }
                                                                            .frame(width: 40)

                                                                            ZStack(alignment: .topTrailing) {
                                                                                RoundedRectangle(cornerRadius: 10)
                                                                                    .fill(Color.white)
                                                                                    .shadow(color: .gray.opacity(0.2), radius: 4, x: 0, y: 2)

                                                                                Menu {
                                                                                    Button("Edit") {
                                                                                        eventToEdit = event
                                                                                    }

                                                                                    Button("Delete", role: .destructive) {
                                                                                        deleteEvent(event)
                                                                                    }
                                                                                } label: {
                                                                                    VStack(alignment: .leading, spacing: 8) {
                                                                                        Text(event.eventTitle)
                                                                                            .font(.subheadline)
                                                                                            .foregroundColor(.black)
                                                                                            .bold()
                                                                                            .padding(.bottom, 2)

                                                                                        Rectangle()
                                                                                            .fill(Color.orange.opacity(0.4))
                                                                                            .frame(height: 1)

                                                                                        Text("\(timeOnly(from: event.startDate)) - \(timeOnly(from: event.endDate))")
                                                                                            .font(.caption)
                                                                                            .foregroundColor(.gray)

                                                                                        Spacer()
                                                                                    }
                                                                                    .padding(.horizontal)
                                                                                    .padding(.vertical, 12)
                                                                                }

                                                                                // Three dots for design only
                                                                                Image(systemName: "ellipsis")
                                                                                    .rotationEffect(.degrees(90))
                                                                                    .foregroundColor(.gray)
                                                                                    .padding(.trailing, 8)
                                                                                    .padding(.top, 15)

                                                                            }

                                                                        }
                                                                        .padding(.horizontal)
                                                                    }
                                                                }
                                                            }
                                                        }


                                                    } else {
                                                        let groupedClosed = Dictionary(grouping: expiredEvents) { event -> Date in
                                                            // Group by first day of the month (preserves year/month distinction)
                                                            let calendar = Calendar.current
                                                            let components = calendar.dateComponents([.year, .month], from: event.startDate)
                                                            return calendar.date(from: components)!
                                                        }

                                                        let sortedMonthKeys = groupedClosed.keys.sorted(by: >) // DESCENDING: most recent months first

                                                        if groupedClosed.isEmpty {
                                                            Text("No closed events found.")
                                                                .foregroundColor(.gray)
                                                                .padding(.top)
                                                        } else {
                                                            ForEach(sortedMonthKeys, id: \.self) { monthDate in
                                                                let eventsInMonth = groupedClosed[monthDate]!.sorted(by: { $0.startDate < $1.startDate }) // ASCENDING: earliest first

                                                                VStack(alignment: .leading, spacing: 12) {
                                                                    Text(monthName(from: monthDate)) // Display only the month name
                                                                        .font(.title3)
                                                                        .bold()
                                                                        .padding(.horizontal)

                                                                    ForEach(Array(eventsInMonth.enumerated()), id: \.element.id) { index, event in
                                                                        HStack(alignment: .top, spacing: 12) {
                                                                            VStack(spacing: 2) {
                                                                                Text(dayNumber(from: event.startDate))
                                                                                    .font(.title2)
                                                                                    .bold()
                                                                                    .foregroundColor(.black)
                                                                                Text(dayName(from: event.startDate))
                                                                                    .font(.caption)
                                                                                    .foregroundColor(.gray)
                                                                            }
                                                                            .frame(width: 40)

                                                                            ZStack(alignment: .topTrailing) {
                                                                                RoundedRectangle(cornerRadius: 10)
                                                                                    .fill(Color.white)
                                                                                    .shadow(color: .gray.opacity(0.2), radius: 4, x: 0, y: 2)

                                                                                Menu {
                                                                                    Button("Edit") {
                                                                                        eventToEdit = event
                                                                                    }


                                                                                    Button("Delete", role: .destructive) {
                                                                                        deleteEvent(event)
                                                                                    }
                                                                                } label: {
                                                                                    VStack(alignment: .leading, spacing: 8) {
                                                                                        Text(event.eventTitle)
                                                                                            .font(.subheadline)
                                                                                            .foregroundColor(.black)
                                                                                            .bold()
                                                                                            .padding(.bottom, 2)

                                                                                        Rectangle()
                                                                                            .fill(Color.orange.opacity(0.4))
                                                                                            .frame(height: 1)

                                                                                        Text("\(timeOnly(from: event.startDate)) - \(timeOnly(from: event.endDate))")
                                                                                            .font(.caption)
                                                                                            .foregroundColor(.gray)


                                                                                        Spacer()
                                                                                    }
                                                                                    .padding(.horizontal)
                                                                                    .padding(.vertical, 12)
                                                                                }

                                                                                // Three dots for design only
                                                                                Image(systemName: "ellipsis")
                                                                                    .rotationEffect(.degrees(90))
                                                                                    .foregroundColor(.gray)
                                                                                    .padding(.trailing, 8)
                                                                                    .padding(.top, 15)

                                                                            }

                                                                        }
                                                                        .padding(.horizontal)
                                                                    }
                                                                }
                                                            }
                                                        }

                                                    }
                                                }
                                            }
                                            .padding(.top)
                                        }

                                    }

                                case .challenges:
                                    VStack(spacing: 16) {
                                        if let challenge = selectedChallenge {
                                            // ✅ Show Challenge Detail View Fullscreen in White Area
                                            HStack {
                                                Button(action: {
                                                    selectedChallenge = nil // Go back to list
                                                }) {
                                                    Image(systemName: "chevron.left")
                                                    Text("Back to Challenges")
                                                }
                                                .font(.subheadline)
                                                .foregroundColor(.blue)
                                                .padding(.horizontal)
                                                .padding(.top)

                                                Spacer()
                                            }

                                            ScrollView {
                                                ChallengeDetailViewAthlete(challenge: challenge)
                                                    .padding()
                                            }

                                        } else {
                                            // ✅ Show Challenge List
                                            Picker("Challenge Filter", selection: $selectedEventTab) {
                                                Text("Open Challenges").tag("open")
                                                Text("Closed Challenges").tag("closed")
                                            }
                                            .pickerStyle(SegmentedPickerStyle())
                                            .padding(.top)
                                            .padding(.horizontal)

                                            let groupedChallenges = Dictionary(grouping: filteredChallenges) { challenge -> Date in
                                                let calendar = Calendar.current
                                                let components = calendar.dateComponents([.year, .month], from: challenge.startDate)
                                                return calendar.date(from: components)!
                                            }

                                            let sortedMonthKeys = selectedEventTab == "closed"
                                                ? groupedChallenges.keys.sorted(by: >)  // Descending month order
                                                : groupedChallenges.keys.sorted(by: <)  // Ascending month order



                                            ScrollView {
                                                VStack(alignment: .leading, spacing: 24) {
                                                    if groupedChallenges.isEmpty {
                                                        Text("No \(selectedEventTab == "open" ? "open" : "closed") challenges found.")
                                                            .foregroundColor(.gray)
                                                            .padding(.top)
                                                    } else {
                                                        ForEach(sortedMonthKeys, id: \.self) { monthDate in
                                                            let challengesInMonth = selectedEventTab == "closed"
                                                                ? groupedChallenges[monthDate]!.sorted(by: { $0.startDate > $1.startDate })  // Descending
                                                                : groupedChallenges[monthDate]!.sorted(by: { $0.startDate < $1.startDate })  // Ascending


                                                            VStack(alignment: .leading, spacing: 12) {
                                                                Text(monthName(from: monthDate))
                                                                    .font(.title3)
                                                                    .bold()
                                                                    .padding(.horizontal)

                                                                ForEach(Array(challengesInMonth.enumerated()), id: \.element.id) { index, challenge in
                                                                    HStack(alignment: .top, spacing: 12) {
                                                                        VStack(spacing: 2) {
                                                                            Text(dayNumber(from: challenge.startDate))
                                                                                .font(.title2)
                                                                                .bold()
                                                                                .foregroundColor(.black)

                                                                            Text(dayName(from: challenge.startDate))
                                                                                .font(.caption)
                                                                                .foregroundColor(.gray)
                                                                        }
                                                                        .frame(width: 40)
                                                                        .frame(maxHeight: .infinity, alignment: .top)
                                                                        .frame(minHeight: 120, alignment: .top)
                                                                        .multilineTextAlignment(.center)

                                                                        GeometryReader { geo in
                                                                            Button(action: {
                                                                                selectedChallenge = challenge
                                                                            }) {
                                                                                ChallengeCardStyledLikeEventCard(challenge: challenge)
                                                                            }
                                                                            .buttonStyle(PlainButtonStyle())
                                                                            .frame(width: geo.size.width)
                                                                        }
                                                                        .frame(maxWidth: .infinity)
                                                                    }
                                                                    .frame(maxWidth: .infinity)
                                                                    .padding(.horizontal)
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                                .padding(.vertical)
                                            }
                                        }
                                    }





                                case .submissions:
                                    Text("Performance results you submitted (e.g. stats, highlights)")
                                        .foregroundColor(.gray)
                                        .padding(.top)

                                case .sponsors:
                                    Text("Your sponsors")
                                        .foregroundColor(.gray)
                                        .padding(.top)
                                }
                            }

                            Spacer()

                            if selectedTab == .events {
                                Button(action: {
                                    showAddEventSheet = true
                                }) {
                                    Text("Add Event")
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.orange)
                                        .foregroundColor(.white)
                                        .cornerRadius(16)
                                }
                                .padding(.bottom, 30)
                                .sheet(item: $eventToEdit, onDismiss: {
                                    fetchUploadedEvents()
                                }) { event in
                                    AddEventCalendarView(existingEvent: event)
                                }
                                .sheet(isPresented: $showAddEventSheet, onDismiss: {
                                    fetchUploadedEvents()
                                }) {
                                    AddEventCalendarView()
                                }
                            }

                        }
                        .padding(.horizontal)
                    }
                }
            }
            .onAppear {
                fetchUserProfile()
                fetchPendingSponsors()
                fetchRejectedSubmissions()
                fetchUploadedEvents()
                fetchChallenges() // ← ADD THIS
            }
            .onChange(of: selectedTab) { newTab in
                if newTab == .challenges {
                    fetchChallenges()
                }
            }


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
            .navigationBarHidden(true)
        }
    }

    // MARK: - Helpers

    private func fetchUploadedEvents() {
        guard !userID.isEmpty else { return }

        isLoadingEvents = true

        Firestore.firestore().collection("events")
            .whereField("athleteID", isEqualTo: userID)
            .getDocuments { snapshot, error in
                defer { isLoadingEvents = false }

                guard let docs = snapshot?.documents else {
                    return
                }

                self.events = docs.compactMap { doc in
                    let data = doc.data()
                    guard
                        let title = data["eventTitle"] as? String,
                        let startTimestamp = data["startDate"] as? Timestamp,
                        let endTimestamp = data["endDate"] as? Timestamp
                    else {
                        return nil
                    }

                    return EventItem(
                        id: doc.documentID,
                        eventTitle: title,
                        startDate: startTimestamp.dateValue(),
                        endDate: endTimestamp.dateValue(),
                        firstName: "",
                        lastName: ""
                    )
                }
            }
    }


    private func bottomButtonTitle() -> String {
        switch selectedTab {
        case .events: return "Add Event"
        case .challenges: return "Upload Results"
        case .submissions: return ""
        case .sponsors: return "Add Sponsor"
        }
    }

    private func deleteEvent(_ event: EventItem) {
        Firestore.firestore().collection("events").document(event.id).delete { error in
            if error == nil {
                events.removeAll { $0.id == event.id }
            }
        }
    }

    private func dayNumber(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private func monthName(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL" // Just the month name
        return formatter.string(from: date)
    }

    private func dayName(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }

    private func timeOnly(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func colorForIndex(_ index: Int) -> Color {
        let colors: [Color] = [.blue, .yellow, .pink, .green, .orange]
        return colors[index % colors.count]
    }

    private func fetchUserProfile() {
        let db = Firestore.firestore()
        guard let uid = Auth.auth().currentUser?.uid else { return }

        db.collection("users").document(uid).getDocument { document, _ in
            if let data = document?.data() {
                self.firstName = data["firstName"] as? String ?? ""
                self.lastName = data["lastName"] as? String ?? ""
            }
        }
    }

    private func fetchPendingSponsors() {
        Firestore.firestore().collection("users").document(userID).getDocument { doc, _ in
            guard let data = doc?.data() else { return }

            let approved = data["sponsorIDs"] as? [String] ?? []
            let pending = data["pendingSponsors"] as? [String] ?? []
            self.hasPendingSponsors = !pending.filter { !approved.contains($0) }.isEmpty
        }
    }

    private func fetchRejectedSubmissions() {
        Firestore.firestore().collection("submissions")
            .whereField("athleteID", isEqualTo: userID)
            .whereField("status", isEqualTo: "Rejected")
            .getDocuments { snapshot, _ in
                self.hasRejectedSubmissions = !(snapshot?.documents.isEmpty ?? true)
            }
    }
    private func fetchChallenges() {
        Firestore.firestore().collection("challenges")
            .whereField("assignedAthletes", arrayContains: userID)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error listening for challenges: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("No challenges found.")
                    return
                }

                self.challenges = documents.compactMap { doc in
                    try? doc.data(as: Challenge.self)
                }
            }
    }


    private func signOut() {
        try? Auth.auth().signOut()
        userID = ""
        userRole = ""
        isSignedOut = true
    }
}

    

