import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SignUpView: View {
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var companyName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var selectedAgeGroup: String = "Age Group"

    @State private var selectedRole: UserRole? = nil
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var isSignUpSuccessful = false
    @AppStorage("userID") var userID: String = ""
    @AppStorage("userRole") var userRole: String = ""
    @AppStorage("ageGroup") var ageGroup: String = ""
    
    @Environment(\.presentationMode) var presentationMode

    let ageGroups = (6...18).map { "\($0)u" }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hello! Register to get started")
                            .font(.title2)
                            .bold()
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                    if selectedRole == nil {
                        VStack(spacing: 16) {
                            Text("Select your role")
                                .font(.headline)

                            Button(action: { selectedRole = .sponsor }) {
                                roleButtonLabel("I am a Sponsor", color: .black)
                            }

                            Button(action: { selectedRole = .athlete }) {
                                roleButtonLabel("I am an Athlete", color: .gray, addBorder: false)
                            }

                            Button(action: { selectedRole = .retailer }) {
                                roleButtonLabel("I am a Retailer", color: .white, textColor: .black, addBorder: true)
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: 16) {
                            TextField("First Name", text: $firstName)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)

                            TextField("Last Name", text: $lastName)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)

                            if selectedRole == .retailer {
                                TextField("Company Name", text: $companyName)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                            }

                            if selectedRole == .athlete {
                                Picker("Select Age Group", selection: $selectedAgeGroup) {
                                    Text("Age Group").tag("Age Group")
                                    ForEach(ageGroups, id: \.self) { group in
                                        Text(group).tag(group)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }

                            TextField("Email", text: $email)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                                .keyboardType(.emailAddress)

                            SecureField("Password", text: $password)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)

                            SecureField("Confirm password", text: $confirmPassword)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)

                            Button(action: handleSignUp) {
                                Text("Register")
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.black)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }

                            HStack {
                                Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.3))
                                Text("Or Register with")
                                    .foregroundColor(.gray)
                                    .font(.footnote)
                                Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.3))
                            }

                            HStack(spacing: 16) {
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

                            Button("Back") {
                                selectedRole = nil
                            }
                            .foregroundColor(.gray)
                        }
                        .padding(.horizontal)
                    }

                    Spacer()

                    HStack {
                        Text("Already have an account?")
                            .foregroundColor(.gray)
                        NavigationLink("Login Now", destination: SignInView())
                            .foregroundColor(.black)
                            .fontWeight(.semibold)
                    }
                }
                .padding()
                .alert("Sign Up Error", isPresented: $showErrorAlert) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(errorMessage)
                }
                .navigationDestination(isPresented: $isSignUpSuccessful) {
                    switch userRole {
                    case "sponsor": SponsorDashboardView()
                    case "athlete": AthleteDashboardView()
                    case "retailer": RetailerDashboardView()
                    default: Text("Unknown role")
                    }
                }
                .navigationBarBackButtonHidden(selectedRole != nil)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        if selectedRole != nil {
                            Button(action: {
                                selectedRole = nil
                            }) {
                                HStack {
                                    Image(systemName: "chevron.left")
                                    Text("Back")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    func handleSignUp() {
        guard !firstName.isEmpty,
              !lastName.isEmpty,
              email.contains("@"),
              password == confirmPassword,
              let selectedRole = selectedRole else {
            errorMessage = "Please fill out all fields and select a role."
            showErrorAlert = true
            return
        }

        if selectedRole == .retailer && companyName.trimmingCharacters(in: .whitespaces).isEmpty {
            errorMessage = "Please enter a company name for retailer accounts."
            showErrorAlert = true
            return
        }

        if selectedRole == .athlete && selectedAgeGroup == "Age Group" {
            errorMessage = "Please select an age group."
            showErrorAlert = true
            return
        }

        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            } else if let result = result {
                let db = Firestore.firestore()
                let roleString = selectedRole.rawValue

                var userData: [String: Any] = [
                    "firstName": firstName,
                    "lastName": lastName,
                    "email": email,
                    "role": roleString
                ]

                if selectedRole == .retailer {
                    userData["companyName"] = companyName
                }

                if selectedRole == .athlete {
                    userData["ageGroup"] = selectedAgeGroup
                    ageGroup = selectedAgeGroup
                }

                db.collection("users").document(result.user.uid).setData(userData) { err in
                    if let err = err {
                        errorMessage = err.localizedDescription
                        showErrorAlert = true
                    } else {
                        userID = result.user.uid
                        userRole = roleString
                        isSignUpSuccessful = true
                    }
                }
            }
        }
    }

    func roleButtonLabel(_ text: String, color: Color, textColor: Color = .white, addBorder: Bool = false) -> some View {
        Text(text)
            .frame(maxWidth: .infinity)
            .padding()
            .background(color)
            .foregroundColor(textColor)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black, lineWidth: addBorder ? 1 : 0)
            )
            .cornerRadius(10)
    }
}


