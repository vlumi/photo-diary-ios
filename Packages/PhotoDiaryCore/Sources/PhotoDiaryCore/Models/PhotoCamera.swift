import Foundation

/// Camera + lens body info from EXIF. Used by the metadata panel; not
/// currently part of the map / calendar pipelines.
public struct PhotoCamera: Hashable, Sendable {
    public let make: String?
    public let model: String?
    public let lensMake: String?
    public let lensModel: String?

    public init(
        make: String? = nil,
        model: String? = nil,
        lensMake: String? = nil,
        lensModel: String? = nil
    ) {
        self.make = make
        self.model = model
        self.lensMake = lensMake
        self.lensModel = lensModel
    }

    /// Convenience for the metadata panel: "FUJIFILM X-T2" or nil when
    /// both halves are missing.
    public var displayName: String? {
        let parts = [make, model].compactMap { $0?.isEmpty == false ? $0 : nil }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    public var lensDisplayName: String? {
        let parts = [lensMake, lensModel].compactMap { $0?.isEmpty == false ? $0 : nil }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}
