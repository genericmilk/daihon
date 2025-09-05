// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Daihon",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "DaihonApp", targets: ["DaihonApp"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "DaihonApp",
            path: "Sources/DaihonApp",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                // Allow using @main App in SwiftPM by compiling as a library and generating entry automatically.
                .unsafeFlags(["-parse-as-library"], .when(platforms: [.macOS]))
            ]
        )
    ]
)
