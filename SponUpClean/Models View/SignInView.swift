import SwiftUI
import FirebaseAuth
import FirebaseFirestore

enum DashboardType: Hashable {
    case athlete
    case sponsor
    case retailer
}

struct SignInView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @AppStorage("userRole") var userRole: String = ""
    @AppStorage("userID") var userID: String = ""
    @State private var isSignedOut = false
    @State private var selectedDashboard: DashboardType? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Welcome back!")
                        .font(.title)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Glad to see you, Again!")
                        .font(.title2)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)

                VStack(spacing: 12) {
                    TextField("Enter your email", text: $email)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    SecureField("Enter your password", text: $password)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                .padding(.horizontal)

                HStack {
                    Spacer()
                    NavigationLink("Forgot Password?", destination: ForgotPasswordView())
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.trailing)
                }

                Button(action: {
                    print("🔐 Attempting to sign in user")
                    signInUser()
                }) {
                    Text("Login")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.black)
                        .cornerRadius(12)
                }
                .disabled(email.isEmpty || password.isEmpty)
                .opacity(email.isEmpty || password.isEmpty ? 0.5 : 1)
                .padding(.horizontal)

                HStack {
                    Rectangle().frame(height: 1).foregroundColor(Color.gray.opacity(0.3))
                    Text("Or Login with")
                        .foregroundColor(.gray)
                        .font(.footnote)
                    Rectangle().frame(height: 1).foregroundColor(Color.gray.opacity(0.3))
                }
                .padding(.horizontal)

                HStack(spacing: 20) {
                    Image(systemName: "f.circle.fill")
                        .resizable()
                        .frame(width: 36, height: 36)
                        .foregroundColor(.blue)

                    Image(systemName: "g.circle.fill")
                        .resizable()
                        .frame(width: 36, height: 36)
                        .foregroundColor(.red)

                    Image(systemName: "apple.logo")
                        .resizable()
                        .frame(width: 30, height: 36)
                        .foregroundColor(.black)
                }

                Spacer()

                HStack {
                    Text("Don't have an account?")
                        .foregroundColor(.gray)
                    NavigationLink("Register Now", destination: SignUpView())
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                }
            }
            .padding()
            .alert("Sign In Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                selectedDashboard = nil
                email = ""
                password = ""
            }
            .onChange(of: isSignedOut) {
                if isSignedOut {
                    userID = ""
                    userRole = ""
                    email = ""
                    password = ""
                    selectedDashboard = nil
                    print("🔁 Signed out and reset")
                }
            }
            .navigationDestination(for: DashboardType.self) { type in
                dashboardDestinationView(for: type)
            }
            .navigationBarBackButtonHidden(true)        // 👈 Hides the system back button
                .interactiveDismissDisabled(true)           // 👈 Prevents swipe-to-dismiss on modal
        }
        NavigationLink(
            destination: dashboardDestinationView(for: selectedDashboard ?? .athlete),
            tag: selectedDashboard ?? .athlete,
            selection: $selectedDashboard
        ) {
            EmptyView()
        }
        .hidden()

    }

    @ViewBuilder
    private func dashboardDestinationView(for type: DashboardType) -> some View {
        switch type {
        case .athlete:
            AthleteDashboardView()
        case .sponsor:
            SponsorDashboardView()
        case .retailer:
            RetailerDashboardView()
        }
    }

    private func signInUser() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password."
            showErrorAlert = true
            return
        }

        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                errorMessage = error.localizedDescription
                showErrorAlert = true
                return
            }

            guard let result = result else {
                errorMessage = "Login failed."
                showErrorAlert = true
                return
            }

            let uid = result.user.uid
            print("✅ Auth success – UID: \(uid)")

            let db = Firestore.firestore()
            db.collection("users").document(uid).getDocument { docSnapshot, err in
                if let err = err {
                    errorMessage = err.localizedDescription
                    showErrorAlert = true
                } else if let doc = docSnapshot, doc.exists {
                    let data = doc.data()
                    let roleFromDB = data?["role"] as? String ?? ""

                    print("✅ Firestore user role: \(roleFromDB)")

                    userID = uid
                    userRole = roleFromDB

                    DispatchQueue.main.async {
                        switch userRole {
                        case "athlete":
                            selectedDashboard = .athlete
                        case "sponsor":
                            selectedDashboard = .sponsor
                        case "retailer":
                            selectedDashboard = .retailer
                        default:
                            errorMessage = "Unknown user role."
                            showErrorAlert = true
                        }
                    }
                } else {
                    errorMessage = "User profile not found."
                    showErrorAlert = true
                }
            }
        }
    }

    private func signOut() {
        do {
            try Auth.auth().signOut()
            userID = ""
            userRole = ""
            isSignedOut = true
            print("✅ Signed out successfully")
        } catch {
            print("❌ Error signing out: \(error.localizedDescription)")
        }
    }
}
