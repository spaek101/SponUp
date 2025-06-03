import SwiftUI
import FirebaseAuth

struct ForgotPasswordView: View {
    @State private var email = ""
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Text("Reset Your Password")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Enter your email to receive a reset link.")
                    .foregroundColor(.gray)
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)

            TextField("Enter your email", text: $email)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding(.horizontal)

            Button(action: sendPasswordReset) {
                Text("Send Reset Link")
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.black)
                    .cornerRadius(12)
            }
            .padding(.horizontal)

            Spacer()

            HStack {
                Text("Remember your password?")
                    .foregroundColor(.gray)
                NavigationLink("Go Back to Login", destination: SignInView())
                    .foregroundColor(.blue)
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Password Reset"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func sendPasswordReset() {
        guard !email.isEmpty else {
            alertMessage = "Please enter your email."
            showAlert = true
            return
        }

        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                alertMessage = "Error: \(error.localizedDescription)"
            } else {
                alertMessage = "A password reset link has been sent to your email."
            }
            showAlert = true
        }
    }
}
