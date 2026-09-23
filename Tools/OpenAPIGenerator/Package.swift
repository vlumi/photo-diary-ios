// swift-tools-version:6.2
// Holds the OpenAPI generator for `make generate-client`, so it never
// enters the app's own dependency graph or build.
import PackageDescription

let package = Package(
    name: "OpenAPIGenerator",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-generator", exact: "1.13.1")
    ]
)
