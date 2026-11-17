import Foundation
import IPv64
import Observation
import SecNtfy
import SwiftyBeaver
import UIKit

/// Android `PushRegistrationException`: shown as a message dialog (title + text, never the token).
nonisolated struct PushRegistrationError: Error, Sendable {
    let title: String
    let message: String

    static var tokenUnavailable: Self {
        Self(title: String(localized: "Device token unavailable"),
             message: String(localized: "This device could not be registered for push notifications (Apple Push Notification service or the push service is not reachable). Please check your internet connection and try again later."))
    }

    static var notSupported: Self {
        Self(title: String(localized: "Not supported"),
             message: String(localized: "Push notifications to the IPv64 app are not supported by the server yet. You can skip this step."))
    }

    static var channelNotFound: Self {
        Self(title: String(localized: "Channel not found"),
             message: String(localized: "The selected channel no longer exists."))
    }

    static func unknownFormat(_ message: String) -> Self {
        Self(title: String(localized: "Unknown app channel format"), message: message)
    }
}

/// Settings of this device's channel (Android `DeviceChannelSettings`).
struct DeviceChannelSettings {
    var name: String
    var isDefault: Bool
    var notifyDown: Bool
    var notifyUp: Bool
    var lang: HC2ChannelLanguage
}

enum DeviceRegistration {
    case registered(HC2Channel, reused: Bool)
    /// No match, `createNew == false` and the account already has app channels.
    case existingCandidates([HC2Channel])
}

/// SecNtfy device token + hc2 "app" channel of this device (Android `SecNtfyHelper` + `PushChannelRegistrar`,
/// spec 01 §9, 04 §7). One instance, injected with `.environment(registrar)`.
@Observable
final class PushRegistrar {
    private let session: Session
    /// `apiUrl|appKey` the SDK was configured with (Android: init once per process unless they change).
    @ObservationIgnored private var configuredFor: String?
    /// Last device registration; a new one waits for it (Android serialises with a mutex).
    @ObservationIgnored private var registration: Task<String?, Never>?
    /// Account scope the push setup sheet was opened for in this app run, shared by all windows
    /// so only one window opens it (Android `MainActivity`: once per account and app start).
    @ObservationIgnored var setupTriggeredFor: String?
    /// Bumped when a window closes the setup sheet; other windows close theirs once `PushSetupStore.shouldShow` is false.
    var setupClosed = 0

    init(session: Session) {
        self.session = session
    }

    // MARK: - SecNtfy

    private var appKey: String {
        AppConfig.secNtfyAppKey
    }

    /// The App Group keeps the key pair and device token so the Notification Service Extension can decrypt.
    private func configureSecNtfy(force: Bool) {
        let url = AppConfig.secNtfyURL
        let key = appKey
        guard force || configuredFor != url + "|" + key else { return }
        SecNtfySwifty.shared.initialize(apiUrl: url, bundleGroup: AppConfig.appGroup)
        if !key.isEmpty { SecNtfySwifty.shared.configure(apiKey: key) }
        configuredFor = url + "|" + key
    }

    /// GAP (SecNtfy SDK): no public accessor for the stored device token, so the App Group key is read directly.
    private var storedToken: String? {
        UserDefaults(suiteName: AppConfig.appGroup)?.string(forKey: "NTFY_DEVICE_TOKEN")?.nonBlank
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    /// APNs token from the app delegate (every launch): register at SecNtfy, then update the device channel.
    func apnsTokenReceived(_ hex: String) async {
        SecNtfySwifty.shared.setApnsToken(apnsToken: hex)
        guard await registerDevice() != nil else { return }
        _ = try? await syncTokenIfChanged(channels: nil)
    }

    /// Android `registerDevice()`: SecNtfy device token or `nil` (not configured / not reachable).
    @discardableResult
    func registerDevice() async -> String? {
        let previous = registration
        let task = Task { [weak self] () -> String? in
            _ = await previous?.value
            return await self?.performRegistration()
        }
        registration = task
        let token = await task.value
        if registration == task { registration = nil }
        return token
    }

    private func performRegistration() async -> String? {
        guard !appKey.isEmpty else { return nil }
        configureSecNtfy(force: false)
        for attempt in 0..<2 {
            let result = await SecNtfySwifty.shared.getNtfyToken()
            if let token = result.token?.nonBlank { return token.trimmingCharacters(in: .whitespacesAndNewlines) }
            iLogger.log.warning("SecNtfy registration failed: \(result.error?.localizedDescription ?? "no token")")
            // GAP (SecNtfy SDK): NtfyError is internal, ConfigurationChanged / NoDevice cannot be told apart → reconfigure, retry once.
            if attempt == 0 { configureSecNtfy(force: true) }
        }
        return nil
    }

    /// Android `ntfyToken()`: stored token, else a fresh registration.
    private func ntfyToken() async -> String? {
        if let storedToken { return storedToken }
        return await registerDevice()
    }

    // MARK: - Account / channel

    /// Remembers the stable account id for the active API key (`account.me().id`) once per key.
    /// API and network errors are ignored (retried on a later trigger).
    func ensureAccountId() async {
        guard let keyHash = PushSetupStore.keyHash(apiKey: session.apiKey),
              PushSetupStore.accountId(keyHash: keyHash) == nil else { return }
        let client = session.api   // captured before the request so an account switch cannot mix them up
        guard let me = try? await ipv64Retrying({ try await client.account.me() }) else { return }
        PushSetupStore.rememberAccountId(keyHash: keyHash, accountId: me.id)
    }

    /// Android `syncTokenIfChanged(channels?)`: puts a changed token on the stored device channel.
    /// Without `channels` and an unchanged token nothing is requested. Returns `true` if a request updated it.
    @discardableResult
    func syncTokenIfChanged(channels: [HC2Channel]? = nil) async throws -> Bool {
        let apiKey = session.apiKey
        let client = session.api
        guard let storedId = PushSetupStore.channelId(apiKey: apiKey) else { return false }
        let token = storedToken
        let fp = token.map(PushSetupStore.fingerprint)
        let upToDate = token == nil || fp == PushSetupStore.tokenFingerprint(apiKey: apiKey)
        if channels == nil && upToDate { return false }
        var channel = channels?.first { $0.id == storedId && $0.type == .app }
        if channel == nil {
            channel = try await ipv64Retrying { try await client.hc2.channels.list() }
                .first { $0.id == storedId && $0.type == .app }
        }
        guard let channel else {
            PushSetupStore.clearChannel(apiKey: apiKey)
            return false
        }
        guard !upToDate, let token else { return false }
        let types = try? await ipv64Retrying { try await client.hc2.channels.types() }
        let key = PushTokenLogic.tokenKey(for: channel, appType: PushTokenLogic.appType(types))
        if PushTokenLogic.configHoldsToken(channel, key: key, token: token) {
            PushSetupStore.setChannel(apiKey: apiKey, id: storedId, tokenFingerprint: fp)
            return false
        }
        let input = HC2ChannelInput(name: channel.name ?? ChannelLogic.displayName(channel),
                                    config: PushTokenLogic.configWithToken(channel.config, key: key, token: token))
        _ = try await ipv64Retrying { try await client.hc2.channels.update(storedId, input) }
        PushSetupStore.setChannel(apiKey: apiKey, id: storedId, tokenFingerprint: fp)
        return true
    }

    /// Android `detectThisDevice`: stored channel, else token match (then remembered).
    func detectThisDevice(_ channels: [HC2Channel], types: [HC2ChannelType]?) -> HC2Channel? {
        let apiKey = session.apiKey
        let storedId = PushSetupStore.channelId(apiKey: apiKey)
        let token = storedToken
        let key = PushTokenLogic.resolveTokenKey(PushTokenLogic.appType(types))
        guard let found = PushTokenLogic.findThisDevice(channels, storedId: storedId, key: key, token: token) else { return nil }
        if found.id != storedId, let token {
            PushSetupStore.setChannel(apiKey: apiKey, id: found.id, tokenFingerprint: PushSetupStore.fingerprint(token))
        }
        return found
    }

    /// Android `registerThisDevice` (spec 04 §7 steps 1–9).
    func registerThisDevice(_ settings: DeviceChannelSettings, adoptChannelId: Int? = nil,
                            createNew: Bool = false) async throws -> DeviceRegistration {
        guard let token = await ntfyToken() else { throw PushRegistrationError.tokenUnavailable }
        await ensureAccountId()
        let apiKey = session.apiKey
        let client = session.api
        let types = try await ipv64Retrying { try await client.hc2.channels.types() }
        guard let appType = PushTokenLogic.appType(types) else { throw PushRegistrationError.notSupported }
        let resolvedKey = PushTokenLogic.resolveTokenKey(appType)
        let key = resolvedKey ?? PushTokenLogic.fallbackTokenKey
        let channels = try await ipv64Retrying { try await client.hc2.channels.list() }
        let apps = channels.filter { $0.type == .app }
        let storedId = PushSetupStore.channelId(apiKey: apiKey)
        let target = Target(apiKey: apiKey, client: client, key: key, token: token)

        if let adoptChannelId {
            guard let channel = channels.first(where: { $0.id == adoptChannelId }) else {
                throw PushRegistrationError.channelNotFound
            }
            return .registered(try await applyToExisting(channel, settings, target, setToken: true), reused: true)
        }
        if let existing = PushTokenLogic.findThisDevice(channels, storedId: storedId, key: key, token: token) {
            let knownFp = existing.id == storedId ? PushSetupStore.tokenFingerprint(apiKey: apiKey) : nil
            let outdated = !PushTokenLogic.configHoldsToken(existing, key: key, token: token)
                && knownFp != PushSetupStore.fingerprint(token)
            return .registered(try await applyToExisting(existing, settings, target, setToken: outdated), reused: true)
        }
        if !createNew && !apps.isEmpty {
            return .existingCandidates(PushTokenLogic.sortedCandidates(apps, names: [settings.name, Self.defaultDeviceName]))
        }
        return .registered(try await create(settings, appType: appType, resolvedKey: resolvedKey, target), reused: false)
    }

    private struct Target {
        let apiKey: String
        let client: IPv64
        let key: String
        let token: String
    }

    private func create(_ settings: DeviceChannelSettings, appType: HC2ChannelType, resolvedKey: String?,
                        _ target: Target) async throws -> HC2Channel {
        var config: [String: JSONValue] = [target.key: .string(target.token)]
        for field in appType.fields ?? [] where field.required == true {
            guard let fieldKey = field.key?.nonBlank, fieldKey.lowercased() != target.key.lowercased() else { continue }
            guard let value = field.default else {
                let label = field.label?.nonBlank ?? fieldKey
                throw PushRegistrationError.unknownFormat(String(localized: "The server requires the setting \"\(label)\" for app channels. Please add this device at ipv64.net."))
            }
            config[fieldKey] = ChannelLogic.configValue(field, value)
        }
        let input = HC2ChannelInput(name: settings.name, type: .app, config: config, enabled: true,
                                    default: settings.isDefault, lang: settings.lang,
                                    notifyDown: settings.notifyDown, notifyUp: settings.notifyUp)
        let client = target.client
        // Android "no id returned": HC2Channel.id is non-optional, a body without id fails decoding instead.
        let created = try await ipv64Retrying { try await client.hc2.channels.create(input) }
        PushSetupStore.setChannel(apiKey: target.apiKey, id: created.id, tokenFingerprint: PushSetupStore.fingerprint(target.token))
        if PushTokenLogic.holdsTokenKey(created, key: target.key) { return created }
        guard let reloaded = try? await ipv64Retrying({ try await client.hc2.channels.get(created.id) }) else { return created }
        if !PushTokenLogic.holdsTokenKey(reloaded, key: target.key) && resolvedKey == nil {
            PushSetupStore.clearChannel(apiKey: target.apiKey)
            // Not cancellable (Android NonCancellable): the guessed channel must not stay behind.
            await Task { try? await client.hc2.channels.delete(created.id) }.value
            throw PushRegistrationError.unknownFormat(String(localized: "The server describes app channels in a format this app version does not know. Please update the app or add this device at ipv64.net."))
        }
        return reloaded
    }

    /// Android `applyToExisting`: one PATCH with the differences only (never un-defaults), then remember id + fingerprint.
    private func applyToExisting(_ channel: HC2Channel, _ settings: DeviceChannelSettings, _ target: Target,
                                 setToken: Bool) async throws -> HC2Channel {
        let name = settings.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let newName = !name.isEmpty && name != channel.name ? name : nil
        let config = setToken ? PushTokenLogic.configWithToken(channel.config, key: target.key, token: target.token) : nil
        let enabled: Bool? = channel.enabled == false ? true : nil
        let isDefault: Bool? = settings.isDefault && channel.default != true ? true : nil
        let down: Bool? = settings.notifyDown != channel.notifyDown ? settings.notifyDown : nil
        let up: Bool? = settings.notifyUp != channel.notifyUp ? settings.notifyUp : nil
        var result = channel
        if newName != nil || config != nil || enabled != nil || isDefault != nil || down != nil || up != nil {
            // GAP-7: HC2ChannelInput.name is non-optional, so the PATCH always carries the (unchanged) name.
            let input = HC2ChannelInput(name: newName ?? channel.name ?? ChannelLogic.displayName(channel), config: config,
                                        enabled: enabled, default: isDefault, notifyDown: down, notifyUp: up)
            let client = target.client
            result = try await ipv64Retrying { try await client.hc2.channels.update(channel.id, input) }
        }
        PushSetupStore.setChannel(apiKey: target.apiKey, id: channel.id, tokenFingerprint: PushSetupStore.fingerprint(target.token))
        return result
    }

    /// Channel name: the model name from the SecNtfy package (e.g. "iPhone 15 Pro Max"), as SecNtfy names the device.
    static var defaultDeviceName: String {
        let model = UIDevice.current.type
        return model == .unrecognized ? UIDevice.current.name : model.rawValue
    }
}
