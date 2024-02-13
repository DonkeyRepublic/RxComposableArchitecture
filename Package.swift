// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RxComposableArchitecture",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "RxComposableArchitecture",
            type: .static,
            targets: ["RxComposableArchitecture"]),
    ],
    dependencies: [
        .package(url: "https://github.com/DonkeyRepublic/swift-composable-architecture-refactor", exact: "0.56.1"),
        .package(url: "https://github.com/pointfreeco/swiftui-navigation", from: "1.0.0"),
        .package(url: "https://github.com/CombineCommunity/RxCombine.git", from: "2.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "RxComposableArchitecture",
            dependencies: [
                .product(name: "RxCombine", package: "RxCombine"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture-refactor")
            ]
        ),
        .testTarget(
            name: "RxComposableArchitectureTests",
            dependencies: ["RxComposableArchitecture"]
        ),
    ]
)
