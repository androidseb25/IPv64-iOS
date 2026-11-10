import Foundation
import Testing
@testable import IPv64_net
import IPv64

struct NodeModuleViewTests {
    @Test(arguments: [("Honeypot", "Honeypot"), ("cdn64", "CDN64 / Proxy"), ("checks", "Healthchecks"), ("healthchecks", "Healthchecks"),
                      ("DNS64", "DNS64"), ("DynDNS", "DynDNS")])
    func labelsKnownModulesCaseInsensitive(name: String, label: String) {
        #expect(moduleLabel(name) == label)
        #expect(hasModuleScreen(name))
    }

    @Test func unknownModuleHasNoScreen() {
        #expect(moduleLabel("other") == nil)
        #expect(!hasModuleScreen("other"))
    }
}

struct NodeLogParserTests {
    @Test func parsesNormalLine() {
        let e = parseNodeLogLine("time=2026-11-04T06:03:15.891Z level=info msg=started module=core")
        #expect(e == NodeLogEntry(time: "2026-11-04T06:03:15.891Z", level: "INFO", module: "core", msg: "started"))
    }

    @Test func parsesQuotedMsgWithSpacesAndEscapes() {
        #expect(parseNodeLogLine(#"level=WARN msg="say \"hi\" there" status=up"#)?.msg == #"say "hi" there"#)
    }

    @Test func firstOfRepeatedModuleWins() {
        let e = parseNodeLogLine(#"level=DEBUG msg="check measured" module=healthchecks module=scheduler token=*** status=up"#)
        #expect(e?.module == "healthchecks")
    }

    @Test(arguments: ["plain text without pairs", "a=1 b=2", "", "=x level=info", "level=info trailing"])
    func unparsableLineIsNil(_ line: String) {
        #expect(parseNodeLogLine(line) == nil)
    }

    @Test func mapsEscapesAndParsesOffsetTime() throws {
        let e = try #require(parseNodeLogLine(#"level=INFO msg="a\nb\tc\\d" time=2026-11-04T07:03:15+01:00"#))
        #expect(e.msg == "a\nb\tc\\d")
        #expect(nodeLogClock(e.time) != nil)
    }

    @Test func clockRejectsGarbage() {
        #expect(nodeLogClock("not a time") == nil)
        #expect(nodeLogClock(nil) == nil)
        #expect(nodeLogClock("2026-11-04T06:03:15.891Z")?.count == 8)
    }
}
