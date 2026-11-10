import Foundation
import Testing
@testable import IPv64_net
import IPv64

/// Mutates the shared `PushSetupStore.overrideDefaults` seam, so the cases must not run in parallel.
@Suite(.serialized)
struct PushSetupStoreTests {
    private let defaults: UserDefaults
    private let key = "  my-api-key \n"

    init() {
        defaults = isolatedDefaults("PushSetupStoreTests")
        PushSetupStore.overrideDefaults = defaults
    }

    @Test func hashesAndFingerprints() {
        #expect(PushSetupStore.sha256Hex("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        #expect(PushSetupStore.fingerprint(" tok\n") == PushSetupStore.sha256Hex("tok"))
        #expect(PushSetupStore.keyHash(apiKey: "  ") == nil)
        #expect(PushSetupStore.keyHash(apiKey: key) == String(PushSetupStore.sha256Hex("my-api-key").prefix(16)))
        let scope = PushSetupStore.accountScope(accountId: 7)
        #expect(scope == "a" + PushSetupStore.sha256Hex("account:7").prefix(16))
        #expect(scope.count == 17)
    }

    @Test func scopeIsKeyHashUntilAccountIdKnown() throws {
        let hash = try #require(PushSetupStore.keyHash(apiKey: key))
        #expect(PushSetupStore.scope(apiKey: key) == hash)
        PushSetupStore.rememberAccountId(keyHash: hash, accountId: 42)
        #expect(PushSetupStore.accountId(keyHash: hash) == 42)
        #expect(PushSetupStore.scope(apiKey: key) == PushSetupStore.accountScope(accountId: 42))
        #expect(PushSetupStore.scope(apiKey: "") == nil)
    }

    @Test func loggedOutNeverShowsAndWritesNothing() {
        #expect(!PushSetupStore.shouldShow(apiKey: ""))
        PushSetupStore.markDone(apiKey: "")
        PushSetupStore.setChannel(apiKey: "", id: 1, tokenFingerprint: "x")
        #expect(PushSetupStore.channelId(apiKey: "") == nil)
        #expect(defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("HC2_PUSH_SETUP.") }.isEmpty)
    }

    @Test func shouldShowDependsOnDoneChannelAndConfig() {
        #expect(PushSetupStore.shouldShow(apiKey: key) == AppConfig.isSecNtfyConfigured)
        PushSetupStore.markDone(apiKey: key)
        #expect(!PushSetupStore.shouldShow(apiKey: key))
    }

    @Test func storedChannelHidesSetup() {
        PushSetupStore.setChannel(apiKey: key, id: 5, tokenFingerprint: "fp")
        #expect(!PushSetupStore.shouldShow(apiKey: key))
        #expect(PushSetupStore.channelId(apiKey: key) == 5)
        #expect(PushSetupStore.tokenFingerprint(apiKey: key) == "fp")
        PushSetupStore.setChannel(apiKey: key, id: 6, tokenFingerprint: nil)
        #expect(PushSetupStore.tokenFingerprint(apiKey: key) == nil)
        PushSetupStore.clearChannel(apiKey: key)
        #expect(PushSetupStore.channelId(apiKey: key) == nil)
        #expect(PushSetupStore.shouldShow(apiKey: key) == AppConfig.isSecNtfyConfigured)
    }

    @Test func rememberAccountIdMigratesKeyHashEntries() throws {
        let hash = try #require(PushSetupStore.keyHash(apiKey: key))
        PushSetupStore.setChannel(apiKey: key, id: 9, tokenFingerprint: "fp")
        PushSetupStore.markDone(apiKey: key)
        PushSetupStore.rememberAccountId(keyHash: hash, accountId: 3)
        #expect(PushSetupStore.channelId(apiKey: key) == 9)
        #expect(PushSetupStore.tokenFingerprint(apiKey: key) == "fp")
        #expect(!PushSetupStore.shouldShow(apiKey: key))
        for field in ["done_", "channel_", "tokenfp_"] {
            #expect(defaults.object(forKey: "HC2_PUSH_SETUP." + field + hash) == nil)
        }
    }

    @Test func existingAccountChannelWinsOverMigration() throws {
        let hash = try #require(PushSetupStore.keyHash(apiKey: key))
        let account = PushSetupStore.accountScope(accountId: 3)
        defaults.set(1, forKey: "HC2_PUSH_SETUP.channel_" + account)
        defaults.set(2, forKey: "HC2_PUSH_SETUP.channel_" + hash)
        defaults.set("old", forKey: "HC2_PUSH_SETUP.tokenfp_" + hash)
        PushSetupStore.rememberAccountId(keyHash: hash, accountId: 3)
        #expect(PushSetupStore.channelId(apiKey: key) == 1)
        #expect(PushSetupStore.tokenFingerprint(apiKey: key) == nil)
    }
}

struct PushTokenLogicTests {
    private func appType(_ fields: String) throws -> HC2ChannelType {
        try decode("{\"type\":\"app\",\"fields\":[\(fields)]}")
    }
    private func channel(_ json: String) throws -> HC2Channel { try decode("{\"id\":1,\"type\":\"app\"\(json)}") }

    @Test(arguments: [
        (#"{"key":"foo"},{"key":"Device_Token"}"#, "Device_Token"),
        (#"{"key":"my_token_x"},{"key":"token"}"#, "token"),
        (#"{"key":"a"},{"key":"push_token_id"}"#, "push_token_id"),
        (#"{"key":"only","required":true,"kind":"text"}"#, "only"),
    ])
    func resolveTokenKey(fields: String, expected: String) throws {
        #expect(PushTokenLogic.resolveTokenKey(try appType(fields)) == expected)
    }

    @Test func resolveTokenKeyAmbiguousIsNil() throws {
        #expect(PushTokenLogic.resolveTokenKey(try appType(#"{"key":"a","required":true},{"key":"b","required":true}"#)) == nil)
        #expect(PushTokenLogic.resolveTokenKey(nil) == nil)
    }

    @Test func tokenKeyFallbackChain() throws {
        #expect(PushTokenLogic.tokenKey(for: try channel(""), appType: nil) == "device_token")
        #expect(PushTokenLogic.tokenKey(for: try channel(#","secrets_set":["x","My_Token"]"#), appType: nil) == "My_Token")
        #expect(PushTokenLogic.tokenKey(for: try channel(#","config":{"zz_token":"1","aa_token":"2"}"#), appType: nil) == "aa_token")
    }

    @Test func fingerprintComparisonAndConfigMerge() throws {
        let c = try channel(#","config":{"Device_Token":"  tok  ","other":"x"}"#)
        #expect(PushTokenLogic.configHoldsToken(c, key: "device_token", token: "tok"))
        #expect(PushTokenLogic.configHoldsToken(c, key: nil, token: "tok"))
        #expect(!PushTokenLogic.configHoldsToken(c, key: nil, token: "nope"))
        #expect(!PushTokenLogic.configHoldsToken(try channel(""), key: nil, token: "tok"))
        let merged = PushTokenLogic.configWithToken(["DEVICE_TOKEN": .string("old"), "keep": .bool(true)], key: "device_token", token: "new")
        #expect(merged == ["device_token": .string("new"), "keep": .bool(true)])
    }

    @Test func findsThisDeviceByStoredIdThenToken() throws {
        let a: HC2Channel = try decode(#"{"id":1,"type":"app","config":{"t":"tok"}}"#)
        let b: HC2Channel = try decode(#"{"id":2,"type":"app"}"#)
        let mail: HC2Channel = try decode(#"{"id":3,"type":"ipv64_mail"}"#)
        #expect(PushTokenLogic.findThisDevice([a, b, mail], storedId: 2, key: nil, token: "tok")?.id == 2)
        #expect(PushTokenLogic.findThisDevice([a, b, mail], storedId: 3, key: nil, token: "tok")?.id == 1)
        #expect(PushTokenLogic.findThisDevice([a, b], storedId: nil, key: "t", token: nil) == nil)
        #expect(PushTokenLogic.findThisDevice([b], storedId: nil, key: nil, token: "tok") == nil)
    }

    @Test func holdsTokenKeyAndCandidateOrder() throws {
        let c = try channel(#","secrets_set":["Device_Token"]"#)
        #expect(PushTokenLogic.holdsTokenKey(c, key: "device_token"))
        #expect(!PushTokenLogic.holdsTokenKey(c, key: "other"))
        let a: HC2Channel = try decode(#"{"id":1,"type":"app","name":"Other"}"#)
        let b: HC2Channel = try decode(#"{"id":2,"type":"app","name":" iPhone "}"#)
        #expect(PushTokenLogic.sortedCandidates([a, b], names: ["iphone"]).map(\.id) == [2, 1])
    }
}

struct ChannelLogicTests {
    private func field(_ json: String) throws -> HC2ChannelType.Field { try decode(json) }

    @Test(arguments: [("true", true), (" YES ", true), ("1", true), ("on", true), ("false", false), ("", false), ("2", false)])
    func parseBool(raw: String, expected: Bool) {
        #expect(ChannelLogic.parseBool(raw) == expected)
    }

    @Test func configValueByKind() throws {
        #expect(ChannelLogic.configValue(try field(#"{"key":"k","kind":"bool"}"#), "yes") == .bool(true))
        let number = try field(#"{"key":"k","kind":"number"}"#)
        #expect(ChannelLogic.configValue(number, " 5 ") == .number(5))
        #expect(ChannelLogic.configValue(number, "1.5") == .number(1.5))
        #expect(ChannelLogic.configValue(number, "x") == .string("x"))
        #expect(ChannelLogic.configValue(try field(#"{"key":"k"}"#), " raw ") == .string(" raw "))
    }

    @Test func textOfJSONValues() {
        #expect(ChannelLogic.text(nil) == "" && ChannelLogic.text(.null) == "")
        #expect(ChannelLogic.text(.bool(true)) == "true")
        #expect(ChannelLogic.text(.number(8)) == "8")
        #expect(ChannelLogic.text(.number(1.5)) == "1.5")
        #expect(ChannelLogic.text(.string("s")) == "s")
    }

    @Test func buildConfigForNewChannelOmitsBlankOptionals() throws {
        let fields = [try field(#"{"key":"url"}"#), try field(#"{"key":"opt"}"#), try field(#"{"key":"pw","kind":"password"}"#),
                      try field(#"{"key":"port","kind":"number"}"#), try field(#"{"key":"on","kind":"bool"}"#)]
        let map = ChannelLogic.buildConfig(fields: fields, values: ["url": "  https://x ", "opt": " ", "pw": " s3 ", "port": "25", "on": "true"],
                                           touched: [], base: ["ignored": .string("x")], isEdit: false)
        #expect(map == ["url": .string("https://x"), "pw": .string(" s3 "), "port": .number(25), "on": .bool(true)])
    }

    @Test func buildConfigForEditKeepsUnknownKeysAndSecretsUntilTouched() throws {
        let fields = [try field(#"{"key":"url"}"#), try field(#"{"key":"pw","kind":"password"}"#), try field(#"{"key":"keep"}"#)]
        let base: [String: JSONValue] = ["url": .string("old"), "unknown": .string("u"), "keep": .string("k")]
        let untouched = ChannelLogic.buildConfig(fields: fields, values: ["url": "", "pw": "typed"], touched: [], base: base, isEdit: true, keepKeys: ["keep"])
        #expect(untouched == ["url": .string(""), "unknown": .string("u"), "keep": .string("k")])
        let touched = ChannelLogic.buildConfig(fields: fields, values: ["url": "new", "pw": "typed"], touched: ["pw"], base: base, isEdit: true)
        #expect(touched["pw"] == .string("typed") && touched["url"] == .string("new"))
    }

    @Test func fieldErrors() throws {
        #expect(ChannelLogic.fieldError(try field(#"{"key":"k"}"#), value: " ", required: true) != nil)
        #expect(ChannelLogic.fieldError(try field(#"{"key":"k"}"#), value: " ", required: false) == nil)
        #expect(ChannelLogic.fieldError(try field(#"{"key":"k","kind":"number"}"#), value: "x", required: false) != nil)
        #expect(ChannelLogic.fieldError(try field(#"{"key":"k","kind":"bool"}"#), value: "", required: true) == nil)
    }

    @Test func initialValues() throws {
        let secret = try field(#"{"key":"k","secret":true,"default":"d"}"#)
        #expect(ChannelLogic.initialValue(secret, config: ["k": .string("x")], isEdit: true) == "")
        #expect(ChannelLogic.initialValue(secret, config: nil, isEdit: false) == "d")
        let bool = try field(#"{"key":"k","kind":"bool","default":"true"}"#)
        #expect(ChannelLogic.initialValue(bool, config: ["k": .bool(false)], isEdit: true) == "false")
        #expect(ChannelLogic.initialValue(bool, config: [:], isEdit: true) == "true")
    }

    @Test func awaitingVerificationAndDisplayName() throws {
        let mail: HC2Channel = try decode(#"{"id":4,"type":"ipv64_mail","verified":false}"#)
        #expect(ChannelLogic.isAwaitingVerification(mail, types: nil))
        #expect(!ChannelLogic.isAwaitingVerification(mail, types: [try decode(#"{"type":"ipv64_mail","needs_verification":false}"#)]))
        let verified: HC2Channel = try decode(#"{"id":4,"type":"ipv64_mail","verified":true}"#)
        #expect(!ChannelLogic.isAwaitingVerification(verified, types: nil))
        #expect(ChannelLogic.displayName(try decode(#"{"id":1,"name":" N ","type_label":"L"}"#)) == " N ")
        #expect(ChannelLogic.displayName(try decode(#"{"id":1,"name":" ","type_label":"L"}"#)) == "L")
        #expect(ChannelLogic.displayName(try decode(#"{"id":1,"type":"webhook"}"#)) == "webhook")
    }
}
