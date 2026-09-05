import Foundation

/// Exposure settings pulled from EXIF. All fields optional — cameras
/// vary in what they tag, and older / phone-only photos may lack
/// several. Presented in the metadata panel; the map / calendar don't
/// read them.
public struct PhotoExposure: Hashable, Sendable {
    public let focalLength: Double?
    public let focalLength35mmEquiv: Double?
    public let aperture: Double?
    public let exposureTime: Double?
    public let iso: Int?

    public init(
        focalLength: Double? = nil,
        focalLength35mmEquiv: Double? = nil,
        aperture: Double? = nil,
        exposureTime: Double? = nil,
        iso: Int? = nil
    ) {
        self.focalLength = focalLength
        self.focalLength35mmEquiv = focalLength35mmEquiv
        self.aperture = aperture
        self.exposureTime = exposureTime
        self.iso = iso
    }
}
