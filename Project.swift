import ProjectDescription

let project = Project(
    name: "Tuist",
    packages: [.local(path: ".")],
    targets: [
        .target(
            name: "TuistApp",
            destinations: .iOS,
            product: .app,
            bundleId: "io.tuist.TuistApp",
            infoPlist: .extendingDefault(
                with: [
                    "UILaunchScreen": [
                        "UIColorName": "",
                        "UIImageName": "",
                    ]
                ]
            ),
            sources: ["App/Sources/**"],
            resources: ["App/Resources/**"],
            dependencies: [
                .package(product: "Tuist", type: .runtime)
            ]
        ),
        .target(
            name: "TuistAppTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "io.tuist.TuistAppTests",
            infoPlist: .default,
            sources: ["App/Tests/**"],
            resources: [],
            dependencies: [.target(name: "TuistApp")]
        ),
    ]
)
