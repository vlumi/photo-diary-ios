import Foundation

public struct Photo: Identifiable, Hashable, Sendable {
    public let id: String
    public let galleryId: String
    public let title: String
    public let author: String?
    public let timestamp: PhotoTimestamp
    public let location: PhotoLocation
    public let camera: PhotoCamera
    public let exposure: PhotoExposure
    /// `<root>/display/<size>/<id>` on a server, `photodiary-demo://` for
    /// the demo.
    public let displayImageURL: URL
    public let thumbnailURL: URL

    public init(
        id: String,
        galleryId: String,
        title: String = "",
        author: String? = nil,
        timestamp: PhotoTimestamp,
        location: PhotoLocation = PhotoLocation(),
        camera: PhotoCamera = PhotoCamera(),
        exposure: PhotoExposure = PhotoExposure(),
        displayImageURL: URL,
        thumbnailURL: URL
    ) {
        self.id = id
        self.galleryId = galleryId
        self.title = title
        self.author = author
        self.timestamp = timestamp
        self.location = location
        self.camera = camera
        self.exposure = exposure
        self.displayImageURL = displayImageURL
        self.thumbnailURL = thumbnailURL
    }
}
