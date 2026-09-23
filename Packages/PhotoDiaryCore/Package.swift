// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "PhotoDiaryCore",
    // String Catalogs live in every target that ships user-facing strings.
    // English is the base language.
    defaultLocalization: "en",
    platforms: [
        // Match the app's iOS-latest-only stance. When iOS 26 goes GA and
        // we've tested on the release, bump both this and project.yml.
        .iOS(.v26),
        // macOS floor exists solely so `swift test` on CI (which builds
        // for the host, not iOS) can see modern availability like
        // @Observable. The app itself never runs on macOS.
        .macOS(.v14),
    ],
    products: [
        // Pure API + models + persistence. Headlessly testable, no UI
        // dependency.
        .library(name: "PhotoDiaryCore", targets: ["PhotoDiaryCore"]),
        // SwiftUI views + MapKit surface. Depends on Core.
        .library(name: "PhotoDiaryKit", targets: ["PhotoDiaryKit"]),
        // Dev tool: renders the app icon from AppIconScene (make icon).
        .executable(name: "photodiary-icon", targets: ["PhotoDiaryIcon"]),
    ],
    dependencies: [
        // Image pipeline for RemoteImageLoader: memory + disk cache,
        // request coalescing, cancellation. DemoImageLoader stays
        // dependency-free — its tiles are procedural.
        .package(url: "https://github.com/kean/Nuke.git", from: "13.2.0"),
        // Runtime for the client generated from the server's OpenAPI
        // document (Sources/PhotoDiaryCore/Generated, `make generate-client`).
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.12.1"),
        .package(url: "https://github.com/apple/swift-http-types", from: "1.4.0"),
    ],
    targets: [
        .target(
            name: "PhotoDiaryCore",
            dependencies: [
                .product(name: "Nuke", package: "Nuke"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "HTTPTypesFoundation", package: "swift-http-types"),
            ],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .target(
            name: "PhotoDiaryKit",
            dependencies: ["PhotoDiaryCore"]
        ),
        .executableTarget(
            name: "PhotoDiaryIcon",
            dependencies: ["PhotoDiaryKit"]
        ),
        .testTarget(
            name: "PhotoDiaryCoreTests",
            dependencies: ["PhotoDiaryCore"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "PhotoDiaryKitTests",
            dependencies: ["PhotoDiaryKit"]
        ),
    ]
)
