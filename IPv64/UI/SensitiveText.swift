import SwiftUI

/// Masked value with an eye toggle; the revealed value is screenshot-protected via `SecureContainer`.
struct SensitiveText: View {
    private let value: String
    private let monospaced: Bool
    private let external: Binding<Bool>?
    @State private var local = false

    init(_ value: String, monospaced: Bool = true, revealed: Binding<Bool>? = nil) {
        self.value = value
        self.monospaced = monospaced
        self.external = revealed
    }

    private var isRevealed: Binding<Bool> { external ?? $local }

    var body: some View {
        HStack(spacing: 8) {
            if isRevealed.wrappedValue {
                SecureContainer {
                    Text(verbatim: value)
                        .font(monospaced ? .body.monospaced() : .body)
                        .foregroundStyle(Color(.label))
                }
            } else {
                Text(verbatim: "••••••••").font(.body)
            }
            Spacer(minLength: 0)
            Button {
                isRevealed.wrappedValue.toggle()
            } label: {
                Label(isRevealed.wrappedValue ? "Hide" : "Show",
                      systemImage: isRevealed.wrappedValue ? "eye.slash" : "eye")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SensitiveText("s3cr3t-token")
        .padding()
}
