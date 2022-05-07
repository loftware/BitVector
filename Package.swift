// swift-tools-version:5.5
import PackageDescription

let auxilliaryFiles = ["README.md", "LICENSE"]
let package = Package(
  name: "LoftDataStructures_BitVector",
  products: [
    .library(
      name: "LoftDataStructures_BitVector",
      targets: ["LoftDataStructures_BitVector"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/loftware/StandardLibraryProtocolChecks",
      from: "0.1.2"
    ),
  ],
  targets: [
    .target(
      name: "LoftDataStructures_BitVector",
      path: ".",
      exclude: auxilliaryFiles + ["Tests.swift"],
      sources: ["BitVector.swift"]),

    .testTarget(
      name: "Test",
      dependencies: [
        "LoftDataStructures_BitVector",
        .product(name: "LoftTest_StandardLibraryProtocolChecks",
                 package: "StandardLibraryProtocolChecks"),
      ],
      path: ".",
      exclude: auxilliaryFiles + ["BitVector.swift"],
      sources: ["Tests.swift"]
    ),
  ]
)
