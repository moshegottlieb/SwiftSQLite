// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftSQLite",
    products: [
        /**
         SwiftSQLite library, using the built in SQLite, no SQLCipher support
         */
        .library(
            name: "SwiftSQLite",
            targets: ["SwiftSQLite"]),
        /**
         SwiftSQLCipher library, using the SQLCipher library, see additional license for details
         */
        .library(name: "SwiftSQLCipher",
            targets: ["SwiftSQLCipher"]),
        
        .executable(name: "SwiftSQLCipherTest",
                    targets: ["SwiftSQLCipherTest"]),
        
    ],
    dependencies: [
    ],
    targets: [
                
        .target(
            name: "SwiftSQLite",
            dependencies: []),
        
        .testTarget(
            name: "SwiftSQLiteTests",
            dependencies: ["SwiftSQLite"]),
        
        .target(
            name: "SwiftSQLCipher",
            dependencies: [],
            cSettings: SwiftSQLCipherCFlags,
            swiftSettings: [
                .define("SWIFT_SQLITE_CIPHER")
            ],
            linkerSettings: []
        ),
        
        .testTarget(
            name: "SwiftSQLCipherTests",
            dependencies: ["SwiftSQLCipher"],
            swiftSettings: [
                .define("SWIFT_SQLITE_CIPHER")
            ],
            linkerSettings: []
        ),
        
        .executableTarget(
            name: "SwiftSQLCipherTest",
            dependencies: [
                "SwiftSQLCipher"
            ]
        )
        
        
        
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

package.targets.append(
    .systemLibrary(
        name: "CSQLCipherLinux",
        providers: [
            .apt(["sqlcipher-dev"]),
            .yum(["sqlcipher-devel"])])
)


package.targets.first( where: { $0.name == "SwiftSQLite"})?.dependencies.append(.target(name: "SQLite3"))
package.targets.first( where: { $0.name == "SwiftSQLCipher"})?.dependencies.append(.target(name: "CSQLCipherLinux"))
package.targets.first( where: { $0.name == "SwiftSQLCipher"})?.linkerSettings?.append(.linkedFramework("-lsqlcipher"))


#else

package.targets.append(
    .target(
        name: "CSQLCipher",
        cSettings: SwiftSQLCipherCFlags)
)

package.targets.first( where: { $0.name == "SwiftSQLCipher"})?.dependencies.append(.target(name: "CSQLCipher"))

#endif


var SwiftSQLCipherCFlags: [CSetting] { [

    .define("SQLCIPHER_CRYPTO_CC"),
    .define("SQLITE_HAS_CODEC"),
    .define("NDEBUG"),
    
    .define("SQLITE_TEMP_STORE", to: "3"),
    // Derived from sqlite3 version 3.43.0
    .define("SQLITE_DEFAULT_MEMSTATUS", to: "0"),
    .define("SQLITE_DISABLE_PAGECACHE_OVERFLOW_STATS"),
    .define("SQLITE_DQS", to: "0"),
    .define("SQLITE_ENABLE_API_ARMOR", .when(configuration: .debug)),
    .define("SQLITE_ENABLE_COLUMN_METADATA"),
    .define("SQLITE_ENABLE_DBSTAT_VTAB"),
    .define("SQLITE_ENABLE_FTS3"),
    .define("SQLITE_ENABLE_FTS3_PARENTHESIS"),
    .define("SQLITE_ENABLE_FTS3_TOKENIZER"),
    .define("SQLITE_ENABLE_FTS4"),
    .define("SQLITE_ENABLE_FTS5"),
    .define("SQLITE_ENABLE_NULL_TRIM"),
    .define("SQLITE_ENABLE_RTREE"),
    .define("SQLITE_ENABLE_SESSION"),
    .define("SQLITE_ENABLE_STMTVTAB"),
    .define("SQLITE_ENABLE_UNKNOWN_SQL_FUNCTION"),
    .define("SQLITE_ENABLE_UNLOCK_NOTIFY"),
    .define("SQLITE_MAX_VARIABLE_NUMBER", to: "250000"),
    .define("SQLITE_LIKE_DOESNT_MATCH_BLOBS"),
    .define("SQLITE_OMIT_AUTHORIZATION"),
    .define("SQLITE_OMIT_COMPLETE"),
    .define("SQLITE_OMIT_DEPRECATED"),
    .define("SQLITE_OMIT_DESERIALIZE"),
    .define("SQLITE_OMIT_GET_TABLE"),
    .define("SQLITE_OMIT_LOAD_EXTENSION"),
    .define("SQLITE_OMIT_PROGRESS_CALLBACK"),
    .define("SQLITE_OMIT_SHARED_CACHE"),
    .define("SQLITE_OMIT_TCL_VARIABLE"),
    .define("SQLITE_OMIT_TRACE"),
    .define("SQLITE_SECURE_DELETE"),
    .define("SQLITE_THREADSAFE", to: "1"),
    .define("SQLITE_UNTESTABLE"),
    .define("SQLITE_USE_URI")
] }
