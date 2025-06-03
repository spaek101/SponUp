import SwiftUI
import FirebaseCore // ✅ Required to use FirebaseApp.configure()

@main
struct SponUpCleanApp: App {
    // ✅ Configure Firebase when the app starts
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            LandingPageView() // ✅ Replaced with landing page as the starting view
        }
    }
}
