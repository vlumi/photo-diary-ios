import Foundation

/// The last JSON answer for each endpoint, on disk per instance, so a
/// relaunch renders what it had before the network says anything new.
/// Bytes, not models: the reader decodes them through the same wire
/// types as a live response. Lives under Caches, so the system may
/// purge it, and everything degrades to a plain load when it does.
public struct ResponseCache: Sendable {
    private let root: URL

    public init(root: URL) {
        self.root = root
    }

    /// The app's cache: `Caches/PhotoDiary/responses`.
    public static func inCaches() -> ResponseCache {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return ResponseCache(root: caches.appending(path: "PhotoDiary/responses"))
    }

    public func load(origin: String, key: String) -> Data? {
        try? Data(contentsOf: url(origin: origin, key: key))
    }

    public func save(_ data: Data, origin: String, key: String) {
        let file = url(origin: origin, key: key)
        try? FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: file, options: .atomic)
    }

    /// Everything cached for one instance — on forget, or when its
    /// access is gone.
    public func clear(origin: String) {
        try? FileManager.default.removeItem(at: directory(origin: origin))
    }

    /// One answer — a gallery that is gone.
    public func clear(origin: String, key: String) {
        try? FileManager.default.removeItem(at: url(origin: origin, key: key))
    }

    private func directory(origin: String) -> URL {
        root.appending(path: Self.fileSafe(origin))
    }

    private func url(origin: String, key: String) -> URL {
        directory(origin: origin).appending(path: Self.fileSafe(key) + ".json")
    }

    /// Origins and keys carry "://", "/" and ":"; one flat name each.
    static func fileSafe(_ s: String) -> String {
        String(s.map { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" ? $0 : "_" })
    }
}
