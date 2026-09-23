import Foundation
import Testing

@testable import PhotoDiaryCore

/// The API client is generated from the server's OpenAPI document,
/// pinned at a release in `Packages/PhotoDiaryCore/OpenAPI/`, so the
/// compiler holds the app to that release. Two things it can't see:
///
/// - The oldest server the app supports (`Fixtures/openapi-min.json`).
///   The app may rely only on what that one already offered, so a
///   generated call it makes and the answers it decodes are checked
///   against it here.
/// - The session behavior the transport is written for, which lives in
///   the document as prose and headers rather than types.
@Suite struct ServerContractTests {
    private typealias JSON = [String: Any]

    // MARK: - The documents

    private static let openAPIDirectory = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .appending(path: "../../OpenAPI")
        .standardized

    private static func load(_ url: URL) throws -> JSON {
        try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? JSON)
    }

    private let newest: JSON
    private let oldest: JSON
    /// The operations the generated client covers, by name.
    private let operationIds: [String]

    init() throws {
        newest = try Self.load(Self.openAPIDirectory.appending(path: "openapi.json"))
        let fixture = try #require(
            Bundle.module.url(
                forResource: "openapi-min", withExtension: "json", subdirectory: "Fixtures"))
        oldest = try Self.load(fixture)
        let config = try String(
            contentsOf: Self.openAPIDirectory.appending(path: "openapi-generator-config.yaml"),
            encoding: .utf8)
        let list = try #require(config.components(separatedBy: "operations:").last)
        operationIds = list.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("- ") }
            .map { String($0.dropFirst(2)) }
    }

    /// An operation found by name in the newest document, and where it
    /// lives, which is how it is found in an older one (they had no names).
    private struct Located {
        let method: String
        let path: String
        let operation: JSON
    }

    private func locate(_ operationId: String) throws -> Located {
        let paths = try #require(newest["paths"] as? JSON)
        for (path, entry) in paths {
            for (method, operation) in (entry as? JSON) ?? [:] {
                if let operation = operation as? JSON,
                    operation["operationId"] as? String == operationId
                {
                    return Located(method: method, path: path, operation: operation)
                }
            }
        }
        throw ContractError.missing(operationId)
    }

    private enum ContractError: Error { case missing(String) }

    private func operation(in document: JSON, _ located: Located) -> JSON? {
        ((document["paths"] as? JSON)?[located.path] as? JSON)?[located.method] as? JSON
    }

    private func parameters(_ operation: JSON?) -> Set<String> {
        let all = operation?["parameters"] as? [JSON] ?? []
        return Set(all.compactMap { p in (p["name"] as? String).map { "\(p["in"] ?? "")/\($0)" } })
    }

    private static func resolved(_ schema: JSON, in document: JSON) -> JSON {
        guard let ref = schema["$ref"] as? String, let name = ref.split(separator: "/").last
        else { return schema }
        let schemas = (document["components"] as? JSON)?["schemas"] as? JSON
        return schemas?[String(name)] as? JSON ?? schema
    }

    private func bodySchema(_ container: Any?, in document: JSON) -> JSON? {
        let content = (container as? JSON)?["content"] as? JSON
        return ((content?["application/json"] as? JSON)?["schema"] as? JSON)
            .map { Self.resolved($0, in: document) }
    }

    /// The least a response may contain: required properties only.
    private func minimalExample(_ schema: JSON, in document: JSON) -> Any {
        let schema = Self.resolved(schema, in: document)
        switch schema["type"] as? String {
        case "object":
            let properties = schema["properties"] as? JSON ?? [:]
            let required = schema["required"] as? [String] ?? []
            return Dictionary(
                uniqueKeysWithValues: required.compactMap { key in
                    (properties[key] as? JSON).map { (key, minimalExample($0, in: document)) }
                })
        case "array":
            return [(schema["items"] as? JSON).map { minimalExample($0, in: document) } ?? [:]]
        case "string": return "x"
        case "boolean": return true
        case "integer", "number": return 1
        default: return NSNull()
        }
    }

    private func decodeMinimal<T: Decodable>(
        _ type: T.Type, answering operationId: String, in document: JSON
    ) throws -> T {
        let located = try locate(operationId)
        let responses = operation(in: document, located)?["responses"] as? JSON
        let schema = try #require(bodySchema(responses?["200"], in: document), "\(operationId)")
        let data = try JSONSerialization.data(
            withJSONObject: minimalExample(schema, in: document), options: .fragmentsAllowed)
        return try JSONDecoder().decode(type, from: data)
    }

    // MARK: - The oldest supported server

    @Test func theOldestServerHasEveryOperationTheAppCalls() throws {
        #expect(operationIds.count == 7)
        for id in operationIds {
            let located = try locate(id)
            #expect(operation(in: oldest, located) != nil, "\(located.method) \(located.path)")
        }
    }

    @Test func theOldestServerTakesEveryParameterTheAppSends() throws {
        for id in operationIds {
            let located = try locate(id)
            let missing = parameters(located.operation)
                .subtracting(parameters(operation(in: oldest, located)))
            #expect(missing.isEmpty, "\(id) sends \(missing) that 1.0.7 doesn't take")
        }
        let query = try locate("queryGalleryPhotos")
        let body = bodySchema(operation(in: oldest, query)?["requestBody"], in: oldest)
        #expect((body?["properties"] as? JSON)?["lang"] != nil)
    }

    /// What the oldest server promises decodes into the generated types,
    /// so they demand nothing it doesn't send. Its photos weren't
    /// described yet; those answers were always complete in practice.
    @Test func theOldestServersAnswersDecode() throws {
        let galleries = try decodeMinimal(
            [Components.Schemas.Gallery].self, answering: "listGalleries", in: oldest)
        #expect(galleries.count == 1)
        _ = try decodeMinimal(
            Operations.GetSession.Output.Ok.Body.JsonPayload.self,
            answering: "getSession", in: oldest)
        _ = try decodeMinimal(
            Operations.GetMeta.Output.Ok.Body.JsonPayload.self, answering: "getMeta", in: oldest)
    }

    // MARK: - The session the transport is written for

    @Test func theSessionCookiesAreTheOnesTheServerReads() throws {
        let schemes = try #require((newest["components"] as? JSON)?["securitySchemes"] as? JSON)
        let access = try #require(schemes["accessCookie"] as? JSON)
        let refresh = try #require(schemes["refreshCookie"] as? JSON)
        #expect(access["in"] as? String == "cookie")
        #expect(access["name"] as? String == SessionCookies.accessName)
        #expect(refresh["in"] as? String == "cookie")
        #expect(refresh["name"] as? String == SessionCookies.refreshName)
    }

    /// The transport refreshes on a 401 and retries once, by sending the
    /// refresh cookie alone and taking the new pair it sets.
    @Test func refreshAndRetryMatchesWhatTheServerDocuments() throws {
        for id in ["listGalleries", "queryGalleryPhotos", "getGalleryPhoto", "getSession"] {
            let responses = try locate(id).operation["responses"] as? JSON
            #expect(responses?["401"] != nil, "\(id) documents no 401")
        }
        let refresh = try locate("refreshSession")
        // The transport sends this one itself, by path.
        #expect(refresh.path == "/api/v1/tokens/refresh" && refresh.method == "post")
        let security = try #require(refresh.operation["security"] as? [JSON])
        #expect(security.count == 1 && security[0]["refreshCookie"] != nil)
        let ok = (refresh.operation["responses"] as? JSON)?["200"] as? JSON
        #expect((ok?["headers"] as? JSON)?["Set-Cookie"] != nil)
    }

    /// Pairing takes the 302 as success and reads the cookies it set.
    @Test func consumingATicketRedirectsAndStartsASession() throws {
        let found = (try locate("consumeTicket").operation["responses"] as? JSON)?["302"] as? JSON
        #expect((found?["headers"] as? JSON)?["Set-Cookie"] != nil)
    }
}
