import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Model for the event
struct EventItem: Identifiable {
    var id: String
    var eventTitle: String
    var startDate: Date
    var endDate: Date
    var firstName: String
    var lastName: String
}

// MARK: - Alert Type Enum
enum AlertType: Identifiable {
    case invalidInput(String)
    case duplicateEvent
    case deleteConfirmation

    var id: Int {
        switch self {
        case .invalidInput: return 0
        case .duplicateEvent: return 1
        case .deleteConfirmation: return 2
        }
    }
}

// MARK: - DatePickerView
struct DatePickerView: View {
    @Binding var selectedDate: Date
    @Binding var formattedDate: String
    var isStartDate: Bool
    var minDate: Date

    @Environment(\.presentationMode) var presentationMode
    @State private var tempDate: Date

    init(selectedDate: Binding<Date>, formattedDate: Binding<String>, isStartDate: Bool, minDate: Date) {
        _selectedDate = selectedDate
        _formattedDate = formattedDate
        _tempDate = State(initialValue: selectedDate.wrappedValue)
        self.isStartDate = isStartDate
        self.minDate = minDate
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                        .padding(5)
                }
                .padding(.top, 10)
                .padding(.trailing, 10)
            }

            Text("Select Date")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top)

            DatePicker("Select Date", selection: $tempDate, in: minDate..., displayedComponents: .date)
                .datePickerStyle(GraphicalDatePickerStyle())
                .padding(.horizontal)
                .frame(maxWidth: .infinity, maxHeight: 300)
                .background(Color.white)
                .cornerRadius(10)

            Spacer()
        }
        .onAppear { tempDate = selectedDate }
        .onChange(of: tempDate) {
            if tempDate != selectedDate {
                selectedDate = tempDate
                formattedDate = formatDate(tempDate)
                presentationMode.wrappedValue.dismiss()
            }
        }

        .padding()
        .background(Color(UIColor.systemGroupedBackground))
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - EventCardView
struct EventCardView: View {
    var event: EventItem
    var onDelete: () -> Void

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.eventTitle)
                    .font(.headline)

                Text("\(formattedDate(event.startDate)) - \(formattedDate(event.endDate))")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .cornerRadius(10)
            .shadow(radius: 5)
            .padding(.horizontal)

            VStack {
                HStack {
                    Spacer()
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                            .padding(2)
                    }
                    .padding(.top, 5)
                    .padding(.trailing, 20)
                }
                Spacer()
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - UploadScheduleView
struct UploadScheduleView: View {
    @State private var eventTitle = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var formattedStartDate = ""
    @State private var formattedEndDate = ""

    @State private var showStartDatePicker = false
    @State private var showEndDatePicker = false

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var uploadedEvents: [EventItem] = []
    @State private var activeAlert: AlertType?
    @State private var eventToDelete: EventItem?

    @AppStorage("userID") var userID: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Create an Event")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)

                TextField("Event Title", text: $eventTitle)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                Button(action: { showStartDatePicker.toggle() }) {
                    Text("Start Date: \(formattedStartDate.isEmpty ? "Select a date" : formattedStartDate)")
                        .padding()
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                }
                .sheet(isPresented: $showStartDatePicker, onDismiss: {
                    if endDate < startDate {
                        endDate = startDate
                        formattedEndDate = formattedDate(endDate)
                    }
                }) {
                    DatePickerView(
                        selectedDate: $startDate,
                        formattedDate: $formattedStartDate,
                        isStartDate: true,
                        minDate: Calendar.current.startOfDay(for: Date())
                    )
                }

                Button(action: { showEndDatePicker.toggle() }) {
                    Text("End Date: \(formattedEndDate.isEmpty ? "Select a date" : formattedEndDate)")
                        .padding()
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                }
                .sheet(isPresented: $showEndDatePicker) {
                    DatePickerView(
                        selectedDate: $endDate,
                        formattedDate: $formattedEndDate,
                        isStartDate: false,
                        minDate: startDate
                    )
                }

                Button(action: validateAndUploadEvent) {
                    Text("Create and Share with Sponsors")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                VStack(spacing: 10) {
                    ForEach(uploadedEvents.sorted {
                        if $0.startDate != $1.startDate {
                            return $0.startDate < $1.startDate
                        } else if $0.endDate != $1.endDate {
                            return $0.endDate < $1.endDate
                        } else {
                            return $0.eventTitle.localizedCompare($1.eventTitle) == .orderedAscending
                        }
                    }) { event in
                        EventCardView(event: event) {
                            eventToDelete = event
                            activeAlert = .deleteConfirmation
                        }
                    }
                }

                Spacer()
            }
            .padding()
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .invalidInput(let message):
                return Alert(
                    title: Text(message == "Event was created successfully!" ? "Success" : "Invalid Input"),
                    message: Text(message),
                    dismissButton: .default(Text("OK"))
                )
            case .duplicateEvent:
                return Alert(
                    title: Text("Duplicate Event"),
                    message: Text("An event with the same title and dates already exists. Proceed?"),
                    primaryButton: .destructive(Text("Proceed")) {
                        uploadSchedule(skipDuplicateCheck: true)
                    },
                    secondaryButton: .cancel()
                )
            case .deleteConfirmation:
                return Alert(
                    title: Text("Are you sure?"),
                    message: Text("Do you really want to delete this event?"),
                    primaryButton: .destructive(Text("Delete")) {
                        if let event = eventToDelete {
                            deleteEvent(event)
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .onAppear {
            formattedStartDate = formattedDate(startDate)
            formattedEndDate = formattedDate(endDate)
            fetchUserData()
            fetchUploadedEvents()
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func validateAndUploadEvent() {
        if eventTitle.isEmpty {
            activeAlert = .invalidInput("Event title cannot be empty.")
        } else if endDate < startDate {
            activeAlert = .invalidInput("End date cannot be before the start date.")
        } else if uploadedEvents.contains(where: {
            $0.eventTitle == eventTitle &&
            Calendar.current.isDate($0.startDate, inSameDayAs: startDate) &&
            Calendar.current.isDate($0.endDate, inSameDayAs: endDate)
        }) {
            activeAlert = .duplicateEvent
        } else {
            uploadSchedule()
        }
    }

    private func fetchUserData() {
        let db = Firestore.firestore()
        guard let userID = Auth.auth().currentUser?.uid else { return }

        db.collection("users").document(userID).getDocument { document, _ in
            if let data = document?.data() {
                self.firstName = data["firstName"] as? String ?? ""
                self.lastName = data["lastName"] as? String ?? ""
            }
        }
    }

    private func fetchUploadedEvents() {
        guard !userID.isEmpty else { return }
        let db = Firestore.firestore()

        db.collection("events")
            .whereField("athleteID", isEqualTo: userID)
            .getDocuments { snapshot, _ in
                let events = snapshot?.documents.compactMap { doc -> EventItem? in
                    let data = doc.data()
                    guard
                        let title = data["eventTitle"] as? String,
                        let start = data["startDate"] as? Timestamp,
                        let end = data["endDate"] as? Timestamp,
                        let first = data["firstName"] as? String,
                        let last = data["lastName"] as? String
                    else { return nil }

                    return EventItem(id: doc.documentID, eventTitle: title, startDate: start.dateValue(), endDate: end.dateValue(), firstName: first, lastName: last)
                } ?? []

                DispatchQueue.main.async {
                    self.uploadedEvents = events.filter { $0.endDate >= Date() }

                }
            }
    }

    private func deleteEvent(_ event: EventItem) {
        let db = Firestore.firestore()
        db.collection("events").document(event.id).delete { error in
            if error == nil {
                uploadedEvents.removeAll { $0.id == event.id }
            }
        }
    }

    private func uploadSchedule(skipDuplicateCheck: Bool = false) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startDate)
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate)!

        let db = Firestore.firestore()
        let data: [String: Any] = [
            "eventTitle": eventTitle,
            "startDate": startOfDay,
            "endDate": endOfDay,
            "athleteID": userID,
            "firstName": firstName,
            "lastName": lastName
        ]

        db.collection("events").addDocument(data: data) { error in
            if error == nil {
                fetchUploadedEvents()
                eventTitle = ""
                startDate = Date()
                endDate = Date()
                formattedStartDate = formattedDate(startDate)
                formattedEndDate = formattedDate(endDate)

                DispatchQueue.main.async {
                    activeAlert = .invalidInput("Event was created successfully!")
                }
            }
        }
    }
}
