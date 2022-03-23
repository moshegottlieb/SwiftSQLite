// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftSQLite",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "SwiftSQLite",
            targets: ["SwiftSQLite"]),
    ],
    dependencies: [
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "SwiftSQLite",
            dependencies: []),
        .testTarget(
            name: "SwiftSQLiteTests",
            dependencies: ["SwiftSQLite"]),
    ]
)

#if os(Linux)
package.targets.append(
    .systemLibrary(
        name: "SQLite3",
        providers: [
            .apt(["libsqlite3-dev"]),
            .yum(["sqlite-devel"])])
)
package.targets[0].dependencies.append(.target(name: "SQLite3"))
#endif
