import SwiftUI

private struct APIErrorModifier: ViewModifier {
    @ObservedObject var api: ApiService
    func body(content: Content) -> some View {
        content.alert("Request failed", isPresented: Binding(
            get: { api.errorMessage != nil },
            set: { if !$0 { api.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { api.errorMessage = nil }
        } message: {
            Text(api.errorMessage ?? "")
        }
    }
}

extension View {
    func apiErrors(_ api: ApiService) -> some View { modifier(APIErrorModifier(api: api)) }
}
