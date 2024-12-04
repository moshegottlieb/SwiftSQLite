//
//  main.swift
//  SwiftSQLite
//
//  Created by Moshe Gottlieb on 04.12.24.
//

import Foundation
import SwiftSQLCipher
import os

enum E : Error {
    case error(String)
}

do {
    if #available(macOS 11.0, *) {
        Database.logger = SQLLogger()
    }
    let filename = FileManager.default.temporaryDirectory.path.appending("/test.db")
    defer {
        do {
            try FileManager.default.removeItem(atPath: filename)
        } catch {
            print("Could not remove test.db: \(error)")
        }
    }
    let db = try Database(path: filename)
    let password = "TopSecret"
    try db.setKey(password)
    guard let salt = try db.cipherSalt else {
        throw E.error("Could not get salt")
    }
    try db.setPlainTextHeader(size: 32)
    try db.set(journalMode: .wal)
    try db.flushHeader()
    db.close()
    try db.open(path: filename)
    try db.setKey(password)
    try db.setPlainTextHeader(size: 32)
    try db.setCipherSalt(salt)
    try db.set(journalMode: .wal)
    let stmt = try db.statement(sql: "SELECT COUNT(*) FROM sqlite_master")
    try stmt.step()
    
} catch {
    print("Error: \(error)")
    exit(1)
}


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
