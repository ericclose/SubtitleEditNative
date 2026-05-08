// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacOSVideoProto",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MacOSVideoProto", targets: ["MacOSVideoProto"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MacOSVideoProto",
            dependencies: [],
            path: "Sources/MacOSVideoProto"
        ),
        .testTarget(
            name: "MacOSVideoProtoTests",
            dependencies: ["MacOSVideoProto"],
            path: "Tests/MacOSVideoProtoTests"
        )
    ]
)
