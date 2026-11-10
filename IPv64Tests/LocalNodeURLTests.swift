import Testing
@testable import IPv64_net

struct LocalNodeURLTests {
    @Test(arguments: [
        ("192.168.1.10", "http://192.168.1.10:8080/api"),
        (" 192.168.1.10:9000 ", "http://192.168.1.10:9000/api"),
        ("http://10.0.0.1/api/", "http://10.0.0.1/api"),
        ("http://10.0.0.1/api///", "http://10.0.0.1/api"),
        ("http://[fd00::1]:8080", "http://[fd00::1]:8080/api"),
        ("http://[fe80::1]", "http://[fe80::1]/api"),
        ("[fd00::1]", "http://[fd00::1]:8080/api"),
        ("[fd00::1]:9000", "http://[fd00::1]:9000/api"),
        ("http://[FD00:0:0:0:0:0:0:1]", "http://[fd00::1]/api"),
        ("http://nas.local", "http://nas.local/api"),
        ("https://node.example.home64.de", "https://node.example.home64.de/api"),
        ("node.example.home64.de", "https://node.example.home64.de/api"),
        ("node.example.home64.de:9443", "https://node.example.home64.de:9443/api"),
        ("http://node.example.home64.de", "http://node.example.home64.de/api"),
        ("node64.fritz.box", "http://node64.fritz.box:8080/api"),
        ("raspberrypi", "http://raspberrypi:8080/api"),
        ("http://user:pw@192.168.1.10:8080", "http://192.168.1.10:8080/api"),
        ("http://8.8.8.8/api", "http://8.8.8.8/api"),
        ("203.0.113.5", "http://203.0.113.5:8080/api"),
        ("203.0.113.5:9000", "http://203.0.113.5:9000/api"),
        ("http://[2001:db8::1]", "http://[2001:db8::1]/api"),
        ("http://172.32.0.1", "http://172.32.0.1/api"),
        ("https://203.0.113.5", "https://203.0.113.5/api"),
        ("http://10.0.0.1:80/x/y?token=1#frag", "http://10.0.0.1/x/y"),
        ("https://Node.Example.COM:443/api?x=1", "https://node.example.com/api"),
        ("HTTP://NAS.LOCAL:8080", "http://nas.local:8080/api"),
        ("192.168.1.10/custom?x#y", "http://192.168.1.10:8080/custom"),
        ("http://10.0.0.1/api", "http://10.0.0.1/api"),
    ])
    func normalizes(input: String, expected: String) {
        #expect(LocalNodeURL.normalizeLocalNodeUrl(input) == expected)
    }

    @Test(arguments: ["ftp://x", "", "   ", "http://192.168.1.1.", "http://3232235777", "http://", "http://host:99999", "http://host:0",
                      "http://host:abc", "http://[::1", "http://[zz::1]", "http://exa mple.com", "http://bücher.de", "fd00::1", "https://"])
    func rejects(_ input: String) {
        #expect(LocalNodeURL.normalizeLocalNodeUrl(input) == nil)
    }

    @Test(arguments: ["10.0.0.1", "172.16.0.1", "172.31.255.255", "192.168.0.1", "127.0.0.1", "169.254.1.1", "fd00::1", "fe80::1", "::1",
                      "[fd00::1]", "raspberrypi", "nas.local", "x.fritz.box", "NAS.LOCAL", "host.home.arpa", "a.lan", "::ffff:192.168.1.1", "nas.local."])
    func localHosts(_ host: String) {
        #expect(LocalNodeURL.isLocalHost(host))
    }

    @Test(arguments: ["172.32.0.1", "172.15.0.1", "8.8.8.8", "0.0.0.0", "2001:db8::1", "fritz.box", "example.com", "192.168.1.1.", "3232235777",
                      "::ffff:8.8.8.8", "999.1.1.1", "localhost.example.com"])
    func nonLocalHosts(_ host: String) {
        #expect(!LocalNodeURL.isLocalHost(host))
    }

    @Test func ipHostDetection() {
        #expect(LocalNodeURL.isIpHost("1.2.3.4") && LocalNodeURL.isIpHost("fd00::1") && LocalNodeURL.isIpHost("999.1.1.1"))
        #expect(!LocalNodeURL.isIpHost("example.com") && !LocalNodeURL.isIpHost("1.2.3"))
    }

    @Test(arguments: [
        ("http://203.0.113.5:8080/api", true), ("http://192.168.1.10:8080/api", false), ("https://203.0.113.5/api", false),
        ("http://example.com/api", true), ("http://nas.local/api", false), ("garbage", false),
    ])
    func publicHttp(url: String, expected: Bool) {
        #expect(LocalNodeURL.isPublicHttp(url) == expected)
    }

    @Test func hostOfStoredURL() {
        #expect(LocalNodeURL.host(of: "http://[fd00::1]:8080/api") == "[fd00::1]")
        #expect(LocalNodeURL.host(of: "http://nas.local/api") == "nas.local")
        #expect(LocalNodeURL.host(of: "nope") == nil)
    }

    @Test func invalidInputMessageDependsOnScheme() {
        #expect(LocalNodeURL.invalidInputMessage(" http://x").contains("HTTP works"))
        #expect(LocalNodeURL.invalidInputMessage("x").contains("192.168.1.10:8080/api"))
    }

    @Test func literalParsingNeverResolves() {
        #expect(LocalNodeURL.parseLiteral("192.168.1.1") == .v4([192, 168, 1, 1]))
        #expect(LocalNodeURL.parseLiteral("256.1.1.1") == nil)
        #expect(LocalNodeURL.parseLiteral("example.com") == nil)
        #expect(LocalNodeURL.parseLiteral("::1") == .v6([UInt8](repeating: 0, count: 15) + [1]))
    }
}
