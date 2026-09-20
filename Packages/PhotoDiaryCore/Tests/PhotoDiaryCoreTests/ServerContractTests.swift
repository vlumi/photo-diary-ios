import Foundation
import Testing

@testable import PhotoDiaryCore

/// The server's OpenAPI document at one pinned release tag.
struct PinnedSpec: Sendable, CustomTestStringConvertible {
    typealias JSON = [String: Any]

    /// The newest server the client is checked against.
    static let newest = PinnedSpec(file: "openapi")
    /// The oldest server the app supports. The client may rely only on
    /// what this one already offered: a field a later server added has
    /// to be optional in the models, and a parameter it added can't be
    /// sent unconditionally.
    static let oldestSupported = PinnedSpec(file: "openapi-min")

    let file: String

    var testDescription: String { "\(file).json" }

    func load() throws -> JSON {
        let url = try #require(
            Bundle.module.url(forResource: file, withExtension: "json", subdirectory: "Fixtures"))
        return try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? JSON)
    }
}

/// The hand-written client checked against the server's own OpenAPI
/// document, pinned at release tags by `make sync-schema`. A failure
/// after moving the newest pin means the server changed something the
/// app relies on; a failure against the oldest means the app started
/// relying on something older servers don't have.
@Suite struct ServerContractTests {
    private typealias JSON = PinnedSpec.JSON

    /// Read-only view over one document.
    private struct Document {
        let spec: JSON

        func operation(_ route: APIRoute) -> JSON? {
            let paths = spec["paths"] as? JSON
            return (paths?[route.template] as? JSON)?[route.method.lowercased()] as? JSON
        }

        func response(_ route: APIRoute, _ status: String) -> JSON? {
            (operation(route)?["responses"] as? JSON)?[status] as? JSON
        }

        func resolved(_ schema: JSON) -> JSON {
            guard let ref = schema["$ref"] as? String, let name = ref.split(separator: "/").last
            else { return schema }
            let schemas = (spec["components"] as? JSON)?["schemas"] as? JSON
            return schemas?[String(name)] as? JSON ?? schema
        }

        func bodySchema(of container: JSON?) -> JSON? {
            let content = container?["content"] as? JSON
            return ((content?["application/json"] as? JSON)?["schema"] as? JSON).map(resolved)
        }

        func parameters(_ route: APIRoute, in place: String) -> [String] {
            let all = operation(route)?["parameters"] as? [JSON] ?? []
            return all.filter { $0["in"] as? String == place }.compactMap { $0["name"] as? String }
        }

        /// The least a response may contain: required properties only.
        /// Decoding it proves a model demands nothing the server doesn't promise.
        func minimalExample(_ schema: JSON) -> Any {
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

        /// Everything a response may contain, each value present and
        /// non-null.
        func fullExample(_ schema: JSON) -> Any {
            let schema = resolved(schema)
            if let variants = (schema["anyOf"] ?? schema["oneOf"]) as? [JSON] {
                let real = variants.first { $0["type"] as? String != "null" }
                return real.map(fullExample) ?? NSNull()
            }
            switch schema["type"] as? String {
            case "object":
                let properties = schema["properties"] as? JSON ?? [:]
                return properties.compactMapValues { ($0 as? JSON).map(fullExample) }
            case "array":
                return [(schema["items"] as? JSON).map(fullExample) ?? [:] as Any]
            case "string": return "x"
            case "boolean": return true
            case "integer", "number": return 1
            default: return NSNull()
            }
        }

        func decodeMinimal<T: Decodable>(_ type: T.Type, from route: APIRoute) throws -> T {
            let schema = try #require(bodySchema(of: response(route, "200")), "\(route.template)")
            let data = try JSONSerialization.data(
                withJSONObject: minimalExample(schema), options: .fragmentsAllowed)
            return try JSONDecoder().decode(type, from: data)
        }
    }

    private static let bothPins = [PinnedSpec.newest, .oldestSupported]

    private func document(_ pin: PinnedSpec) throws -> Document {
        Document(spec: try pin.load())
    }

    // MARK: - On every supported server

    @Test(arguments: bothPins)
    func theServerHasEveryRouteTheAppCalls(pin: PinnedSpec) throws {
        let document = try document(pin)
        for route in APIRoute.all {
            #expect(document.operation(route) != nil, "\(route.method) \(route.template)")
        }
    }

    @Test(arguments: bothPins)
    func theRequestsCarryParametersTheServerDeclares(pin: PinnedSpec) throws {
        let document = try document(pin)
        let request = document.operation(.galleryPhotosQuery)?["requestBody"] as? JSON
        let queryBody = try #require(document.bodySchema(of: request))
        #expect((queryBody["properties"] as? JSON)?["lang"] != nil)
        #expect(document.parameters(.galleryPhoto, in: "query").contains("lang"))
        #expect(document.parameters(.consumeTicket, in: "query").contains("token"))
        #expect(document.parameters(.consumeTicket, in: "query").contains("redirect"))
    }

    @Test(arguments: bothPins)
    func theModelsDemandNothingTheServerDoesNotPromise(pin: PinnedSpec) throws {
        let document = try document(pin)
        _ = try document.decodeMinimal(SessionIdentity.self, from: .session)
        let galleries = try document.decodeMinimal([GalleryDTO].self, from: .galleries)
        #expect(galleries.count == 1)
        _ = try document.decodeMinimal(MetaDTO.self, from: .meta)
    }

    // MARK: - Session (documented correctly from photo-diary 1.0.9)

    @Test func theSessionCookiesAreTheOnesTheServerReads() throws {
        let spec = try PinnedSpec.newest.load()
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
        let document = try document(.newest)
        for route in [APIRoute.galleries, .galleryPhotosQuery, .galleryPhoto, .session] {
            #expect(document.response(route, "401") != nil, "\(route.template) documents no 401")
        }
        let security = try #require(document.operation(.refresh)?["security"] as? [JSON])
        #expect(security.count == 1 && security[0]["refreshCookie"] != nil)
        #expect((document.response(.refresh, "200")?["headers"] as? JSON)?["Set-Cookie"] != nil)
        #expect(document.response(.refresh, "401") != nil)
    }

    /// Pairing accepts a 302 and then looks for the cookies it set.
    @Test func consumingATicketRedirectsAndStartsASession() throws {
        let document = try document(.newest)
        #expect(
            (document.response(.consumeTicket, "302")?["headers"] as? JSON)?["Set-Cookie"] != nil)
        #expect(document.response(.consumeTicket, "401") != nil)
    }

    // MARK: - Photos (described from photo-diary 1.1.0)

    /// A photo the server may send with nothing but what it promises:
    /// the model has to decode it. Its date parts may be null (a photo
    /// without a capture date), which the app leaves out rather than
    /// failing on.
    @Test func thePhotoModelDemandsNothingTheServerDoesNotPromise() throws {
        let document = try document(.newest)
        let single = try document.decodeMinimal(PhotoDTO.self, from: .galleryPhoto)
        #expect(single.id == "x")
        let list = try document.decodeMinimal([PhotoDTO].self, from: .galleryPhotosQuery)
        #expect(list.count == 1)
    }

    /// Every optional field the app reads must still exist under that
    /// name: a renamed one would decode as nil without a murmur. A
    /// photo carrying everything the server describes has to come out
    /// of the mapping with each of them filled in.
    @Test func everyFieldTheAppReadsIsOneTheServerDescribes() throws {
        let document = try document(.newest)
        let schema = try #require(document.bodySchema(of: document.response(.galleryPhoto, "200")))
        let data = try JSONSerialization.data(withJSONObject: document.fullExample(schema))
        let dto = try JSONDecoder().decode(PhotoDTO.self, from: data)
        let root = try #require(URL(string: "https://photos.example.test/"))
        let photo = try #require(dto.toDomain(galleryId: "g", photoRoot: root))

        #expect(photo.id == "x")
        #expect(photo.title == "x")
        #expect(photo.author == "x")
        #expect(photo.timestamp.year == 1 && photo.timestamp.hour == 1)
        #expect(photo.location.country == "x")
        #expect(photo.location.coordinates != nil)
        #expect(photo.location.altitude != nil)
        #expect(photo.camera.make == "x" && photo.camera.model == "x")
        #expect(photo.camera.lensMake == "x" && photo.camera.lensModel == "x")
        #expect(photo.exposure.focalLength != nil && photo.exposure.focalLength35mmEquiv != nil)
        #expect(photo.exposure.aperture != nil && photo.exposure.exposureTime != nil)
        #expect(photo.exposure.iso != nil)
        // The largest rendition the server lists becomes the display URL.
        #expect(photo.displayImageURL.absoluteString.hasSuffix("display/1/x"))
    }

    @Test func everyGalleryFieldTheAppReadsIsOneTheServerDescribes() throws {
        let document = try document(.newest)
        let schema = try #require(document.bodySchema(of: document.response(.galleries, "200")))
        let data = try JSONSerialization.data(withJSONObject: document.fullExample(schema))
        let gallery = try #require(try JSONDecoder().decode([GalleryDTO].self, from: data).first)
        #expect(gallery.toDomain().title == "x")
        #expect(gallery.toDomain().description == "x")
    }
}
