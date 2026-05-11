// swift-tools-version: 6.0

/* Native */
import CompilerPluginSupport
import PackageDescription

// MARK: - Package

let package = Package(
    name: "Networking",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "Networking",
            targets: ["Networking"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/grantbrooksgoodman/app-subsystem",
            branch: "main"
        ),
        .package(
            url: "https://github.com/firebase/firebase-ios-sdk.git",
            .upToNextMajor(from: "11.4.0")
        ),
        .package(
            url: "https://github.com/swiftlang/swift-syntax",
            "600.0.0" ..< "700.0.0"
        ),
    ],
    targets: [
        .target(
            name: "Networking",
            dependencies: [
                .product(name: "AppSubsystem", package: "app-subsystem"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseDatabase", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk"),
                "NetworkingMacros",
            ],
            path: "Sources",
            exclude: ["Macros"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .macro(
            name: "NetworkingMacros",
            dependencies: [
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            ],
            path: "Sources/Macros"
        ),
    ]
)
