// swift-tools-version: 5.9
import PackageDescription
import Foundation

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let native = "\(root)/.build/native"
let package = Package(
    name: "DayScribe",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "DayScribe", targets: ["DayScribe"])],
    targets: [
        .target(name: "WhisperBridge", cxxSettings: [
            .unsafeFlags(["-I\(root)/.vendor/whisper.cpp/include", "-I\(root)/.vendor/whisper.cpp/ggml/include"])
        ], linkerSettings: [
            .unsafeFlags(["-L\(native)/src", "-L\(native)/ggml/src", "-L\(native)/ggml/src/ggml-cpu", "-L\(native)/ggml/src/ggml-metal", "-L\(native)/ggml/src/ggml-blas"]),
            .linkedLibrary("whisper"), .linkedLibrary("ggml"), .linkedLibrary("ggml-base"),
            .linkedLibrary("ggml-cpu"), .linkedLibrary("ggml-metal"), .linkedLibrary("ggml-blas"),
            .linkedFramework("Accelerate"), .linkedFramework("Metal"), .linkedFramework("Foundation")
        ]),
        .target(name: "DayScribeCore", dependencies: ["WhisperBridge"]),
        .executableTarget(name: "DayScribe", dependencies: ["DayScribeCore"], linkerSettings: [
            .linkedFramework("AppKit"), .linkedFramework("Carbon"),
            .linkedFramework("AVFoundation"), .linkedFramework("UserNotifications"),
            .linkedFramework("ServiceManagement")
        ]),
        .testTarget(name: "DayScribeCoreTests", dependencies: ["DayScribeCore"])
    ],
    cxxLanguageStandard: .cxx17
)
