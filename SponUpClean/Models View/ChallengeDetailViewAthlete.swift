import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import PhotosUI
import Vision
import CoreML

struct ChallengeDetailViewAthlete: View {
    let challenge: Challenge
    @AppStorage("userRole") var userRole: String = ""

    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var ocrResults: [String] = []
    @State private var showSuccessMessage = false
    @State private var showResultAlreadySubmittedMessage = false
    @State private var hasSubmitted = false
    @State private var submissionStatus: String? = nil
    @State private var sponsorName: String = ""
    @State private var currentImageIndex: Int = 0

    @State private var showDeliveryForm = false
    @State private var email: String = ""
    @State private var shippingAddress: String = ""
    @State private var deliveryValidationFailed = false

    @State private var deliveryMethod: String = ""
    @State private var redemptionCode: String = ""
    @State private var trackingNumber: String = ""
    @State private var carrier: String = ""
    @State private var estimatedDeliveryDate: Date = Date()
    @State private var notes: String = ""

    // ML Prediction State
    @State private var predictedEventType: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(challenge.title)
                        .font(.title.bold())

                    if !sponsorName.isEmpty {
                        Text("Sponsored by: \(sponsorName)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }

                    if let reward = challenge.reward, !reward.isEmpty {
                        Text("Reward: \(reward)")
                            .font(.body)
                            .foregroundColor(.black)
                    }

                    Text("Challenge: \(challenge.achievements.map { $0.type }.joined(separator: ", "))")
                    Text("Start: \(challenge.startDate.formatted(date: .abbreviated, time: .omitted))")
                    Text("End: \(challenge.endDate.formatted(date: .abbreviated, time: .omitted))")

                    if submissionStatus?.lowercased() != "rewarded" {
                        Text("Submission Deadline: \(timeRemaining(to: challenge.endDate))")
                            .foregroundColor(.red)
                    }

                    if let status = submissionStatus {
                        Text("Status: \(status.capitalized)")
                            .foregroundColor(color(for: status))
                            .bold()
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
                        }
                    }

                    if !ocrResults.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("📄 Parsed Stats")
                                .font(.headline)
                            ForEach(ocrResults, id: \.self) { line in
                                Text(line)
                                    .font(.callout)
                                    .foregroundColor(.primary)
                                    .padding(.vertical, 2)
                            }
                            // Prediction block
                            if let prediction = predictedEventType {
                                Text("📊 Predicted Event Type: \(prediction)")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                    .padding(.vertical, 4)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
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
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background((isChallengeExpired || !hasChallengeStarted) ? Color.gray.opacity(0.3) : Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                        }
                        .disabled(isChallengeExpired || !hasChallengeStarted)
                        .onChange(of: selectedPhotoItems) { _, newItems in
                            Task {
                                selectedImages.removeAll()
                                ocrResults.removeAll()
                                for item in newItems {
                                    if let data = try? await item.loadTransferable(type: Data.self),
                                       let uiImage = UIImage(data: data) {
                                        selectedImages.append(uiImage)
                                        performOCR(on: uiImage)
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
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background((selectedImages.isEmpty || !canSubmit || !hasChallengeStarted) ? Color.gray.opacity(0.3) : Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(16)
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
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Challenge Details")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)

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
    // MARK: - OCR Helper
    private func performOCR(on image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { (request, error) in
            if let results = request.results as? [VNRecognizedTextObservation] {
                let recognizedStrings = results.compactMap { $0.topCandidates(1).first?.string }
                DispatchQueue.main.async {
                    self.ocrResults.append(contentsOf: recognizedStrings)
                    // Predict event type after OCR
                    self.predictEventType(from: self.ocrResults)
                }
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try requestHandler.perform([request])
            } catch {
                print("❌ OCR failed: \(error)")
            }
        }
    }

    // MARK: - ML Prediction
    private func predictEventType(from lines: [String]) {
        guard let model = try? EventTypeClassifier(configuration: MLModelConfiguration()) else {
            print("❌ Failed to load Core ML model.")
            return
        }

        // Try to extract numeric values from OCR
        var ab: Int64 = 0, h: Int64 = 0, hr: Int64 = 0, rbi: Int64 = 0
        var avg: Double = 0.0

        for line in lines {
            let lower = line.lowercased()
            if let match = line.range(of: #"(\d+)\s*AB"#, options: .regularExpression) {
                ab = Int64(line[match].replacingOccurrences(of: "AB", with: "").trimmingCharacters(in: .whitespaces)) ?? 0
            }
            if let match = line.range(of: #"(\d+)\s*H"#, options: .regularExpression) {
                h = Int64(line[match].replacingOccurrences(of: "H", with: "").trimmingCharacters(in: .whitespaces)) ?? 0
            }
            if let match = line.range(of: #"(\d+)\s*HR"#, options: .regularExpression) {
                hr = Int64(line[match].replacingOccurrences(of: "HR", with: "").trimmingCharacters(in: .whitespaces)) ?? 0
            }
            if let match = line.range(of: #"(\d+)\s*RBI"#, options: .regularExpression) {
                rbi = Int64(line[match].replacingOccurrences(of: "RBI", with: "").trimmingCharacters(in: .whitespaces)) ?? 0
            }
            if let match = line.range(of: #"AVG[:=]?\s*([\d.]+)"#, options: .regularExpression) {
                let number = line[match].components(separatedBy: CharacterSet(charactersIn: ":= ")).last ?? ""
                avg = Double(number) ?? 0.0
            }
        }

        // Avoid division by zero
        if ab > 0 && h > 0 {
            avg = Double(h) / Double(ab)
        }

        do {
            let input = EventTypeClassifierInput(athlete_name: "", event_context: "", raw_text: "", AB: ab, H: h, HR: hr, RBI: rbi, AVG: avg)
            let result = try model.prediction(input: input)
            DispatchQueue.main.async {
                self.predictedEventType = result.event_type
            }
        } catch {
            print("❌ Prediction failed: \(error)")
        }
    }
}
