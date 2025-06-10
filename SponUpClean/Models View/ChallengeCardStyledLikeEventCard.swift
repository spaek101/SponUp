import SwiftUI

struct ChallengeCardStyledLikeEventCard: View {
    var challenge: Challenge
    var status: String?

    private var dateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        let start = formatter.string(from: challenge.startDate)
        let end = formatter.string(from: challenge.endDate)
        return "\(start) - \(end) +5 days to submit"
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .shadow(color: .gray.opacity(0.2), radius: 4, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 8) {
                // Title
                Text(challenge.title)
                    .font(.subheadline)
                    .foregroundColor(.black)
                    .bold()

                // Divider
                Rectangle()
                    .fill(Color.orange.opacity(0.4))
                    .frame(height: 1)

                // Date
                Text(dateRange)
                    .font(.caption2)
                    .foregroundColor(.gray)

                // Time remaining or status
                let remaining = timeRemaining()

                if !remaining.value.isEmpty {
                    HStack(spacing: 4) {
                        Text(remaining.label)
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(remaining.value)
                            .font(.caption2)
                            .foregroundColor(remaining.color)
                    }
                } else if !remaining.label.isEmpty {
                    Text(remaining.label)
                        .font(.caption2)
                        .foregroundColor(remaining.color)
                }

                // Status Row (either status dot or event-in-progress message)
                if shouldShowStatusDot(status: status) {
                    if let msg = statusMessage(for: status) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(msg.color)
                                .frame(width: 8, height: 8)
                            Text(msg.text)
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                } else if isEventInProgress() {
                    HStack(spacing: 6) {
                        Text("Event in progress...")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            Image(systemName: "ellipsis")
                .rotationEffect(.degrees(90))
                .foregroundColor(.gray)
                .padding(.trailing, 8)
                .padding(.top, 15)
        }
        
        .frame(maxWidth: .infinity) // No fixed height
    }

    // MARK: - Logic

    private func timeRemaining() -> (label: String, value: String, color: Color) {
        let now = Date()
        let start = challenge.startDate
        let end = challenge.endDate
        let submissionDeadline = end.addingTimeInterval(5 * 86400)

        if now < start {
            let time = start.timeIntervalSince(now)
            return ("Starts in:", formatTime(time), .gray)
        } else if now >= start && now <= end {
            return ("", "", .clear) // show event-in-progress via isEventInProgress()
        } else if now > end && now <= submissionDeadline {
            let time = submissionDeadline.timeIntervalSince(now)
            return ("Submission ends in:", formatTime(time), .red)
        } else {
            return ("Submission closed", "", .gray)
        }
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let days = Int(interval / 86400)
        let hours = Int((interval.truncatingRemainder(dividingBy: 86400)) / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(days)d \(hours)h \(minutes)m"
    }

    private func statusMessage(for status: String?) -> (text: String, color: Color)? {
        guard let status = status?.lowercased() else { return nil }
        switch status {
        case "approved": return ("Approved", .green)
        case "rewarded": return ("Rewarded", .green)
        case "rejected": return ("Rejected", .red)
        case "pending": return ("Pending Review", .gray)
        default: return nil
        }
    }

    private func shouldShowStatusDot(status: String?) -> Bool {
        guard let status = status?.lowercased() else { return false }
        return ["pending", "approved", "rejected", "rewarded"].contains(status)
    }

    private func isEventInProgress() -> Bool {
        let now = Date()
        return now >= challenge.startDate && now <= challenge.endDate && !shouldShowStatusDot(status: status)
    }
}
