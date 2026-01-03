// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AIRoadTripTours",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AIRoadTripToursCore",
            targets: ["AIRoadTripToursCore"]
        ),
        .library(
            name: "AIRoadTripToursServices",
            targets: ["AIRoadTripToursServices"]
        ),
        .library(
            name: "AIRoadTripToursApp",
            targets: ["AIRoadTripToursApp"]
        ),
        .executable(
            name: "AIRoadTripToursDemo",
            targets: ["AIRoadTripToursDemo"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-openapi-generator.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "AIRoadTripToursDemo",
            dependencies: [
                "AIRoadTripToursCore",
                .product(name: "Logging", package: "swift-log"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "AIRoadTripToursApp",
            dependencies: [
                "AIRoadTripToursCore",
                "AIRoadTripToursServices",
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "AIRoadTripToursCore",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "AIRoadTripToursServices",
            dependencies: [
                "AIRoadTripToursCore",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "AIRoadTripToursCoreTests",
            dependencies: ["AIRoadTripToursCore"]
        ),
        .testTarget(
            name: "AIRoadTripToursServicesTests",
            dependencies: [
                "AIRoadTripToursCore",
                "AIRoadTripToursServices"
            ]
        ),
    ]
)
