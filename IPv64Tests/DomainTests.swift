import Testing
@testable import IPv64_net
import IPv64

struct DomainIpTests {
    private func detail(_ records: String?, ignore: String? = nil, prefix: String? = nil) throws -> DomainDetail {
        var fields = ["\"id\":1"]
        if let records { fields.append("\"records\":[\(records)]") }
        if let ignore { fields.append("\"ignore\":\"\(ignore)\"") }
        if let prefix { fields.append("\"ipv6_prefix\":\"\(prefix)\"") }
        return try decode("{\(fields.joined(separator: ","))}")
    }
    private func rec(_ type: String, _ content: String) -> String { "{\"id\":1,\"type\":\"\(type)\",\"content\":\"\(content)\"}" }

    @Test func noAddressRecordsMeansNoIp() throws {
        #expect(!DynDNSLogic.hasIp(nil))
        #expect(!DynDNSLogic.hasIp(try detail(nil)))
        #expect(!DynDNSLogic.hasIp(try detail(rec("TXT", "hello"))))
    }

    @Test(arguments: ["A", "AAAA"])
    func addressRecordMeansIp(_ type: String) throws {
        #expect(DynDNSLogic.hasIp(try detail(rec(type, "1.2.3.4"))))
    }

    @Test func statusComputation() throws {
        let a = try detail(rec("A", "1.2.3.4"))
        #expect(DynDNSLogic.status(nil, myV4: "1.2.3.4", myV6: "::") == .checking)
        #expect(DynDNSLogic.status(try detail(nil), myV4: "1.2.3.4", myV6: "::") == .noIp)
        #expect(DynDNSLogic.status(a, myV4: "0.0.0.0", myV6: "::") == .unknown)
        #expect(DynDNSLogic.status(a, myV4: "1.2.3.4", myV6: "::") == .matches)
        #expect(DynDNSLogic.status(a, myV4: "9.9.9.9", myV6: "::") == .differs)
        // ignore=ipv4 never mismatches on v4
        #expect(DynDNSLogic.status(try detail(rec("A", "1.2.3.4"), ignore: "ipv4"), myV4: "9.9.9.9", myV6: "::") == .matches)
    }

    @Test func fixedIpv6PrefixNeverMismatches() throws {
        let aaaa = try detail(rec("AAAA", "2001:db8::1"), prefix: "2001:db8::/64")
        #expect(DynDNSLogic.status(aaaa, myV4: "0.0.0.0", myV6: "2001:db8::2") == .matches)
        let plain = try detail(rec("AAAA", "2001:db8::1"))
        #expect(DynDNSLogic.status(plain, myV4: "0.0.0.0", myV6: "2001:db8::2") == .differs)
    }
}

struct DomainKindFilterTests {
    private let domains: [(name: String, kind: String?)] = [
        ("a.ipv64.net", "dyndns"), ("b.example.org", "own"), ("c.home64.de", nil), ("d.example.org", nil),
    ]

    private func names(_ filter: DomainKindFilter) -> [String] {
        domains.filter { filter.matches(kind: $0.kind.map { DomainKind(rawValue: $0) }, name: $0.name) }.map(\.name)
    }

    @Test func filtersByKindWithZoneFallback() {
        #expect(names(.all).count == 4)
        #expect(names(.dyndns) == ["a.ipv64.net", "c.home64.de"])
        #expect(names(.own) == ["b.example.org", "d.example.org"])
    }
}
