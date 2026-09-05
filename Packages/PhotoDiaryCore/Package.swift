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
    ],
    products: [
        // Pure API + models + persistence. Headlessly testable, no UI
        // dependency.
        .library(name: "PhotoDiaryCore", targets: ["PhotoDiaryCore"]),
        // SwiftUI views + MapKit surface. Depends on Core.
        .library(name: "PhotoDiaryKit", targets: ["PhotoDiaryKit"]),
    ],
    targets: [
        .target(
            name: "PhotoDiaryCore",
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .target(
            name: "PhotoDiaryKit",
            dependencies: ["PhotoDiaryCore"],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PhotoDiaryCoreTests",
            dependencies: ["PhotoDiaryCore"]
        ),
        .testTarget(
            name: "PhotoDiaryKitTests",
            dependencies: ["PhotoDiaryKit"]
        ),
    ]
)
