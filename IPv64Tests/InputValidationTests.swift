import Testing
@testable import IPv64_net

struct InputValidationTests {
    @Test(arguments: ["0.0.0.0", "1.2.3.4", "255.255.255.255"])
    func ipv4AcceptsPlainAddresses(_ ip: String) {
        #expect(DynDNSLogic.isIpv4(ip))
    }

    @Test(arguments: ["010.1.1.1", "256.1.1.1", "1.2.3", "+1.2.3.4", "1.2.3.4 ", "", "1.2.3.4.5", "a.b.c.d"])
    func ipv4RejectsMalformedAddresses(_ ip: String) {
        #expect(!DynDNSLogic.isIpv4(ip))
    }

    @Test(arguments: ["1.2.3.4", "1.2.3.4/24", "1.2.3.4/0", "1.2.3.4/32", "2001:db8::/32", "2001:db8::1", "::1/128", " 1.2.3.4 "])
    func addressErrorAcceptsValidInput(_ input: String) {
        #expect(ProxyLogic.addressError(input) == nil)
    }

    @Test(arguments: ["1.2.3.4/-0", "1.2.3.4/+8", "1.2.3.4/", "1.2.3.4/33", "1.2.3.4/24/1", "010.1.1.1/24", "", "  ",
                      "2001:db8::/129", "::ffff:1.2.3.4", "fe80::1%en0"])
    func addressErrorRejectsInvalidInput(_ input: String) {
        #expect(ProxyLogic.addressError(input) != nil)
    }

    @Test func addressErrorMessages() {
        #expect(ProxyLogic.addressError("") == "Enter an IP address or network.")
        #expect(ProxyLogic.addressError("1.2.3.4/24/1") == "Use the format 203.0.113.0/24 or 2001:db8::/32.")
        #expect(ProxyLogic.addressError("nope") == "Enter a valid IPv4 or IPv6 address.")
        #expect(ProxyLogic.addressError("1.2.3.4/x") == "The prefix length must be a number.")
        #expect(ProxyLogic.addressError("1.2.3.4/33") == "The prefix length must be between 0 and 32.")
        #expect(ProxyLogic.addressError("::1/129") == "The prefix length must be between 0 and 128.")
    }

    @Test(arguments: [
        ("https://Example.com/x?y", "example.com"),
        ("  example.com. ", "example.com"),
        ("http://a.b-c.de/", "a.b-c.de"),
        ("*.example.com", "*.example.com"),
        ("example.com?x=1", "example.com"),
    ] as [(String, String?)])
    func dns64DomainIsNormalized(input: String, expected: String?) {
        #expect(normalizeDns64Domain(input) == expected)
    }

    @Test(arguments: ["ex ample.com", "localhost", "a..b.com", ".example.com", "", "exa$mple.com", "https://"])
    func dns64DomainRejectsInvalid(_ input: String) {
        #expect(normalizeDns64Domain(input) == nil)
    }
}

struct CountryFlagTests {
    @Test(arguments: [("DE", "🇩🇪"), ("fr", "🇫🇷"), ("??", "??"), ("DEU", "DEU"), ("", ""), (" us ", "🇺🇸")])
    func countryFlag(code: String, expected: String) {
        #expect(SecurityLogic.countryFlag(code) == expected)
    }

    @Test func nilStaysNil() {
        #expect(SecurityLogic.countryFlag(nil) == nil)
    }
}
