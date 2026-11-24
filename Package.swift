// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "WindowSwitcher",
    platforms: [.macOS(.v12)],
    targets: [
        // Pure logic (config, ordering, cycling): no AppKit, so it is unit-tested on its own.
        .target(name: "SwitcherCore"),
        .executableTarget(name: "WindowSwitcher", dependencies: ["SwitcherCore"]),
        .testTarget(name: "SwitcherCoreTests", dependencies: ["SwitcherCore"]),
    ]
)
