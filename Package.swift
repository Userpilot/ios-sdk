// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Userpilot",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Userpilot",
            targets: ["Userpilot"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/davidstump/SwiftPhoenixClient",
            exact: "5.3.5")
        ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Userpilot",
            dependencies: [
                .product(name: "SwiftPhoenixClient", package: "SwiftPhoenixClient")
            ],
            path: "Sources/Userpilot",
            resources: [
                .process("Resources/countries.json"),
                .process("Assets.xcassets"),
                .process("Experiences/Content/Flows/Carousel/CarouselExperienceViewController.xib"),
                .process("Experiences/Content/Survey/ListView/SurveyListViewController.xib")
            ]
        ),
        .testTarget(
            name: "UserpilotTests",
            dependencies: ["Userpilot"])
    ]
)
