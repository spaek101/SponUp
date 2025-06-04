import SwiftUI

struct ChallengeOptionsView: View {
    @Binding var sponsoredAthletes: [Athlete]
    @Binding var challenges: [Challenge]

    var body: some View {
        VStack(alignment: .center, spacing: 24) {
            // Intro Section
            VStack(alignment: .leading, spacing: 16) {
                Text("How would you like to create a challenge?")
                    .font(.headline)
            }
        
                    

            // Challenge Cards
            NavigationLink(destination: CreateChallengeView(sponsoredAthletes: $sponsoredAthletes, challenges: $challenges)) {
                CustomDashboardCardView(title: "Create My Own Challenge", systemImage: "plus.circle.fill")
            }
            .buttonStyle(PlainButtonStyle())
            .frame(maxWidth: .infinity)

            NavigationLink(destination: ViewScheduleView(sponsoredAthletes: $sponsoredAthletes, challenges: $challenges)) {
                CustomDashboardCardView(title: "View Athlete's Schedule", systemImage: "calendar.circle.fill")
            }
            .buttonStyle(PlainButtonStyle())
            .frame(maxWidth: .infinity)

            Spacer()
        }
        .padding()
        .background(Color.clear)
        .navigationBarTitle("Challenge Options", displayMode: .inline)
    }
}

struct CustomDashboardCardView: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(Color.blue)
                .clipShape(Circle())

            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.black)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)

            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 5)
        .frame(maxWidth: .infinity)
    }
}
