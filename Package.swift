// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TeslaCamViewer",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(
            name: "TeslaCamViewer",
            targets: ["TeslaCamViewer"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "TeslaCamViewer",
            path: "Sources",
            exclude: [
                "TeslaCamViewer/Resources/"
            ],
            linkerSettings: [
                .linkedFramework("Cocoa"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AVKit")
            ]
        ),
    ]
)

