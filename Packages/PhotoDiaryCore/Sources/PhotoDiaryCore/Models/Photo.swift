import Foundation

/// A single photo. Shape mirrors the server's `/api/v1/gallery-photos`
/// response — subset of fields, grown as UI surfaces need them.
public struct Photo: Identifiable, Hashable, Sendable {
    public let id: String
    public let galleryId: String
    public let title: String
    public let author: String?
    public let timestamp: PhotoTimestamp
    public let location: PhotoLocation
    public let camera: PhotoCamera
    public let exposure: PhotoExposure
    /// URL to fetch the display-sized image bytes. Different resource
    /// depending on the surface: `RemoteInstance` returns a
    /// `photos/display/<size>/<id>` URL on the server; `DemoInstance`
    /// returns a `bundle://` URL that maps to an embedded resource.
    public let displayImageURL: URL
    /// Thumbnail URL — same story, different size.
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
