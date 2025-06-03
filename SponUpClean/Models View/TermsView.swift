import SwiftUI

struct TermsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Privacy Policy")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)

                Text("Effective Date: April 13, 2025")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding(.bottom)

                Text("""
                    At SponUp, we are committed to protecting your privacy and ensuring a safe user experience. This Privacy Policy outlines how we collect, use, store, and protect your personal data. By using our app, you agree to the terms of this policy.

                    1. **Information We Collect**
                    We collect personal information to provide and improve our services. The information we collect includes:
                    - **Personal Information**: When you sign up for SponUp, we collect your name, email address, and role (athlete or sponsor).
                    - **Account Information**: We collect information about your account such as your event details, start and end dates, and participation history.
                    - **Usage Data**: We collect information about how you use the app, including device information, login history, and interactions with the app.

                    2. **How We Use Your Information**
                    We use your information for the following purposes:
                    - **To Provide Services**: We use your information to create and manage your account, process your event information, and provide features within the app.
                    - **To Improve Our Services**: We analyze usage patterns to enhance the app experience and add new features.
                    - **To Communicate with You**: We may send you notifications about events, updates, and promotional content. You can opt-out at any time.

                    3. **How We Share Your Information**
                    We do not sell or rent your personal information. We may share your information in the following cases:
                    - **Service Providers**: We may share your information with trusted third-party service providers who help us operate and improve the app.
                    - **Legal Compliance**: We may disclose your information if required by law or to protect our rights, property, or safety.

                    4. **Data Security**
                    We implement reasonable technical and organizational measures to protect your data from unauthorized access, alteration, or destruction. However, no method of transmission over the internet is 100% secure, and we cannot guarantee its absolute security.

                    5. **Your Rights**
                    You have the right to access, update, or delete your personal information. If you wish to exercise these rights, please contact us via the support section in the app.

                    6. **Changes to This Policy**
                    We may update this Privacy Policy from time to time. Any changes will be posted on this page with an updated effective date. We encourage you to review this policy periodically.

                    7. **Contact Us**
                    If you have any questions or concerns about this Privacy Policy, please contact us at support@sponup.com.
                    """)

                Text("Terms of Service")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)

                Text("""
                    Effective Date: April 13, 2025

                    By using SponUp (the "App"), you agree to the following Terms of Service. If you do not agree with these terms, please do not use the app.

                    1. **Account Creation**
                    To access and use SponUp, you must create an account. You agree to provide accurate, up-to-date information when signing up. You are responsible for maintaining the confidentiality of your login credentials and for all activities that occur under your account.

                    2. **Use of the App**
                    You agree to use SponUp in a lawful and respectful manner. You may not:
                    - Use the app for any illegal activities.
                    - Harass, abuse, or harm others.
                    - Attempt to access the app's backend or manipulate any system to gain unauthorized access.
                    - Share or distribute content that violates the rights of others.

                    3. **Events and Content**
                    As an athlete or sponsor, you agree to use SponUp solely for event management and scheduling purposes. All content you upload, including event details and personal data, remains your property, but by using the app, you grant SponUp the right to use it for the app's functionality.

                    4. **Payment and Fees**
                    Some features of SponUp may require a subscription or payment. You agree to pay all applicable fees for the services you use. All payments are handled through secure payment processors, and we do not store any payment information.

                    5. **Termination**
                    SponUp reserves the right to suspend or terminate your account if you violate these Terms of Service or engage in unlawful activity. You may also close your account at any time by contacting customer support.

                    6. **Limitation of Liability**
                    SponUp is not liable for any direct, indirect, incidental, or consequential damages arising from the use of the app. We do not guarantee the app’s availability or performance.

                    7. **Privacy**
                    Your use of SponUp is governed by our Privacy Policy. By using the app, you consent to the collection, use, and sharing of your data as described in the Privacy Policy.

                    8. **Updates and Modifications**
                    SponUp reserves the right to update or modify these Terms of Service at any time. Changes will be communicated to you, and your continued use of the app constitutes acceptance of the revised terms.

                    9. **Governing Law**
                    These Terms of Service are governed by and construed in accordance with the laws of the jurisdiction in which SponUp operates.

                    10. **Contact Us**
                    If you have any questions or concerns regarding these Terms of Service, please contact us at support@sponup.com.
                    """)
            }
            .padding()
        }
        .navigationTitle("Privacy & Terms")
    }
}

struct TermsView_Previews: PreviewProvider {
    static var previews: some View {
        TermsView()
    }
}
