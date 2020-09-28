// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LoftDataStructures_Bits",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "LoftDataStructures_Bits",
            targets: ["LoftDataStructures_Bits"]),
    ],
    dependencies: [],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "LoftDataStructures_Bits",
            dependencies: []),
        .testTarget(
            name: "LoftDataStructures_BitsTests",
            dependencies: ["LoftDataStructures_Bits"]),
    ]
)
