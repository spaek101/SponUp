import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct AddEventCalendarView: View {
    var existingEvent: AthleteDashboardView.EventItem? = nil

    @Environment(\.dismiss) var dismiss

    @AppStorage("userID") var userID: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""

    @State private var eventTitle: String = ""
    @State private var startDate: Date? = nil
    @State private var endDate: Date? = nil

    @State private var startTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
    @State private var endTime: Date = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!

    @State private var showAlert = false
    @State private var alertMessage = ""

    private func monthName(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom Back Button
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal)
                }
                Spacer()
            }
            .padding(.top, 12)

            ScrollView {
                VStack(spacing: 20) {
                    Text("Add New Event")
                        .font(.title2)
                        .bold()
                        .padding(.top)

                    TextField("Event Title", text: $eventTitle)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select Date Range")
                            .font(.caption)
                            .foregroundColor(.gray)
                        RangeCalendarView(startDate: $startDate, endDate: $endDate)
                    }
                    .padding(.horizontal)

                    HStack(spacing: 20) {
                        VStack(alignment: .leading) {
                            Text("Start Time")
                                .font(.caption)
                                .foregroundColor(.gray)
                            DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }

                        VStack(alignment: .leading) {
                            Text("End Time")
                                .font(.caption)
                                .foregroundColor(.gray)
                            DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                    }
                    .padding(.horizontal)

                    Spacer()

                    Button(action: saveEvent) {
                        Text("Save Event")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            fetchUserName()

            if let event = existingEvent {
                eventTitle = event.eventTitle
                startDate = event.startDate
                endDate = event.endDate
                startTime = event.startDate
                endTime = event.endDate
            }
        }
        .alert("Missing Info", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private func fetchUserName() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("users").document(uid).getDocument { doc, _ in
            if let data = doc?.data() {
                firstName = data["firstName"] as? String ?? ""
                lastName = data["lastName"] as? String ?? ""
            }
        }
    }

    private func saveEvent() {
        guard !eventTitle.isEmpty else {
            alertMessage = "Please enter an event title."
            showAlert = true
            return
        }

        guard let start = startDate else {
            alertMessage = "Please select a start date."
            showAlert = true
            return
        }

        let end = endDate ?? start

        let calendar = Calendar.current

        let startDateTime = calendar.date(
            bySettingHour: calendar.component(.hour, from: startTime),
            minute: calendar.component(.minute, from: startTime),
            second: 0, of: start) ?? start

        let endDateTime = calendar.date(
            bySettingHour: calendar.component(.hour, from: endTime),
            minute: calendar.component(.minute, from: endTime),
            second: 0, of: end) ?? end

        let data: [String: Any] = [
            "eventTitle": eventTitle,
            "startDate": Timestamp(date: startDateTime),
            "endDate": Timestamp(date: endDateTime),
            "athleteID": userID,
            "firstName": firstName,
            "lastName": lastName
        ]

        if let existing = existingEvent {
            Firestore.firestore().collection("events").document(existing.id).setData(data) { error in
                if error == nil {
                    dismiss()
                } else {
                    alertMessage = "Failed to update event. Please try again."
                    showAlert = true
                }
            }
        } else {
            Firestore.firestore().collection("events").addDocument(data: data) { error in
                if error == nil {
                    dismiss()
                } else {
                    alertMessage = "Failed to save event. Please try again."
                    showAlert = true
                }
            }
        }
    }
}
