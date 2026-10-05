// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "Coldkey", platforms: [.macOS(.v13)], products: [.executable(name: "Coldkey", targets: ["Coldkey"])], targets: [.executableTarget(name: "Coldkey"), .testTarget(name: "ColdkeyTests", dependencies: ["Coldkey"])])
