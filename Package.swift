// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MTTransitions",
    platforms: [
        .iOS(.v14),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "MTTransitions",
            targets: ["MTTransitions"]),
    ],
    dependencies: [
       .package(
            name: "MetalPetal",
            url: "https://github.com/MetalPetal/MetalPetal",
            from: "1.24.0"
       )
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "MTTransitions",
            dependencies: [
                "MetalPetal"
            ],
            path: "Source",
            resources: [
                .process("Assets.bundle")
            ],
            cSettings: [
                .headerSearchPath("../MetalPetal/Sources/MetalPetalObjectiveC/include")
            ],
            cxxSettings: [
                .headerSearchPath("../MetalPetal/Sources/MetalPetalObjectiveC/include")
            ]
        ),
    ]
)
