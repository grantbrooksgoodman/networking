// swift-tools-version: 5.10

/* Native */
import PackageDescription

// MARK: - Package

let package = Package(
    name: "Networking",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "Networking",
            targets: ["Networking"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/grantbrooksgoodman/app-subsystem", branch: "main"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", .upToNextMajor(from: "11.4.0")),
//        .package(url: "https://github.com/nicklockwood/SwiftFormat", branch: "main"),
//        .package(url: "https://github.com/realm/SwiftLint", branch: "main"),
    ],
    targets: [
        .target(
            name: "Networking",
            dependencies: [
                .product(name: "AppSubsystem", package: "app-subsystem"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseDatabase", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk"),
            ],
            path: "Sources",
            plugins: [ /* .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLint") */ ]
        ),
    ]
)
