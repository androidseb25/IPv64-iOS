import SwiftUI

/// Native form sheet used by the node sheets: Cancel (leading), confirm (trailing), not dismissable while busy.
struct NodeFormSheet<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    let title: LocalizedStringKey
    var confirmLabel: LocalizedStringKey
    var confirmSystemImage = "checkmark"
    var confirmEnabled = true
    var isBusy = false
    var destructive = false
    let onConfirm: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        NavigationStack {
            Form { content }
                .disabled(isBusy)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", systemImage: "xmark") { dismiss() }.disabled(isBusy)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        if isBusy {
                            ProgressView()
                        } else {
                            Button(confirmLabel, systemImage: confirmSystemImage, action: onConfirm)
                                .tint(destructive ? Color.ipv64Red : nil)
                                .disabled(!confirmEnabled)
                        }
                    }
                }
        }
        .interactiveDismissDisabled(isBusy)
    }
}
