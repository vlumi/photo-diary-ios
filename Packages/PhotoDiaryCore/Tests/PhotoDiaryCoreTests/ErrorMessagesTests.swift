import Foundation
import Testing

@testable import PhotoDiaryCore

/// Every error a screen can show must read as a sentence, never as the
/// Foundation fallback "The operation couldn't be completed".
struct ErrorMessagesTests {
    private static let instanceErrors: [InstanceError] = [
        .galleryNotFound("g"), .photoNotFound("p"), .notImplemented, .sessionExpired,
        .server(status: 503), .transport("The Internet connection appears to be offline."),
        .decoding("missing field"),
    ]
    private static let imageErrors: [ImageLoaderError] = [
        .unsupportedScheme("ftp"), .notFound(URL(string: "https://x/y.jpg")!),
        .decodingFailed(URL(string: "https://x/y.jpg")!),
    ]

    @Test(arguments: instanceErrors)
    func instanceErrorReadsAsASentence(_ error: InstanceError) {
        let text = error.localizedDescription
        #expect(!text.contains("operation couldn't be completed"))
        #expect(text.hasSuffix(".") || text.hasSuffix(")"))
    }

    @Test(arguments: imageErrors)
    func imageErrorReadsAsASentence(_ error: ImageLoaderError) {
        let text = error.localizedDescription
        #expect(!text.contains("operation couldn't be completed"))
        #expect(text.hasSuffix("."))
    }

    @Test func serverErrorNamesTheStatus() {
        #expect(InstanceError.server(status: 503).localizedDescription.contains("503"))
    }

    @Test func transportErrorKeepsTheSystemDetail() {
        let text = InstanceError.transport("The Internet connection appears to be offline.")
            .localizedDescription
        #expect(text.hasPrefix("Couldn't reach the server."))
        #expect(text.contains("offline"))
    }
}
