//
//  main.swift
//  SwiftSQLite
//
//  Created by Moshe Gottlieb on 04.12.24.
//

import Foundation
import SwiftSQLCipher

#if !os(Linux)
import os
#endif

enum E : Error {
    case error(String)
}

do {
    #if !os(Linux)
    if #available(macOS 11.0, *) {
        Database.logger = SQLLogger()
    }
    #endif
    let filename = FileManager.default.temporaryDirectory.path.appending("/test.db")
    let identifier = "my-db"
    var db:Database!
    
    defer {
        do {
            try FileManager.default.removeItem(atPath: filename)
            if let db = db {
                try db.deleteCredentials(identifier: identifier)
            }
        } catch {
            print("Could not remove test.db: \(error)")
        }
    }
    
    try db = Database()
    try db.openSharedWalDatabase(path: filename, identifier: identifier)
    try db.exec("CREATE TABLE test (a INT)")
    try db.exec("INSERT INTO test (a) VALUES (1), (2), (3)")
    db.close()
    
    try db.openSharedWalDatabase(path: filename, identifier: identifier)
    let stmt = try db.statement(sql: "SELECT SUM(a) FROM test")
    try stmt.step()
    if stmt.integer(column: 0) != 6 {
        throw E.error("Unexpected value in DB")
    }
} catch {
    print("Error: \(error)")
    exit(1)
}

#if !os(Linux)
@available(macOS 11.0, *)
struct SQLLogger : SwiftSQLCipher.Log {
    
    func log(prepare: String) {
        log.trace("[PREPARE] \(prepare)")
    }
    
    func log(error: String, code: Int) {
        log.error("[ERROR] \(error)")
    }
    
    func log(sql: String) {
        log.trace("[SQL] \(sql)")
    }
    
    func log(message: String) {
        log.trace("[INFO] \(message)")
    }
    
    private var log = Logger()
    
}
#endif
