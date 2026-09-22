// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "StudyBuddy",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "StudyBuddy",
            path: "Sources/StudyBuddy"
        )
    ]
)
