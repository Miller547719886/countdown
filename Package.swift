// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Jiedian",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Jiedian", targets: ["JiedianApp"]),
        .library(name: "JiedianCore", targets: ["JiedianCore"])
    ],
    dependencies: [
        .package(path: "Vendor/Tyme4Swift")
    ],
    targets: [
        .target(
            name: "JiedianCore",
            dependencies: [
                .product(name: "Tyme4Swift", package: "Tyme4Swift")
            ],
            resources: [
                .copy("Resources/Holidays"),
                .copy("Resources/ThirdParty")
            ]
        ),
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
                .linkedFramework("UserNotifications"),
                .linkedFramework("EventKit")
            ]
        ),
        .executableTarget(name: "JiedianChecks", dependencies: ["JiedianCore"])
    ]
)
