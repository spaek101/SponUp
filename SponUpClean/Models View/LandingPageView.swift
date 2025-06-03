import SwiftUI

struct LandingPageView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()

                // Replace this with your actual image asset name
                Image("landingImage")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 250)

                Spacer()

                VStack(spacing: 16) {
                    NavigationLink(destination: SignInView()) {
                        Text("Login")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }

                    NavigationLink(destination: SignUpView()) {
                        Text("Register")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.black, lineWidth: 1)
                            )
                    }

                    Button(action: {
                        // Navigate or store guest session
                        print("Guest mode")
                    }) {
                        Text("Continue as a guest")
                            .foregroundColor(.blue)
                            .font(.subheadline)
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 40)
            }
            .background(Color.white.ignoresSafeArea())
        }
    }
}
