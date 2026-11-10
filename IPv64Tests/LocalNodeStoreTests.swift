import Foundation
import Testing
@testable import IPv64_net
import IPv64

struct LocalNodeIdsTests {
    @Test func listsOnlyNodesWithUrlOfOwner() {
        let prefs: [String: Any] = [
            "b.url": "u", "b.key": "k", "b.owner": "1", "b.name": "Beta",
            "a.url": "u", "a.key": "k", "a.owner": "1",
            "c.url": "u", "c.key": "k", "c.owner": "2",
            "d.key": "k", "d.owner": "1",
        ]
        #expect(LocalNodeStore.localNodeIds(prefs, owner: "1") == ["a", "b"])
        #expect(LocalNodeStore.localNodeIds(prefs, owner: "2") == ["c"])
        #expect(LocalNodeStore.localNodeIds(prefs, owner: "3").isEmpty)
    }

    @Test(arguments: [("cdn64", true), ("PROXY64", true), ("proxy", true), ("dns64", false), ("checks", false)])
    func proxyModuleNames(name: String, expected: Bool) {
        #expect(LocalNodeStore.isProxyModule(name) == expected)
    }
}

/// Mutates the shared `LocalNodeStore.overrideDefaults` seam, so the cases must not run in parallel.
@Suite(.serialized)
struct LocalNodeStoreTests {
    private let defaults: UserDefaults

    init() {
        defaults = isolatedDefaults("LocalNodeStoreTests")
        LocalNodeStore.overrideDefaults = defaults
    }

    private func module(_ name: String, enabled: Bool) throws -> Node64.ModuleStatus {
        try decode("{\"name\":\"\(name)\",\"enabled\":\(enabled)}")
    }

    @Test func saveModulesStoresProxyAndDnsFlags() throws {
        LocalNodeStore.saveModules("n1", modules: [try module("CDN64", enabled: true), try module("dns64", enabled: false)])
        #expect(LocalNodeStore.proxyActive("n1"))
        #expect(!LocalNodeStore.dnsActive("n1"))
        LocalNodeStore.saveModules("n1", modules: [try module("proxy", enabled: false), try module("DNS64", enabled: true)])
        #expect(!LocalNodeStore.proxyActive("n1"))
        #expect(LocalNodeStore.dnsActive("n1"))
    }

    @Test func saveModulesWritesOnlyOnChange() throws {
        let modules = [try module("cdn64", enabled: true)]
        LocalNodeStore.saveModules("n1", modules: modules)
        // Tamper with the stored value: an unchanged module state must not rewrite it.
        defaults.set(true, forKey: "NODE64_LOCAL.n1.dns")
        LocalNodeStore.saveModules("n1", modules: [try module("cdn64", enabled: true), try module("dns64", enabled: true)])
        #expect(LocalNodeStore.dnsActive("n1"))
        defaults.set(false, forKey: "NODE64_LOCAL.n1.dns")
        LocalNodeStore.saveModules("n1", modules: modules)   // proxy true == stored, dns false == stored → no write
        #expect(!LocalNodeStore.dnsActive("n1"))
        #expect(defaults.object(forKey: "NODE64_LOCAL.n2.proxy") == nil)
        LocalNodeStore.saveModules("n2", modules: [])        // false/false == defaults → nothing written
        #expect(defaults.object(forKey: "NODE64_LOCAL.n2.proxy") == nil)
    }

    @Test func listAndNameFilterByOwner() throws {
        defaults.set("http://a/api", forKey: "NODE64_LOCAL.a.url"); defaults.set("1", forKey: "NODE64_LOCAL.a.owner")
        defaults.set("http://b/api", forKey: "NODE64_LOCAL.b.url"); defaults.set("2", forKey: "NODE64_LOCAL.b.owner")
        defaults.set("other", forKey: "unrelated.url")
        #expect(LocalNodeStore.list(owner: "1") == ["a"])
        #expect(LocalNodeStore.list(owner: "2") == ["b"])
        LocalNodeStore.setName("a", "Alpha")
        #expect(LocalNodeStore.name("a") == "Alpha")
        #expect(LocalNodeStore.get("a", owner: "2") == nil)   // wrong owner
    }

    @Test func removeOwnerDeletesOnlyThatOwnersNodes() {
        for (id, owner) in [("a", "1"), ("b", "1"), ("c", "2")] {
            defaults.set("http://\(id)/api", forKey: "NODE64_LOCAL.\(id).url")
            defaults.set(owner, forKey: "NODE64_LOCAL.\(id).owner")
            defaults.set(id, forKey: "NODE64_LOCAL.\(id).name")
            defaults.set(true, forKey: "NODE64_LOCAL.\(id).proxy")
        }
        LocalNodeStore.removeOwner("1")
        #expect(LocalNodeStore.list(owner: "1").isEmpty)
        #expect(LocalNodeStore.name("a") == nil && !LocalNodeStore.proxyActive("b"))
        #expect(LocalNodeStore.list(owner: "2") == ["c"])
        #expect(LocalNodeStore.name("c") == "c")
    }

    @Test func saveGetRemoveRoundTripUsesKeychain() throws {
        defer { LocalNodeStore.remove("rt") }
        try LocalNodeStore.save(id: "rt", url: "http://10.0.0.1:8080/api", key: "secret", owner: "1")
        #expect(LocalNodeStore.get("rt", owner: "1") == .init(url: "http://10.0.0.1:8080/api", key: "secret"))
        #expect(LocalNodeStore.get("rt", owner: "2") == nil)
        #expect(LocalNodeStore.name("rt") == nil)
        LocalNodeStore.remove("rt")
        #expect(LocalNodeStore.get("rt", owner: "1") == nil)
        #expect(LocalNodeStore.list(owner: "1").isEmpty)
    }
}
