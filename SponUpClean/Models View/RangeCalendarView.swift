import SwiftUI

struct RangeCalendarView: View {
    @Binding var startDate: Date?
    @Binding var endDate: Date?

    @State private var currentMonth: Date = Date()

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                }) {
                    Image(systemName: "chevron.left")
                        .padding(6)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }

                Spacer()

                Text(monthYearFormatter.string(from: currentMonth))
                    .font(.headline)

                Spacer()

                Button(action: {
                    currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                }) {
                    Image(systemName: "chevron.right")
                        .padding(6)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)

            LazyVGrid(columns: columns, spacing: 10) {
                let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]
                ForEach(Array(daysOfWeek.enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }


                ForEach(generateDates(for: currentMonth), id: \.self) { date in
                    Button(action: {
                        handleDateSelection(date)
                    }) {
                        Text("\(calendar.component(.day, from: date))")
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(backgroundColor(for: date))
                            .cornerRadius(8)
                            .foregroundColor(foregroundColor(for: date))
                    }
                    .disabled(!calendar.isDate(date, equalTo: currentMonth, toGranularity: .month))
                }
            }
            .padding(.horizontal)
        }
    }

    private func generateDates(for baseDate: Date) -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: baseDate),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }

        var dates: [Date] = []
        var current = monthFirstWeek.start

        while current < monthInterval.end || calendar.component(.weekday, from: current) != 1 {
            dates.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }

        return dates
    }

    private func handleDateSelection(_ date: Date) {
        if startDate == nil || (startDate != nil && endDate != nil) {
            startDate = date
            endDate = nil
        } else if let start = startDate {
            if date < start {
                startDate = date
                endDate = nil
            } else if calendar.isDate(date, inSameDayAs: start) {
                // Auto select range if same day
                endDate = start
            } else {
                endDate = date
            }
        }
    }

    private func backgroundColor(for date: Date) -> Color {
        if let start = startDate, let end = endDate {
            if calendar.isDate(date, inSameDayAs: start) || calendar.isDate(date, inSameDayAs: end) || (date > start && date < end) {
                return Color.blue.opacity(0.2)
            }
        } else if let start = startDate, calendar.isDate(date, inSameDayAs: start) {
            return Color.blue.opacity(0.2)
        }
        return Color.clear
    }

    private func foregroundColor(for date: Date) -> Color {
        if calendar.isDateInToday(date) {
            return .red
        } else {
            return .primary
        }
    }

    private var monthYearFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }
}
