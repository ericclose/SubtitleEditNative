// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SENativeApp",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "LibSENative",
            path: "Sources",
            exclude: ["MainApp.swift", "ContentView.swift", "SettingsView.swift", "AutomationDialogs.swift", "SpellCheckView.swift"]
        ),
        .executableTarget(
            name: "SENativeApp",
            dependencies: ["LibSENative"],
            path: "Sources",
            exclude: ["SubtitleBridge.swift", "SubtitleLine.swift", "WaveformRenderer.swift", "AppLogger.swift"]
        ),
        .executableTarget(
            name: "TestRunner",
            dependencies: ["LibSENative"],
            path: "TestRunner",
            sources: ["main.swift"]
        ),
        .testTarget(
            name: "SENativeAppTests",
            dependencies: ["LibSENative"],
            path: "Tests/SENativeAppTests"
        ),
    ]
)
