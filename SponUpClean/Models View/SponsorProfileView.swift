import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import PhotosUI

struct SponsorProfileView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var firstName: String
    @Binding var lastName: String
    @State private var email = ""
    @State private var id = ""
    @State private var isEditing = false
    @State private var originalFirstName = ""
    @State private var originalLastName = ""
    @State private var profileImageURL: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showToast = false

    @AppStorage("userID") var userID: String = ""
    @AppStorage("userRole") var userRole: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Profile Image & Name
                VStack(spacing: 8) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        ZStack(alignment: .bottomTrailing) {
                            AsyncImage(url: URL(string: profileImageURL)) { phase in
                                switch phase {
                                case .empty:
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 100, height: 100)
                                        .foregroundColor(.gray)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                case .failure:
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 100, height: 100)
                                        .foregroundColor(.gray)
                                @unknown default:
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 100, height: 100)
                                        .foregroundColor(.gray)
                                }
                            }

                            Circle()
                                .fill(Color.white)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.black)
                                )
                                .offset(x: 4, y: 4)
                        }
                    }

                    Text("\(firstName) \(lastName)")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Sponsor")
                        .foregroundColor(.gray)
                        .font(.subheadline)
                }
                .padding(.top)

                VStack(spacing: 0) {
                    SectionHeader(title: "ACCOUNT INFORMATION")

                    InfoRow(title: "Email", value: email)
                    Divider()
                    InfoRow(title: "User ID", value: id, copyable: true)
                }
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                .padding(.horizontal)

                if isEditing {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Edit Information")
                            .font(.headline)

                        HStack(spacing: 12) {
                            TextField("First Name", text: $firstName)
                                .padding()
                                .background(Color(.systemGray5))
                                .cornerRadius(10)

                            TextField("Last Name", text: $lastName)
                                .padding()
                                .background(Color(.systemGray5))
                                .cornerRadius(10)
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
                    }
                    .padding(.horizontal)
                }

                Button(action: {
                    isEditing.toggle()
                }) {
                    Label(isEditing ? "Cancel Editing" : "Edit Profile", systemImage: "pencil")
                        .foregroundColor(.blue)
                }
                .padding(.top, 8)

                Spacer()
            }
            .padding(.vertical)
        }
        .onChange(of: selectedPhoto) { _ in
            handlePhotoSelection()
        }
        .onAppear {
            loadUserData()
        }
        .overlay(
            Group {
                if showToast {
                    Text("✅ Profile photo updated!")
                        .font(.subheadline)
                        .padding()
                        .background(Color.black.opacity(0.85))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .transition(.opacity)
                        .padding(.bottom, 50)
                }
            },
            alignment: .bottom
        )
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
                        showToast = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            showToast = false
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
                firstName = data["firstName"] as? String ?? ""
                lastName = data["lastName"] as? String ?? ""
                profileImageURL = data["profileImageURL"] as? String ?? ""

                originalFirstName = firstName
                originalLastName = lastName
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

