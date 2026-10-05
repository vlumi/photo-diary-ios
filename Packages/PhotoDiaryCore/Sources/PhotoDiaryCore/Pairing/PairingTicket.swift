import Foundation

/// A parsed pairing link: `photodiary://sso?host=<host>&token=<ticket>`,
/// optionally `&scheme=http` for a local plain-http instance.
/// Scan, launch and paste all produce this string, so this alone decides
/// whether input is a pairing link.
public struct PairingTicket: Hashable, Sendable, Identifiable {
    public let host: String
    public let token: String
    /// "https" unless the link says `scheme=http`. Plain http is only
    /// reachable for local-network hosts (ATS blocks it elsewhere).
    public let scheme: String

    public var origin: String { "\(scheme)://\(host)" }
    public var id: String { "\(origin)|\(token)" }

    public init(host: String, token: String, scheme: String = "https") {
        self.host = host
        self.token = token
        self.scheme = scheme
    }

    public static func parse(_ url: URL) -> PairingTicket? {
        // Accepts a hostname with optional port and nothing else — no
        // scheme, path, userinfo or whitespace. Keeps a hostile link
        // from smuggling a different origin into the URL the app
        // builds. (Regex isn't Sendable, so it's built per call rather
        // than held in a static.)
        let hostPattern =
            #/^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*(:[0-9]{1,5})?$/#
        guard url.scheme?.lowercased() == "photodiary",
            url.host()?.lowercased() == "sso",
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        else { return nil }
        guard let rawHost = items.first(where: { $0.name == "host" })?.value?.lowercased(),
            let token = items.first(where: { $0.name == "token" })?.value,
            !token.isEmpty,
            rawHost.wholeMatch(of: hostPattern) != nil
        else { return nil }
        let scheme = items.first(where: { $0.name == "scheme" })?.value?.lowercased() ?? "https"
        guard scheme == "https" || (scheme == "http" && isLocalNetwork(rawHost)) else {
            return nil
        }
        return PairingTicket(host: rawHost, token: token, scheme: scheme)
    }

    /// Where plain http may go: a name only the local network resolves,
    /// or a private, loopback or link-local IPv4 address. ATS would let
    /// an IP literal anywhere through.
    static func isLocalNetwork(_ hostWithPort: String) -> Bool {
        let host = String(hostWithPort.split(separator: ":").first ?? "")
        if host == "localhost" || host.hasSuffix(".local") { return true }
        let octets = host.split(separator: ".").map { Int($0) }
        guard octets.count == 4, octets.allSatisfy({ $0 != nil && $0! <= 255 }) else {
            return !host.contains(".")
        }
        switch (octets[0]!, octets[1]!) {
        case (10, _), (127, _), (192, 168), (169, 254): return true
        case (172, 16...31): return true
        default: return false
        }
    }

    public static func parse(_ text: String) -> PairingTicket? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else { return nil }
        return parse(url)
    }
}
