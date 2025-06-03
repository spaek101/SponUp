import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

struct ViewScheduleView: View {
    @Binding var sponsoredAthletes: [Athlete]
    @Binding var challenges: [Challenge]

    @State private var currentEvents: [(event: Event, athlete: Athlete)] = []
    @State private var pastEvents: [(event: Event, athlete: Athlete)] = []

    @AppStorage("userID") private var userID: String = ""

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    var body: some View {
        TabView {
            // MARK: - Current Events Tab
            NavigationView {
                VStack {
                    if currentEvents.isEmpty {
                        Text("There are no events to display.")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .padding(.top, 50)
                    } else {
                        List(currentEvents, id: \.event.id) { pair in
                            NavigationLink(
                                destination: CreateChallengeView(
                                    sponsoredAthletes: $sponsoredAthletes,
                                    challenges: $challenges,
                                    event: pair.event,
                                    preselectedAthletes: [pair.athlete]
                                )
                            ) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("\(pair.athlete.firstName) \(pair.athlete.lastName)")
                                        .font(.headline)

                                    Text("🏷️ \(pair.event.eventTitle)")
                                        .font(.subheadline)

                                    Text("📅 Start: \(pair.event.startDate, formatter: dateFormatter)")
                                        .font(.footnote)

                                    Text("📅 End: \(pair.event.endDate, formatter: dateFormatter)")
                                        .font(.footnote)

                                    Text("🎯 Challenges created: \(countChallenges(for: pair.event))")
                                        .font(.footnote)
                                        .foregroundColor(.blue)
                                        .padding(.top, 4)
                                }
                            }
                        }
                        .listStyle(InsetGroupedListStyle())
                    }
                }
                .navigationTitle("Upcoming Events")
            }
            .tabItem {
                Label("Current", systemImage: "circle.fill")
            }

            // MARK: - Past Events Tab
            NavigationView {
                VStack {
                    if pastEvents.isEmpty {
                        Text("There are no past events to display.")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .padding(.top, 50)
                    } else {
                        List(pastEvents, id: \.event.id) { pair in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(pair.athlete.firstName) \(pair.athlete.lastName)")
                                    .font(.headline)

                                Text("🏷️ \(pair.event.eventTitle)")
                                    .font(.subheadline)

                                Text("📅 Start: \(pair.event.startDate, formatter: dateFormatter)")
                                    .font(.footnote)

                                Text("📅 End: \(pair.event.endDate, formatter: dateFormatter)")
                                    .font(.footnote)

                                Text("🎯 Challenges created: \(countChallenges(for: pair.event))")
                                    .font(.footnote)
                                    .foregroundColor(.blue)
                                    .padding(.top, 4)

                                Text("Event Expired")
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                                    .padding(.top, 2)
                            }
                        }
                        .listStyle(InsetGroupedListStyle())
                    }
                }
                .navigationTitle("Past Events")
            }
            .tabItem {
                Label("Expired", systemImage: "circle.slash.fill")
            }
        }
        .onAppear {
            fetchSchedule()
        }
    }

    // MARK: - Count Challenges for Event
    private func countChallenges(for event: Event) -> Int {
        challenges.filter {
            $0.eventID == event.id && $0.createdBy == userID
        }.count
    }

    // MARK: - Fetch & Sort Events
    private func fetchSchedule() {
        let db = Firestore.firestore()
        currentEvents.removeAll()
        pastEvents.removeAll()

        for athlete in sponsoredAthletes {
            db.collection("events")
                .whereField("athleteID", isEqualTo: athlete.id)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("Error fetching events for \(athlete.firstName): \(error.localizedDescription)")
                        return
                    }

                    let athleteEvents: [Event] = snapshot?.documents.compactMap {
                        try? $0.data(as: Event.self)
                    } ?? []

                    let now = Date()
                    var current: [(event: Event, athlete: Athlete)] = []
                    var past: [(event: Event, athlete: Athlete)] = []

                    for event in athleteEvents {
                        if now <= event.endDate {
                            current.append((event, athlete))
                        } else {
                            past.append((event, athlete))
                        }
                    }

                    current.sort { $0.event.startDate < $1.event.startDate }
                    past.sort { $0.event.startDate > $1.event.startDate }

                    DispatchQueue.main.async {
                        self.currentEvents.append(contentsOf: current)
                        self.pastEvents.append(contentsOf: past)
                    }
                }
        }
    }
}
