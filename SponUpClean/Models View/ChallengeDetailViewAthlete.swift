import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import PhotosUI

struct ChallengeDetailViewAthlete: View {
    let challenge: Challenge
    @AppStorage("userRole") var userRole: String = ""

    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var showSuccessMessage = false
    @State private var showResultAlreadySubmittedMessage = false
    @State private var hasSubmitted = false
    @State private var submissionStatus: String? = nil
    @State private var sponsorName: String = ""
    @State private var currentImageIndex: Int = 0

    // Delivery Info (input)
    @State private var showDeliveryForm = false
    @State private var email: String = ""
    @State private var shippingAddress: String = ""
    @State private var deliveryValidationFailed = false

    // Delivery Info (from reward)
    @State private var deliveryMethod: String = ""
    @State private var redemptionCode: String = ""
    @State private var trackingNumber: String = ""
    @State private var carrier: String = ""
    @State private var estimatedDeliveryDate: Date = Date()
    @State private var notes: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(challenge.title).font(.title).bold()

                if !sponsorName.isEmpty {
                    Text("Sponsored by: \(sponsorName)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                if let reward = challenge.reward, !reward.isEmpty {
                    Text("🏆 Reward: \(reward)")
                        .font(.body)
                        .foregroundColor(.black)
                }

                Text("Challenge: \(challenge.achievements.map { $0.type }.joined(separator: ", "))")
                Text("Start: \(challenge.startDate.formatted(date: .abbreviated, time: .omitted))")
                Text("End: \(challenge.endDate.formatted(date: .abbreviated, time: .omitted))")

                if submissionStatus?.lowercased() != "rewarded" {
                    Text("Submission Deadline: \(timeRemaining(to: challenge.endDate))").foregroundColor(.red)
                }

                if let status = submissionStatus {
                    Text("Status: \(status.capitalized)").foregroundColor(color(for: status)).bold()
                }

                if !hasChallengeStarted {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.gray)
                        Text("You cannot submit until the challenge starts.")
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                }


                Divider()

                if showResultAlreadySubmittedMessage {
                    if submissionStatus?.lowercased() == "rejected" {
                        Label("Resubmit results.", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                            .foregroundColor(.orange)
                    } else {
                        Label("Results already submitted.", systemImage: "checkmark.seal.fill")
                            .foregroundColor(.green)
                    }
                }

                if !selectedImages.isEmpty {
                    VStack {
                        TabView(selection: $currentImageIndex) {
                            ForEach(selectedImages.indices, id: \.self) { index in
                                Image(uiImage: selectedImages[index])
                                    .resizable()
                                    .scaledToFit()
                                    .cornerRadius(10)
                                    .padding(.horizontal)
                                    .tag(index)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .frame(height: 250)

                        HStack(spacing: 6) {
                            ForEach(selectedImages.indices, id: \.self) { index in
                                Circle()
                                    .fill(index == currentImageIndex ? Color.primary : Color.secondary.opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.top, 4)
                    }
                }

                if showSuccessMessage {
                    Text("✅ Successfully submitted.").foregroundColor(.green)
                }

                if !showDeliveryForm {
                    PhotosPicker(
                        selection: $selectedPhotoItems,
                        maxSelectionCount: 5,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Text("Upload Results")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isChallengeExpired || !hasChallengeStarted ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(isChallengeExpired || !hasChallengeStarted)
                    .onChange(of: selectedPhotoItems) { _, newItems in
                        Task {
                            selectedImages.removeAll()
                            for item in newItems {
                                if let data = try? await item.loadTransferable(type: Data.self),
                                   let uiImage = UIImage(data: data) {
                                    selectedImages.append(uiImage)
                                }
                            }
                            showResultAlreadySubmittedMessage = false
                            currentImageIndex = 0
                        }
                    }

                    Button("Next") {
                        showDeliveryForm = true
                    }
                    .disabled(selectedImages.isEmpty || !canSubmit || !hasChallengeStarted)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background((selectedImages.isEmpty || !canSubmit || !hasChallengeStarted) ? Color.gray : Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }

                if showDeliveryForm {
                    Divider()
                    Text("Delivery Info").font(.headline)

                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .padding().background(Color.gray.opacity(0.1)).cornerRadius(8)

                    TextField("Shipping Address", text: $shippingAddress)
                        .padding().background(Color.gray.opacity(0.1)).cornerRadius(8)

                    Button("Submit") {
                        saveDeliveryInfoAndSubmit()
                    }
                    .disabled(email.trimmingCharacters(in: .whitespaces).isEmpty || shippingAddress.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background((email.trimmingCharacters(in: .whitespaces).isEmpty || shippingAddress.trimmingCharacters(in: .whitespaces).isEmpty) ? Color.gray : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)

                    if deliveryValidationFailed {
                        Text("⚠️ Email and shipping address are required.").foregroundColor(.red)
                    }
                }

                if submissionStatus?.lowercased() == "rewarded" {
                    Divider()
                    Text("🎁 Your reward has been shipped!").font(.headline)
                    Text("Delivery Method: \(deliveryMethod)")
                    if deliveryMethod == "Digital" {
                        Text("Redemption Code: \(redemptionCode)")
                    } else if deliveryMethod == "Physical" {
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
        .navigationTitle("Challenge Details")
        .onAppear {
            fetchSubmission()
            fetchSponsorName()
            fetchDeliveryInfo()
            if let authEmail = Auth.auth().currentUser?.email {
                self.email = authEmail
            }
        }
    }

    // MARK: - Computed properties

    private var hasChallengeStarted: Bool {
        return Date() >= challenge.startDate
    }

    private var canSubmit: Bool {
        let expired = isChallengeExpired
        guard let status = submissionStatus?.lowercased() else { return true }
        return (status == "pending" || status == "rejected") && !expired
    }

    private var isChallengeExpired: Bool {
        let now = Date()
        let adjustedEndDate = Calendar.current.date(byAdding: .day, value: 5, to: challenge.endDate)!
        return adjustedEndDate <= now
    }

    private func timeRemaining(to endDate: Date) -> String {
        let now = Date()
        let adjusted = Calendar.current.date(byAdding: .day, value: 5, to: endDate)!
        if adjusted <= now {
            return "Expired"
        }
        let diff = Calendar.current.dateComponents([.day, .hour, .minute], from: now, to: adjusted)
        return "\(diff.day ?? 0)d \(diff.hour ?? 0)h \(diff.minute ?? 0)m"
    }

    private func color(for status: String) -> Color {
        switch status.lowercased() {
        case "approved": return .green
        case "rejected": return .red
        case "rewarded": return .green
        default: return .orange
        }
    }

    // MARK: - Firestore Methods

    private func fetchSubmission() {
        guard let athleteID = Auth.auth().currentUser?.uid,
              let challengeID = challenge.id else { return }

        Firestore.firestore().collection("submissions")
            .whereField("athleteID", isEqualTo: athleteID)
            .whereField("challengeID", isEqualTo: challengeID)
            .limit(to: 1)
            .getDocuments { snapshot, _ in
                if let doc = snapshot?.documents.first {
                    let data = doc.data()
                    self.submissionStatus = data["status"] as? String ?? "Pending"
                    self.showResultAlreadySubmittedMessage = true
                    self.hasSubmitted = true

                    self.deliveryMethod = data["deliveryMethod"] as? String ?? ""
                    self.redemptionCode = data["redemptionCode"] as? String ?? ""
                    self.trackingNumber = data["trackingNumber"] as? String ?? ""
                    self.carrier = data["carrier"] as? String ?? ""
                    if let ts = data["estimatedDeliveryDate"] as? Timestamp {
                        self.estimatedDeliveryDate = ts.dateValue()
                    }
                    self.notes = data["notes"] as? String ?? ""

                    if let urls = data["imageURLs"] as? [String] {
                        Task {
                            var uiImages: [UIImage] = []
                            for urlString in urls {
                                if let url = URL(string: urlString) {
                                    do {
                                        let (data, _) = try await URLSession.shared.data(from: url)
                                        if let image = UIImage(data: data) {
                                            uiImages.append(image)
                                        }
                                    } catch {
                                        print("❌ Failed to load image from URL: \(urlString)")
                                    }
                                }
                            }
                            self.selectedImages = uiImages
                            self.currentImageIndex = 0
                        }
                    }
                }
            }
    }

    private func fetchSponsorName() {
        guard !challenge.createdBy.isEmpty else { return }
        Firestore.firestore().collection("users").document(challenge.createdBy).getDocument { doc, _ in
            if let data = doc?.data() {
                if challenge.type == "retailer" {
                    self.sponsorName = data["companyName"] as? String ?? ""
                } else {
                    self.sponsorName = "\(data["firstName"] as? String ?? "") \(data["lastName"] as? String ?? "")"
                }
            }
        }
    }

    private func fetchDeliveryInfo() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("users").document(userID).getDocument { doc, _ in
            if let data = doc?.data() {
                self.shippingAddress = data["shippingAddress"] as? String ?? ""
            }
        }
    }

    private func saveDeliveryInfoAndSubmit() {
        guard !email.isEmpty, !shippingAddress.isEmpty,
              let athleteID = Auth.auth().currentUser?.uid,
              let challengeID = challenge.id else {
            deliveryValidationFailed = true
            return
        }

        deliveryValidationFailed = false

        let userRef = Firestore.firestore().collection("users").document(athleteID)
        userRef.setData([
            "emailForRewards": email,
            "shippingAddress": shippingAddress
        ], merge: true)

        uploadImagesAndSubmit(athleteID: athleteID, challengeID: challengeID)
    }

    private func uploadImagesAndSubmit(athleteID: String, challengeID: String) {
        let db = Firestore.firestore()
        let storage = Storage.storage()
        var uploadedURLs: [String] = []
        let group = DispatchGroup()

        for image in selectedImages {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else { continue }
            group.enter()
            let ref = storage.reference().child("submissions/\(UUID().uuidString).jpg")
            ref.putData(imageData, metadata: nil) { _, error in
                if error == nil {
                    ref.downloadURL { url, _ in
                        if let url = url {
                            uploadedURLs.append(url.absoluteString)
                        }
                        group.leave()
                    }
                } else {
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            let data: [String: Any] = [
                "athleteID": athleteID,
                "challengeID": challengeID,
                "imageURLs": uploadedURLs,
                "status": "Pending",
                "submittedAt": Timestamp()
            ]

            let ref = db.collection("submissions")
            ref.whereField("athleteID", isEqualTo: athleteID)
                .whereField("challengeID", isEqualTo: challengeID)
                .limit(to: 1)
                .getDocuments { snap, _ in
                    if let doc = snap?.documents.first {
                        ref.document(doc.documentID).updateData(data) { _ in completeSubmission() }
                    } else {
                        ref.addDocument(data: data) { _ in completeSubmission() }
                    }
                }
        }
    }

    private func completeSubmission() {
        hasSubmitted = true
        showResultAlreadySubmittedMessage = false
        selectedImages = []
        selectedPhotoItems = []
        submissionStatus = "Pending"
        currentImageIndex = 0
        showSuccessMessage = true
        showDeliveryForm = false
    }
}
