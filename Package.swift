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
            targets: ["RxComposableArchitecture"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", exact: "0.32.0"),
        .package(url: "https://github.com/pointfreeco/combine-schedulers", exact: "0.7.2"), // https://forums.swift.org/t/cannot-find-nsrecursivelock-in-scope/59912
        .package(url: "https://github.com/CombineCommunity/RxCombine.git", from: "2.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "RxComposableArchitecture",
            dependencies: [
                .product(name: "RxCombine", package: "RxCombine"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        ),
        .testTarget(
            name: "RxComposableArchitectureTests",
            dependencies: ["RxComposableArchitecture"]
        ),
    ]
)
