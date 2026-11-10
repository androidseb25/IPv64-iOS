import SwiftUI

/// First screen without an account (spec 01 §3.1).
struct WelcomeView: View {
    var body: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Welcome to")
                    .font(.largeTitle.bold())
                Text("IPv64.net")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.tint)
                Text("The App for the Free DynDNS2 Service from Dennis Schröder")
                    .padding(.top, 16)
            }
            .padding(.top, 32)
            Spacer()
            NavigationLink {
                LoginView(isFromUser: false)
            } label: {
                Text("Let's go!")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 37)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: 700)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack { WelcomeView() }
}
