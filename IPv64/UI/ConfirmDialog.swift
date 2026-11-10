import SwiftUI

struct ConfirmRequest: Identifiable {
    let id = UUID()
    var title: String
    var message: String
    var confirmLabel: String = "Confirm"
    var destructive: Bool = false
    var requireTyping: String? = nil
    var action: () -> Void
}

extension View {
    func confirmDialog(_ request: Binding<ConfirmRequest?>) -> some View {
        modifier(ConfirmDialogModifier(request: request))
    }
}

private struct ConfirmDialogModifier: ViewModifier {
    @Binding var request: ConfirmRequest?
    @State private var typed = ""

    private var isPresented: Binding<Bool> {
        Binding(get: { request != nil }, set: { if !$0 { request = nil } })
    }

    func body(content: Content) -> some View {
        content.alert(
            Text(verbatim: request?.title ?? ""), isPresented: isPresented, presenting: request
        ) { req in
            if req.requireTyping != nil {
                TextField("", text: $typed).autocorrectionDisabled().textInputAutocapitalization(.never)
            }
            Button("Cancel", role: .cancel) { typed = "" }
            Button(role: req.destructive ? .destructive : nil) {
                typed = ""
                req.action()
            } label: { Text(verbatim: req.confirmLabel) }
            .disabled(req.requireTyping.map { typed.trimmingCharacters(in: .whitespacesAndNewlines) != $0 } ?? false)
        } message: { req in
            if let needed = req.requireTyping {
                Text(verbatim: req.message + "\n" + String(localized: "Type \"\(needed)\" to confirm."))
            } else {
                Text(verbatim: req.message)
            }
        }
    }
}

#Preview {
    @Previewable @State var req: ConfirmRequest? = ConfirmRequest(
        title: "Delete?", message: "This cannot be undone.", confirmLabel: "Delete", destructive: true,
        requireTyping: "example.net") {}
    Text("Host").confirmDialog($req)
}
