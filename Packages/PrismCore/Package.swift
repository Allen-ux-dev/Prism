// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PrismCore",
    platforms: [.iOS(.v15), .macOS(.v13)],
    products: [
        .library(name: "PrismDomain", targets: ["PrismDomain"]),
        .library(name: "PrismRepositories", targets: ["PrismRepositories"]),
        .library(name: "PrismEnvironment", targets: ["PrismEnvironment"]),
        .library(name: "PrismResolution", targets: ["PrismResolution"]),
        .library(name: "PrismTransactions", targets: ["PrismTransactions"]),
        .library(name: "PrismPrivilegedProtocol", targets: ["PrismPrivilegedProtocol"]),
        .library(name: "PrismDaemonCore", targets: ["PrismDaemonCore"]),
        .library(name: "PrismUIBridge", targets: ["PrismUIBridge"]),
        .executable(name: "prismd", targets: ["prismd"])
    ],
    targets: [
        .target(name: "PrismDomain"),
        .systemLibrary(name: "CZlib"),
        .target(name: "PrismRepositories", dependencies: ["PrismDomain", "CZlib"]),
        .target(name: "PrismEnvironment", dependencies: ["PrismDomain"]),
        .target(name: "PrismResolution", dependencies: ["PrismDomain", "PrismEnvironment"]),
        .target(name: "PrismTransactions", dependencies: ["PrismDomain", "PrismEnvironment", "PrismResolution"]),
        .target(name: "PrismPrivilegedProtocol", dependencies: ["PrismDomain", "PrismEnvironment", "PrismTransactions"]),
        .target(name: "PrismDaemonCore", dependencies: ["PrismDomain", "PrismEnvironment", "PrismResolution", "PrismTransactions", "PrismPrivilegedProtocol"]),
        .target(name: "PrismUIBridge", dependencies: ["PrismDomain", "PrismRepositories", "PrismEnvironment", "PrismResolution", "PrismTransactions", "PrismPrivilegedProtocol"]),
        .executableTarget(name: "prismd", dependencies: ["PrismDaemonCore", "PrismEnvironment"]),
        .testTarget(
            name: "PrismCoreTests",
            dependencies: [
                "PrismDomain", "PrismRepositories", "PrismEnvironment", "PrismResolution",
                "PrismTransactions", "PrismPrivilegedProtocol", "PrismDaemonCore", "PrismUIBridge"
            ],
            resources: [.process("Fixtures")]
        )
    ]
)
