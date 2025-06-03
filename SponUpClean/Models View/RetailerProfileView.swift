import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct RetailerProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userID") var userID: String = ""

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var companyName = ""
    @State private var isEditing = false
    @State private var originalCompanyName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Retailer Profile")
                .font(.largeTitle)
                .bold()

            HStack {
                Text("Name:")
                    .font(.headline)
                Text("\(firstName) \(lastName)")
                    .foregroundColor(.gray)
            }

            HStack {
                Text("Email:")
                    .font(.headline)
                Text(email)
                    .foregroundColor(.gray)
            }

            HStack {
                Text("Company:")
                    .font(.headline)

                if isEditing {
                    TextField("Company Name", text: $companyName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                } else {
                    Text(companyName)
                        .foregroundColor(.gray)
                }

                Button(action: {
                    isEditing.toggle()
                }) {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundColor(.blue)
                }
            }

            if isEditing {
                Button("Save Changes") {
                    saveChanges()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            loadProfile()
        }
    }

    private func loadProfile() {
        Firestore.firestore().collection("users").document(userID).getDocument { doc, _ in
            if let data = doc?.data() {
                firstName = data["firstName"] as? String ?? ""
                lastName = data["lastName"] as? String ?? ""
                email = data["email"] as? String ?? ""
                companyName = data["companyName"] as? String ?? ""
                originalCompanyName = companyName
            }
        }
    }

    private func saveChanges() {
        Firestore.firestore().collection("users").document(userID).updateData([
            "companyName": companyName
        ]) { _ in
            originalCompanyName = companyName
            isEditing = false
        }
    }
}
