import Foundation
import Testing

@testable import PhotoDiaryCore

/// The hand-written client checked against the server's own OpenAPI
/// document, pinned at a release tag by `make sync-schema TAG=…`.
/// A failure after bumping the tag means the server changed something
/// the app relies on.
@Suite struct ServerContractTests {
    private typealias JSON = [String: Any]

    private let spec: JSON

    init() throws {
        let url = try #require(
            Bundle.module.url(
                forResource: "openapi", withExtension: "json", subdirectory: "Fixtures"))
        spec = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? JSON)
    }

    // MARK: - Reading the document

    private func operation(_ route: APIRoute) -> JSON? {
        let paths = spec["paths"] as? JSON
        return (paths?[route.template] as? JSON)?[route.method.lowercased()] as? JSON
    }

    private func response(_ route: APIRoute, _ status: String) -> JSON? {
        (operation(route)?["responses"] as? JSON)?[status] as? JSON
    }

    private func resolved(_ schema: JSON) -> JSON {
        guard let ref = schema["$ref"] as? String, let name = ref.split(separator: "/").last
        else { return schema }
        let schemas = (spec["components"] as? JSON)?["schemas"] as? JSON
        return schemas?[String(name)] as? JSON ?? schema
    }

    private func bodySchema(of container: JSON?) -> JSON? {
        let content = container?["content"] as? JSON
        return ((content?["application/json"] as? JSON)?["schema"] as? JSON).map(resolved)
    }

    private func parameters(_ route: APIRoute, in place: String) -> [String] {
        let all = operation(route)?["parameters"] as? [JSON] ?? []
        return all.filter { $0["in"] as? String == place }.compactMap { $0["name"] as? String }
    }

    /// The least a response may contain: required properties only.
    /// Decoding it proves a model demands nothing the server doesn't promise.
    private func minimalExample(_ schema: JSON) -> Any {
        let schema = resolved(schema)
        switch schema["type"] as? String {
        case "object":
            let properties = schema["properties"] as? JSON ?? [:]
            let required = schema["required"] as? [String] ?? []
            return Dictionary(
                uniqueKeysWithValues: required.compactMap { key in
                    (properties[key] as? JSON).map { (key, minimalExample($0)) }
                })
        case "array":
            return [(schema["items"] as? JSON).map(minimalExample) ?? [:] as Any]
        case "string": return "x"
        case "boolean": return true
        case "integer", "number": return 1
        default: return NSNull()
        }
    }

    private func decodeMinimal<T: Decodable>(_ type: T.Type, from route: APIRoute) throws -> T {
        let schema = try #require(bodySchema(of: response(route, "200")), "\(route.template)")
        let data = try JSONSerialization.data(
            withJSONObject: minimalExample(schema), options: .fragmentsAllowed)
        return try JSONDecoder().decode(type, from: data)
    }

    // MARK: - Routes and requests

    @Test(arguments: APIRoute.all)
    func theServerHasEveryRouteTheAppCalls(route: APIRoute) {
        #expect(operation(route) != nil, "\(route.method) \(route.template)")
    }

    @Test func theRequestsCarryParametersTheServerDeclares() throws {
        let queryBody = try #require(
            bodySchema(of: operation(.galleryPhotosQuery)?["requestBody"] as? JSON))
        #expect((queryBody["properties"] as? JSON)?["lang"] != nil)
        #expect(parameters(.galleryPhoto, in: "query").contains("lang"))
        #expect(parameters(.consumeTicket, in: "query").contains("token"))
        #expect(parameters(.consumeTicket, in: "query").contains("redirect"))
    }

    // MARK: - Session

    @Test func theSessionCookiesAreTheOnesTheServerReads() throws {
        let schemes = try #require((spec["components"] as? JSON)?["securitySchemes"] as? JSON)
        let access = try #require(schemes["accessCookie"] as? JSON)
        let refresh = try #require(schemes["refreshCookie"] as? JSON)
        #expect(access["in"] as? String == "cookie")
        #expect(access["name"] as? String == SessionCookies.accessName)
        #expect(refresh["in"] as? String == "cookie")
        #expect(refresh["name"] as? String == SessionCookies.refreshName)
    }

    /// The refresh-and-retry loop rests on these: a stale access cookie
    /// answers 401 wherever the app reads data, and refreshing takes
    /// the refresh cookie alone and sets a new pair.
    @Test func refreshAndRetryMatchesWhatTheServerDocuments() throws {
        for route in [APIRoute.galleries, .galleryPhotosQuery, .galleryPhoto, .session] {
            #expect(response(route, "401") != nil, "\(route.template) documents no 401")
        }
        let security = try #require(operation(.refresh)?["security"] as? [JSON])
        #expect(security.count == 1 && security[0]["refreshCookie"] != nil)
        #expect((response(.refresh, "200")?["headers"] as? JSON)?["Set-Cookie"] != nil)
        #expect(response(.refresh, "401") != nil)
    }

    /// Pairing accepts a 302 and then looks for the cookies it set.
    @Test func consumingATicketRedirectsAndStartsASession() {
        #expect((response(.consumeTicket, "302")?["headers"] as? JSON)?["Set-Cookie"] != nil)
        #expect(response(.consumeTicket, "401") != nil)
    }

    // MARK: - Responses

    @Test func theModelsDemandNothingTheServerDoesNotPromise() throws {
        _ = try decodeMinimal(SessionIdentity.self, from: .session)
        let galleries = try decodeMinimal([GalleryDTO].self, from: .galleries)
        #expect(galleries.count == 1)
        _ = try decodeMinimal(MetaDTO.self, from: .meta)
    }

    /// The server types its photo responses as open objects, so the
    /// document cannot vouch for a single field `PhotoDTO` reads. When
    /// the server starts describing photos, this stops failing and the
    /// wrapper reports it: remove it then, and the check is real.
    @Test func photoResponsesAreNotDescribedByTheServerYet() {
        withKnownIssue("photo-diary's spec leaves photo objects untyped") {
            _ = try decodeMinimal(PhotoDTO.self, from: .galleryPhoto)
            _ = try decodeMinimal([PhotoDTO].self, from: .galleryPhotosQuery)
        }
    }
}
