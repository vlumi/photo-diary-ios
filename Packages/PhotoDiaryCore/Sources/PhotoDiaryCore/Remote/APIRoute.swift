import Foundation

/// Every server route the app calls, in the OpenAPI document's own
/// notation. The client builds its paths from these and the contract
/// test checks the same list against the pinned server spec, so the
/// two cannot drift apart.
struct APIRoute: Hashable, Sendable {
    let method: String
    /// Path with `{name}` placeholders, as the server's spec writes it.
    let template: String

    /// The template with its placeholders filled, in order.
    func path(_ values: String...) -> String {
        var remaining = values[...]
        var path = ""
        var rest = template[...]
        while let open = rest.firstIndex(of: "{"), let close = rest[open...].firstIndex(of: "}") {
            path += rest[..<open]
            path += remaining.popFirst() ?? ""
            rest = rest[rest.index(after: close)...]
        }
        return path + rest
    }

    static let galleries = APIRoute(method: "GET", template: "/api/v1/galleries")
    static let galleryPhotosQuery = APIRoute(
        method: "POST", template: "/api/v1/gallery-photos/{galleryId}/query")
    static let galleryPhoto = APIRoute(
        method: "GET", template: "/api/v1/gallery-photos/{galleryId}/{photoId}")
    static let meta = APIRoute(method: "GET", template: "/api/v1/meta")
    static let session = APIRoute(method: "GET", template: "/api/v1/tokens")
    static let refresh = APIRoute(method: "POST", template: "/api/v1/tokens/refresh")
    static let consumeTicket = APIRoute(method: "GET", template: "/api/v1/tokens/sso")

    static let all: [APIRoute] = [
        galleries, galleryPhotosQuery, galleryPhoto, meta, session, refresh, consumeTicket,
    ]
}
