import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ReviewSubmissionDetailView: View {
    let challengeID: String
    let submission: ReviewedSubmission

    @State private var challenge = ChallengeInfo(title: "Untitled Challenge", reward: "", achievements: [], startDate: Date(), endDate: Date())
    @State private var status: String
    @State private var isApproved = false
    @State private var isRejected = false
    @State private var isRewarded = false
    @State private var approveDisabled = false
    @State private var rejectDisabled = false
    @State private var deliveryMethod: String = "Digital"
    @State private var redemptionCode: String = ""
    @State private var trackingNumber: String = ""
    @State private var carrier: String = ""
    @State private var estimatedDeliveryDate = Date()
    @State private var notes: String = ""
    @State private var validationFailed = false
    @State private var currentImageIndex: Int = 0
    @State private var scale: CGFloat = 1.0  // Pinch-to-zoom state
    struct IdentifiableImageURL: Identifiable {
        let id = UUID()
        let url: String
    }
    @State private var selectedImage: IdentifiableImageURL? = nil

    @State private var athleteEmail: String = ""
    @State private var shippingAddress: String = ""

    init(challengeID: String, submission: ReviewedSubmission) {
        self.challengeID = challengeID
        self.submission = submission
        _status = State(initialValue: submission.status.capitalized)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(challenge.title)")
                    .font(.title)
                    .bold()

                Text("Reward: \(challenge.reward)")
                Text("Start: \(challenge.startDate.formatted(date: .abbreviated, time: .omitted))")
                Text("End: \(challenge.endDate.formatted(date: .abbreviated, time: .omitted))")

                Text("Challenge:")
                    .font(.headline)
                ForEach(challenge.achievements, id: \.type) { ach in
                    Text("\(ach.type)")
                }


                Divider()

                Text("Submission by \(submission.athleteName)")
                    .font(.title2)
                    .bold()

                TabView(selection: $currentImageIndex) {
                    ForEach(submission.imageURLs.indices, id: \.self) { index in
                        let urlString = submission.imageURLs[index]
                        if let url = URL(string: urlString) {
                            Button {
                                selectedImage = IdentifiableImageURL(url: urlString)
                            } label: {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .cornerRadius(10)
                                            .padding()
                                    case .failure:
                                        Text("Failed to load image")
                                            .foregroundColor(.red)
                                    case .empty:
                                        ProgressView()
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .tag(index)
                        }
                    }
                }
                .frame(height: 280)
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

                if submission.imageURLs.count > 1 {
                    HStack(spacing: 8) {
                        ForEach(submission.imageURLs.indices, id: \.self) { index in
                            Circle()
                                .fill(currentImageIndex == index ? Color.primary : Color.gray.opacity(0.4))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
                }

                Divider()
                Text("Status: \(status)")
                    .foregroundColor(.gray)

                HStack {
                    Button("Approve") {
                        updateStatus(to: "approved")
                    }
                    .disabled(approveDisabled)
                    .buttonStyle(PrimaryButton(color: approveDisabled ? .gray : .green))

                    Button("Reject") {
                        updateStatus(to: "rejected")
                    }
                    .disabled(rejectDisabled)
                    .buttonStyle(PrimaryButton(color: rejectDisabled ? .gray : .red))
                }

                if isApproved && !isRewarded {
                    Divider()
                    Text("Reward Delivery Method")
                        .font(.headline)

                    Picker("Method", selection: $deliveryMethod) {
                        Text("Digital Delivery").tag("Digital")
                        Text("Physical Delivery").tag("Physical")
                        Text("Hand Delivery").tag("Hand-delivered")
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    if deliveryMethod == "Digital" {
                        Text("Recipient Email:")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text(athleteEmail)
                            .padding(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)

                        TextField("Redemption Code", text: $redemptionCode)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    } else if deliveryMethod == "Physical" {
                        Text("Shipping Address:")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text(shippingAddress)
                            .padding(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)

                        TextField("Tracking Number", text: $trackingNumber)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)

                        TextField("Carrier (Optional)", text: $carrier)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)

                        DatePicker("Estimated Delivery Date", selection: $estimatedDeliveryDate, displayedComponents: .date)
                            .padding()
                    } else {
                        TextField("Notes (Optional)", text: $notes)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }

                    if validationFailed {
                        Text("⚠️ Please fill required fields.")
                            .foregroundColor(.red)
                    }

                    Button("Mark Reward as Released") {
                        if validateDeliveryFields() {
                            updateStatus(to: "rewarded", includeDelivery: true)
                        } else {
                            validationFailed = true
                        }
                    }
                    .buttonStyle(PrimaryButton(color: .blue))
                }

                if isRewarded {
                    Divider()
                    Text("🎁 Reward Sent")
                        .font(.headline)
                    Text("Delivery Method: \(deliveryMethod)")
                    if deliveryMethod == "Digital" {
                        Text("Email: \(athleteEmail)")
                        Text("Code: \(redemptionCode)")
                    } else if deliveryMethod == "Physical" {
                        Text("Address: \(shippingAddress)")
                        Text("Tracking #: \(trackingNumber)")
                        if !carrier.isEmpty { Text("Carrier: \(carrier)") }
                        Text("Estimated Delivery: \(estimatedDeliveryDate.formatted(.dateTime.month().day().year()))")
                    } else if deliveryMethod == "Hand-delivered", !notes.isEmpty {
                        Text("Notes: \(notes)")
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Review Submission")
        .onAppear {
            loadChallenge()
            loadStatus()
            fetchAthleteDeliveryInfo()
        }
        .sheet(item: $selectedImage) { image in
            ZStack(alignment: .topTrailing) {
                Color.black.ignoresSafeArea()

                GeometryReader { geometry in
                    ScrollView([.vertical, .horizontal], showsIndicators: false) {
                        if let url = URL(string: image.url) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: geometry.size.width, height: geometry.size.height)
                                        .scaleEffect(scale)  // Pinch-to-zoom effect
                                        .clipped()
                                        .gesture(
                                            MagnificationGesture()
                                                .onChanged { value in
                                                    scale = value
                                                }
                                        )
                                        .padding()
                                case .failure:
                                    Text("Failed to load image")
                                        .foregroundColor(.white)
                                case .empty:
                                    ProgressView()
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                    }
                }

                Button(action: { selectedImage = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                        .padding()
                }
            }
        }
    }

    private func loadChallenge() {
        Firestore.firestore().collection("challenges").document(challengeID).getDocument { snapshot, _ in
            guard let data = snapshot?.data() else { return }

            let title = data["title"] as? String ?? "Untitled"
            let reward = data["reward"] as? String ?? ""
            let start = (data["startDate"] as? Timestamp)?.dateValue() ?? Date()
            let end = (data["endDate"] as? Timestamp)?.dateValue() ?? Date()

            var achievements: [ChallengeAchievement] = []

            if let rawAchievements = data["achievements"] as? [[String: Any]] {
                achievements = rawAchievements.compactMap { dict in
                    guard let type = dict["type"] as? String,
                          let quantity = dict["quantity"] as? Int else { return nil }
                    return ChallengeAchievement(type: type, quantity: quantity)
                }
            }

            self.challenge = ChallengeInfo(
                title: title,
                reward: reward,
                achievements: achievements,
                startDate: start,
                endDate: end
            )
        }
    }


    private func loadStatus() {
        Firestore.firestore().collection("submissions").document(submission.id).addSnapshotListener { snapshot, _ in
            guard let data = snapshot?.data() else { return }

            let s = data["status"] as? String ?? "Pending"
            self.status = s
            self.isApproved = s.lowercased() == "approved"
            self.isRejected = s.lowercased() == "rejected"
            self.isRewarded = s.lowercased() == "rewarded"
            self.approveDisabled = isApproved || isRewarded
            self.rejectDisabled = isRejected || isRewarded
        }
    }

    private func fetchAthleteDeliveryInfo() {
        Firestore.firestore().collection("users").document(submission.athleteID).getDocument { doc, _ in
            if let data = doc?.data() {
                self.athleteEmail = data["emailForRewards"] as? String ?? "(missing)"
                self.shippingAddress = data["shippingAddress"] as? String ?? "(missing)"
            }
        }
    }

    private func validateDeliveryFields() -> Bool {
        switch deliveryMethod {
        case "Digital":
            return !redemptionCode.trimmingCharacters(in: .whitespaces).isEmpty
        case "Physical":
            return !trackingNumber.trimmingCharacters(in: .whitespaces).isEmpty
        default:
            return true
        }
    }

    private func updateStatus(to newStatus: String, includeDelivery: Bool = false) {
        var update: [String: Any] = ["status": newStatus.capitalized]

        if includeDelivery {
            update["deliveryMethod"] = deliveryMethod
            switch deliveryMethod {
            case "Digital":
                update["redemptionCode"] = redemptionCode
            case "Physical":
                update["trackingNumber"] = trackingNumber
                update["carrier"] = carrier
                update["estimatedDeliveryDate"] = Timestamp(date: estimatedDeliveryDate)
            case "Hand-delivered":
                update["notes"] = notes
            default:
                break
            }
        }

        Firestore.firestore().collection("submissions").document(submission.id).updateData(update)
    }
}

struct ChallengeInfo {
    let title: String
    let reward: String
    let achievements: [ChallengeAchievement]
    let startDate: Date
    let endDate: Date
}


struct Achievement: Hashable {
    let type: String
    let quantity: Int
}

struct PrimaryButton: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(configuration.isPressed ? 0.6 : 1))
            .foregroundColor(.white)
            .cornerRadius(8)
    }
}
