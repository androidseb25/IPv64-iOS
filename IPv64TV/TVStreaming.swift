import Foundation

/// Streaming mode (Settings): replaces addresses, IPs, client names and domains on screen with plausible fakes,
/// e.g. while the TV is streamed or filmed. Only the display changes; requests use the real values.
/// The fake is derived from a stable hash (FNV-1a, not `Hasher`), so the same input shows the same fake on every launch.
nonisolated enum Streaming {
    private static let prefixes = ["cdn", "api", "static", "img", "edge", "sync", "telemetry", "stream", "auth", "www", "assets", "media", "push", "dl"]
    private static let companies = ["northwind", "contoso", "fabrikam", "tailspin", "litware", "wingtip", "proseware", "woodgrove", "adatum", "lucerne", "alpine", "margie", "humongous", "trey"]
    private static let suffixes = ["", "-media", "-cloud", "-labs", "-systems", "-net"]
    private static let tlds = ["com", "net", "io", "org", "de", "app"]
    private static let places = ["Living-Room", "Kitchen", "Office", "Bedroom", "Garage", "Hallway", "Mia", "Paul", "Lena", "Tom", "Emma", "Jonas"]
    private static let devices = ["TV", "iPad", "PC", "Laptop", "Phone", "Printer", "Console", "Speaker", "NAS", "Watch"]
    private static let localSuffixes = [".fritz.box", ".lan", ".local", ".home", ".home.arpa", ".internal", ".localdomain"]

    /// Domain "spade.twitch.tv" → "cdn.northwind-media.com", device "iPhone-von-X.fritz.box" or "localhost" → "Kitchen-iPad.lan",
    /// IPv4 "192.168.1.10" → "10.141.7.52", IPv6 "fe80::1" → "fd3a:91c2:07be::5d".
    static func mask(_ text: String) -> String {
        let lower = text.lowercased()
        let h = fnv(lower)
        if lower.contains(":") { return "fd" + hex(h, 0, 2) + ":" + hex(h, 8, 4) + ":" + hex(h, 24, 4) + "::" + String(pick(1..<256, h, 40), radix: 16) }
        let labels = lower.split(separator: ".", omittingEmptySubsequences: false)
        if labels.count == 4, labels.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) {
            return "10.\(pick(0..<256, h, 0)).\(pick(0..<256, h, 8)).\(pick(1..<255, h, 16))"
        }
        if labels.count == 1 || localSuffixes.contains(where: lower.hasSuffix) {
            return "\(pick(places, h, 0))-\(pick(devices, h, 12)).lan"
        }
        // The fake TLD never equals the real one, so nothing of the input survives.
        let tld = tlds.filter { $0 != labels.last! }
        return "\(pick(prefixes, h, 0)).\(pick(companies, h, 8))\(pick(suffixes, h, 20)).\(pick(tld, h, 28))"
    }

    /// "http://192.168.1.10:8080/api" → "http://10.141.7.52" (port, path and user info hidden too);
    /// "https://node.example.com" → "https://api.contoso-cloud.io"; "http://[fd00::1]:8080" → "http://[fd3a:91c2:07be::5d]".
    static func maskURL(_ url: String) -> String {
        guard let components = URLComponents(string: url), let scheme = components.scheme, let host = components.host else { return "http://node.lan" }
        let fake = mask(host)
        return "\(scheme)://" + (fake.contains(":") ? "[\(fake)]" : fake)
    }

    /// Node names stay readable unless they look like a host name or address ("Homelab" stays, "nas.fritz.box" is masked).
    static func name(_ name: String, streaming: Bool) -> String {
        streaming && (name.contains(".") || name.contains(":")) ? mask(name) : name
    }

    /// Error text for the screen: network errors can name the host (e.g. certificate errors), so streaming mode
    /// shows only their code.
    static func errorText(_ error: any Error, streaming: Bool) -> String {
        if streaming, let error = error as? URLError { return String(localized: "Network error (\(error.code.rawValue))") }
        return error.localizedDescription
    }

    private static func fnv(_ s: String) -> UInt64 {
        s.utf8.reduce(14695981039346656037) { ($0 ^ UInt64($1)) &* 1099511628211 }
    }
    private static func pick<C: RandomAccessCollection>(_ items: C, _ h: UInt64, _ shift: UInt64) -> C.Element where C.Index == Int {
        items[items.startIndex + Int((h >> shift) % UInt64(items.count))]
    }
    private static func hex(_ h: UInt64, _ shift: UInt64, _ digits: Int) -> String {
        let s = String(h >> shift & 0xFFFF, radix: 16)
        return String(repeating: "0", count: max(0, digits - s.count)) + s.suffix(digits)
    }
}
