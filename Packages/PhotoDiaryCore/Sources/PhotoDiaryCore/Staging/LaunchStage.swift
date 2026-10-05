import Foundation

/// A launch set up from arguments for the store screenshots, so
/// `make shots` needs no hand on the simulator; Scripts/stage.sh lists
/// them. Debug builds only.
public struct LaunchStage: Equatable, Sendable {
    public enum Opening: Equatable, Sendable {
        /// Whatever was open when the app was last left.
        case unchanged
        case frontPage
        case scope(Scope)
    }

    public struct Camera: Equatable, Sendable {
        public let latitude: Double
        public let longitude: Double
        public let latitudeDelta: Double
        public let longitudeDelta: Double
    }

    public struct CalendarStop: Equatable, Sendable {
        public let galleryId: String
        public let year: Int?
        public let month: Int?
    }

    public struct Pin: Equatable, Sendable {
        public let latitude: Double
        public let longitude: Double
        public let note: String
    }

    /// An instance to sign in to with a password, for this launch only.
    public struct SignIn: Equatable, Sendable {
        public let origin: String
        public let user: String
        public let password: String
    }

    public enum Sheet: String, Sendable {
        case settings
        case pins
    }

    public var opening: Opening = .unchanged
    /// `map` or `calendar`; kept as text so Core needn't know the tabs.
    public var tab: String?
    public var camera: Camera?
    public var calendar: CalendarStop?
    public var photoId: String?
    public var pins: [Pin] = []
    public var selection: String?
    public var sheet: Sheet?
    public var signIn: SignIn?

    static let flag = "-photodiary-stage"

    public init?(arguments: [String]) {
        guard arguments.contains(Self.flag) else { return nil }
        func value(_ name: String) -> String? {
            guard let i = arguments.firstIndex(of: "-photodiary-" + name), i + 1 < arguments.count
            else { return nil }
            return arguments[i + 1]
        }
        switch value("scope") {
        case nil: opening = .unchanged
        case "front": opening = .frontPage
        case let instance?:
            opening = .scope(
                Scope(instanceId: Self.instanceId(instance), galleryId: value("gallery")))
        }
        tab = value("tab")
        camera = value("camera").flatMap(Self.camera)
        calendar = value("calendar").flatMap(Self.calendarStop)
        photoId = value("photo")
        pins = value("pins").map(Self.pins) ?? []
        selection = value("select")
        sheet = value("sheet").flatMap(Sheet.init(rawValue:))
        if let host = value("sign-in"), let user = value("user"), let password = value("password") {
            signIn = SignIn(
                origin: RemoteInstanceFactory.canonicalOrigin(host), user: user, password: password)
        }
    }

    public static var current: LaunchStage? {
        #if DEBUG
        LaunchStage(arguments: ProcessInfo.processInfo.arguments)
        #else
        nil
        #endif
    }

    public var scope: Scope? {
        if case .scope(let scope) = opening { return scope }
        return nil
    }

    /// The demo keeps its sentinel; a host is the origin the registry
    /// keys remote instances by.
    private static func instanceId(_ value: String) -> String {
        value == DemoInstance.instanceId ? value : RemoteInstanceFactory.canonicalOrigin(value)
    }

    private static func camera(_ value: String) -> Camera? {
        let numbers = value.split(separator: ",").compactMap {
            Double($0.trimmingCharacters(in: .whitespaces))
        }
        switch numbers.count {
        case 3:
            return Camera(
                latitude: numbers[0], longitude: numbers[1],
                latitudeDelta: numbers[2], longitudeDelta: numbers[2])
        case 4:
            return Camera(
                latitude: numbers[0], longitude: numbers[1],
                latitudeDelta: numbers[2], longitudeDelta: numbers[3])
        default:
            return nil
        }
    }

    private static func calendarStop(_ value: String) -> CalendarStop? {
        let parts = value.split(separator: "/").map(String.init)
        guard let gallery = parts.first else { return nil }
        let year = parts.count > 1 ? Int(parts[1]) : nil
        let month = parts.count > 2 ? Int(parts[2]) : nil
        return CalendarStop(galleryId: gallery, year: year, month: year == nil ? nil : month)
    }

    /// The note is everything after the second comma, so it may hold
    /// commas of its own.
    private static func pins(_ value: String) -> [Pin] {
        value.split(separator: "|").compactMap { entry in
            let parts = entry.split(separator: ",", maxSplits: 2).map(String.init)
            guard parts.count >= 2,
                let latitude = Double(parts[0].trimmingCharacters(in: .whitespaces)),
                let longitude = Double(parts[1].trimmingCharacters(in: .whitespaces))
            else { return nil }
            let note = parts.count > 2 ? parts[2].trimmingCharacters(in: .whitespaces) : ""
            return Pin(latitude: latitude, longitude: longitude, note: note)
        }
    }
}
