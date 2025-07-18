// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SystemExtensionKit",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "SystemExtensionKit",
            targets: ["SystemExtensionKit"]
        ),
    ],
    dependencies: [],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "SystemExtensionKit",
            dependencies: [],
            path: "Sources",
            resources: [.copy("Resources/PrivacyInfo.xcprivacy")],
            swiftSettings: [.define("INCLUDE_SYSTEM_EXTENSIONS_KIT")],
            linkerSettings: [
                .linkedFramework("SystemExtensions", .when(platforms: [.macOS])),
            ]
        ),
        .testTarget(
            name: "SystemExtensionKitTests",
            dependencies: ["SystemExtensionKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
