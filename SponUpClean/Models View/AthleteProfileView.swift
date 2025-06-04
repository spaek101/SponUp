import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import PhotosUI
import CoreImage.CIFilterBuiltins
import AVFoundation

struct AthleteProfileView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var id = ""
    @State private var ageGroup = "Age Group"
    @State private var profileImageURL: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isEditing = false
    @State private var originalFirstName = ""
    @State private var originalLastName = ""
    @State private var originalAgeGroup = ""
    @State private var showToast = false
    @State private var toastMessage = ""

    @AppStorage("userID") var userID: String = ""
    @AppStorage("userRole") var userRole: String = ""

    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    @State private var qrImage: UIImage?
    @State private var showShareSheet = false
    @State private var showScanner = false
    @State private var scannedUserID: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        ZStack(alignment: .bottomTrailing) {
                            AsyncImage(url: URL(string: profileImageURL)) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView().frame(width: 100, height: 100)
                                case .success(let image):
                                    image.resizable().scaledToFill().frame(width: 100, height: 100).clipShape(Circle())
                                case .failure:
                                    Image(systemName: "person.circle.fill").resizable().scaledToFit().frame(width: 100, height: 100).foregroundColor(.gray)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            Circle()
                                .fill(Color.white)
                                .frame(width: 28, height: 28)
                                .overlay(Image(systemName: "camera.fill").font(.system(size: 14)).foregroundColor(.black))
                                .offset(x: 4, y: 4)
                        }
                    }
                    Text("\(firstName) \(lastName)").font(.title2).fontWeight(.bold)
                    Text("Athlete").foregroundColor(.gray).font(.subheadline)
                }.padding(.top)

                VStack(spacing: 0) {
                    Text("ACCOUNT INFORMATION")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding([.horizontal, .bottom], 12)

                    InfoRow(title: "Email", value: email)
                    Divider()
                    InfoRow(title: "User ID", value: id, copyable: true, onCopy: {
                        UIPasteboard.general.string = id
                        toastMessage = "Copied!"
                        withAnimation { showToast = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation { showToast = false }
                        }
                    })
                }
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                .padding(.horizontal)

                if let qr = generateQRCode(from: id), !id.isEmpty {
                    VStack(spacing: 12) {
                        Text("Share Your Profile").font(.headline)
                        Image(uiImage: qr)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 200, height: 200)

                        HStack(spacing: 12) {
                            Button(action: {
                                qrImage = qr
                                showShareSheet = true
                            }) {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.black)
                                    .cornerRadius(10)
                            }

                            Button(action: {
                                showScanner = true
                            }) {
                                Label("Scan", systemImage: "qrcode.viewfinder")
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.black, lineWidth: 1)
                                    )
                            }
                        }
                    }.padding()
                }

                if isEditing {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Edit Information").font(.headline)
                        HStack(spacing: 12) {
                            TextField("First Name", text: $firstName)
                                .padding().background(Color(.systemGray5)).cornerRadius(10)
                            TextField("Last Name", text: $lastName)
                                .padding().background(Color(.systemGray5)).cornerRadius(10)
                        }
                        Button(action: saveProfileChanges) {
                            Text("Save Changes")
                                .foregroundColor(.white)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isFormChanged() ? Color.black : Color.gray.opacity(0.4))
                                .cornerRadius(12)
                        }
                        .disabled(!isFormChanged())
                    }.padding(.horizontal)
                }

                Button(action: { isEditing.toggle() }) {
                    Label(isEditing ? "Cancel Editing" : "Edit Profile", systemImage: "pencil")
                        .foregroundColor(.blue)
                }

                Spacer()
            }.padding(.vertical)
        }
        .onChange(of: selectedPhoto) { _ in handlePhotoSelection() }
        .onAppear { loadUserData() }
        .sheet(isPresented: $showShareSheet) {
            if let qrImage = qrImage {
                ShareSheet(activityItems: [qrImage])
            }
        }
        .sheet(isPresented: $showScanner) {
            QRCodeScannerView { scannedID in
                showScanner = false
                scannedUserID = scannedID
                handleScannedID(scannedID)
            }
        }
        .overlay(
            Group {
                if showToast {
                    Text(toastMessage)
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.85))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.3), value: showToast)
                        .padding(.bottom, 40)
                }
            },
            alignment: .bottom
        )
    }

    private func generateQRCode(from string: String) -> UIImage? {
        filter.message = Data(string.utf8)
        if let outputImage = filter.outputImage {
            let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 20, y: 20))
            if let cgimg = context.createCGImage(scaled, from: scaled.extent) {
                return UIImage(cgImage: cgimg)
            }
        }
        return nil
    }

    private func handleScannedID(_ scannedID: String) {
        toastMessage = "Scanned ID: \(scannedID)"
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { showToast = false }
        }
    }

    private func handlePhotoSelection() {
        guard let selectedPhoto else { return }
        selectedPhoto.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    if let data = data, let image = UIImage(data: data) {
                        uploadProfileImage(image)
                    }
                case .failure(let error):
                    print("❌ Image loading failed: \(error)")
                }
            }
        }
    }

    private func uploadProfileImage(_ image: UIImage) {
        guard let uid = Auth.auth().currentUser?.uid,
              let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        let ref = Storage.storage().reference().child("profileImages/\(uid)/profile.jpg")
        ref.putData(imageData) { _, error in
            if let error = error {
                print("❌ Upload failed: \(error.localizedDescription)")
                return
            }
            ref.downloadURL { url, _ in
                if let url = url {
                    profileImageURL = url.absoluteString
                    Firestore.firestore().collection("users").document(uid).updateData([
                        "profileImageURL": profileImageURL
                    ]) { _ in
                        toastMessage = "✅ Profile photo updated!"
                        withAnimation {
                            showToast = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation {
                                showToast = false
                            }
                        }
                    }
                }
            }
        }
    }

    private func loadUserData() {
        guard let user = Auth.auth().currentUser else { return }
        email = user.email ?? "No email found"
        id = user.uid
        Firestore.firestore().collection("users").document(user.uid).getDocument { doc, _ in
            if let data = doc?.data() {
                profileImageURL = data["profileImageURL"] as? String ?? ""
                originalFirstName = data["firstName"] as? String ?? ""
                originalLastName = data["lastName"] as? String ?? ""
            }
        }
    }

    private func saveProfileChanges() {
        guard let user = Auth.auth().currentUser else { return }
        Firestore.firestore().collection("users").document(user.uid).updateData([
            "firstName": firstName,
            "lastName": lastName
        ]) { error in
            if error == nil {
                originalFirstName = firstName
                originalLastName = lastName
                isEditing = false
            }
        }
    }

    private func isFormChanged() -> Bool {
        firstName != originalFirstName || lastName != originalLastName
    }
}


struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.gray)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding([.top, .horizontal])
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    var copyable: Bool = false
    var onCopy: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title).font(.body)
            Spacer()
            Text(value)
                .foregroundColor(.gray)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.middle)
            if copyable {
                Button {
                    UIPasteboard.general.string = value
                    onCopy?()
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .foregroundColor(.blue)
                }
                .padding(.leading, 4)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}
