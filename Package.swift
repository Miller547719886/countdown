// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Jiedian",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Jiedian", targets: ["JiedianApp"]),
        .library(name: "JiedianCore", targets: ["JiedianCore"])
    ],
    targets: [
        .target(name: "JiedianCore"),
        .executableTarget(
            name: "JiedianApp",
            dependencies: ["JiedianCore"],
            resources: [.process("Resources")],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Carbon"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("UserNotifications")
            ]
        ),
        .executableTarget(name: "JiedianChecks", dependencies: ["JiedianCore"])
    ]
)
