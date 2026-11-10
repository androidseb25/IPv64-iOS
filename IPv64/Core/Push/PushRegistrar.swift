import Foundation
import IPv64
import Observation

/// hc2 "app" channel of this device (Android `PushChannelRegistrar`).
/// SKELETON: only `ensureAccountId()` is implemented. The SecNtfy registration, APNs token handling,
/// `syncTokenIfChanged` and `registerThisDevice` are added by the push agent (spec 01 §9, 04 §7).
@Observable
final class PushRegistrar {
    private let session: Session

    init(session: Session) {
        self.session = session
    }

    /// Remembers the stable account id for the active API key (`account.me().id`) once per key.
    /// API and network errors are ignored (retried on a later trigger).
    func ensureAccountId() async {
        guard let keyHash = PushSetupStore.keyHash(apiKey: session.apiKey),
              PushSetupStore.accountId(keyHash: keyHash) == nil else { return }
        let client = session.api   // captured before the request so an account switch cannot mix them up
        guard let me = try? await ipv64Retrying({ try await client.account.me() }) else { return }
        PushSetupStore.rememberAccountId(keyHash: keyHash, accountId: me.id)
    }

    /// Updates the token on the stored device channel when it changed. Returns `true` if a request updated it.
    /// TODO(push agent): implement per spec 01 §9.1 `syncTokenIfChanged(channels?)`.
    @discardableResult
    func syncTokenIfChanged(channels: [HC2Channel]? = nil) async throws -> Bool {
        false
    }
}
