import Foundation
import HTTPTypes
import HTTPTypesFoundation
import OpenAPIRuntime

/// The generated client's requests go through the same session as
/// everything else: cookies attached and captured, one refresh and
/// retry on a 401, redirects not followed.
extension PhotoDiaryAPI: ClientTransport {
    public func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        guard var urlRequest = URLRequest(httpRequest: request, baseURL: baseURL) else {
            throw InstanceError.transport("unusable request for \(operationID)")
        }
        if let body {
            urlRequest.httpBody = try await Data(collecting: body, upTo: 1 << 20)
        }
        let (data, response) = try await send(urlRequest)
        guard let httpResponse = response.httpResponse else {
            throw InstanceError.transport("non-HTTP response")
        }
        return (httpResponse, data.isEmpty ? nil : HTTPBody(data))
    }
}

extension URLRequest {
    /// The generated client hands over a path and a base URL apart.
    fileprivate init?(httpRequest: HTTPRequest, baseURL: URL) {
        guard let path = httpRequest.path,
            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
            let relative = URLComponents(string: path)
        else { return nil }
        components.percentEncodedPath =
            components.percentEncodedPath.trimmingSuffix("/") + relative.percentEncodedPath
        components.percentEncodedQuery = relative.percentEncodedQuery
        guard let url = components.url else { return nil }
        self.init(url: url)
        httpMethod = httpRequest.method.rawValue
        for field in httpRequest.headerFields {
            addValue(field.value, forHTTPHeaderField: field.name.canonicalName)
        }
    }
}

extension String {
    fileprivate func trimmingSuffix(_ suffix: String) -> String {
        hasSuffix(suffix) ? String(dropLast(suffix.count)) : self
    }
}

/// What the rest of Core calls: the generated client over one host's
/// session, with its failures turned into the app's own errors.
struct PhotoDiaryClient: Sendable {
    let api: PhotoDiaryAPI
    let client: Client

    init(api: PhotoDiaryAPI) {
        self.api = api
        self.client = Client(serverURL: api.baseURL, transport: api)
    }

    /// Runs one call. The generated client wraps whatever the transport
    /// or the decoder throws; the app wants its own error back.
    func call<T: Sendable>(_ operation: (Client) async throws -> T) async throws -> T {
        do {
            return try await operation(client)
        } catch let error as ClientError {
            if let instanceError = error.underlyingError as? InstanceError { throw instanceError }
            // A failure answer whose body didn't read as documented (an
            // error page from a proxy, say): the status is what counts.
            if let code = error.response?.status.code, !(200..<400).contains(code) {
                throw unexpected(status: code)
            }
            if error.underlyingError is DecodingError {
                throw InstanceError.decoding(String(describing: error.underlyingError))
            }
            throw InstanceError.transport(error.underlyingError.localizedDescription)
        }
    }
}

/// An answer the app has no case for: a session problem, or a status.
func unexpected(status: Int) -> InstanceError {
    status == 401 ? .sessionExpired : .server(status: status)
}
