//
//  Database+Cipher.swift
//  SwiftSQLite
//
//  Created by Moshe Gottlieb on 04.12.24.
//

import Foundation

#if SWIFT_SQLITE_CIPHER
    #if os(Linux)
import CSQLCipherLinux
    #else
import CSQLCipher
    #endif
#else
import SQLite3
#endif

#if SWIFT_SQLITE_CIPHER


fileprivate extension Data {
    // https://stackoverflow.com/a/39075044/1610530
    var hexString : String {
        return reduce("") {$0 + String(format: "%02x", $1)}
    }
    // https://stackoverflow.com/a/64351862/1610530
    init?(hex: String) {
        guard hex.count.isMultiple(of: 2) else {
            return nil
        }
        // I added this for safety
        let hexCharacters = CharacterSet(charactersIn: "abcdefABCDEF0123456789")
        let inputCharacterSet = CharacterSet(charactersIn: hex)
        guard hexCharacters.isSuperset(of: inputCharacterSet) else {
            Database.logger?.log(message: "Trying to decode invalid hex string")
            return nil
        }
        let chars = hex.map { $0 }
        let bytes = stride(from: 0, to: chars.count, by: 2)
            .map { String(chars[$0]) + String(chars[$0 + 1]) }
            .compactMap { UInt8($0, radix: 16) }
        
        guard hex.count / bytes.count == 2 else { return nil }
        self.init(bytes)
    }
}

public extension Database {
    
    /// Set the encryption key (SQLCipher only)
    ///
    /// Call this **AFTER** opening a database to set the encryption key
    /// - Parameter key The key to use to encrypt / decrypt the database
    /// - throws Error if cannot encrypt
    func setKey(_ key:String) throws {
        try check(sqlite3_key(handle, key, Int32(key.count)))
        
    }
    
    /// Rekey the database, or remove the encryption
    ///
    /// You must call this method **AFTER** calling `setKey(:)`
    /// - Parameter key The new key, or nil to decrypt the database
    /// - throws Error
    func reKey(_ key:String) throws {
        try check(sqlite3_rekey(handle, key, Int32(key.count)))
    }
    /// A helper to decrypt the key.
    /// Same as `reKey(nil)`
    ///
    func removeKey() throws {
        try check(sqlite3_rekey(handle, nil, 0))
    }
    /// Retrieve the cipher salt
    ///
    /// - Returns: A 16 byte salt data used by the database, or nil if not encrypted
    var cipherSalt:Data? {
        get throws {
            let stmt = try statement(sql: "PRAGMA cipher_salt");
            guard try stmt.step() else {
                throw DatabaseError(reason: "Clould not step PRAGMA cipher_salt", code: -1)
            }
            guard let string_salt = stmt.string(column: 0) else {
                return nil
            }
            guard let data = Data(hex:string_salt) else {
                return nil
            }
            return data
        }
    }
    
    /// Set the cipher salt
    /// Use in conjunction with `setPlainTextHeaderSize(:)`
    ///
    /// - Parameter salt The 16 byte salt
    ///
    func setCipherSalt(_ salt:Data) throws {
        let stmt = try statement(sql: "PRAGMA cipher_salt = \"x'\(salt.hexString)'\"")
        try stmt.step()
    }
    
    /// Set this number of plain text bytes.
    /// You need to preserve the salt on your own if you do this.
    /// See https://www.zetetic.net/sqlcipher/sqlcipher-api/#cipher_plaintext_header_size
    func setPlainTextHeader(size:Int32) throws {
        // It's an int, you cannot inject to it.
        // Besides, it won't let me parameterize PRAGMAs
        let stmt = try statement(sql: "PRAGMA cipher_plaintext_header_size = \(size)")
        try stmt.step()
    }
    
    /// Forces writing the header
    ///
    func flushHeader() throws {
        let version = try get(version: .user)
        try set(version: version)
    }
    
        
#if !os(Linux)
    
    /// Open a shared WAL mode database
    /// This method generates a key, saves it along with the salt in the keychain, and sets a plain text header for your database
    /// - Parameter path Path to the database file
    /// - Parameter accessGroup Shared app group identifier
    func openSharedWalDatabase(path:String,accessGroup:String? = nil,identifier:String) throws {
        let is_new = !FileManager.default.fileExists(atPath: path)
        let salt_account = "\(identifier)_salt"
        let salt_kc_item = KeychainItem(service: Self.keyChainService, account: salt_account, accessGroup: accessGroup)
        let key_kc_item = KeychainItem(service: Self.keyChainService, account: identifier, accessGroup: accessGroup)
        let key : String
        if is_new {
            key = UUID().uuidString
            try key_kc_item.saveItem(key.data(using: .utf8)!)
        } else {
            key = try key_kc_item.readItem()
        }
        try open(path:path)
        try setKey(key)
        if is_new {
            guard let salt = try cipherSalt else {
                throw DatabaseError(reason: "Could not read salt from database", code: -1)
            }
            try salt_kc_item.saveItem(salt)
            try setPlainTextHeader(size: 32)
        } else {
            try setPlainTextHeader(size: 32)
            let salt = try salt_kc_item.readItemData()
            try setCipherSalt(salt)
        }
        try set(journalMode: .wal)
        if is_new {
            try flushHeader()
        }
    }
    
    /// Delete the credentials from the keychain
    /// Warning: you will not be able to open a database written with these credentials after this step
    ///
    /// - Parameter accessGroup Shared container identifier
    /// - Parameter identifier Your database identifier
    func deleteCredentials(accessGroup:String? = nil,identifier:String) throws {
        let salt_account = "\(identifier)_salt"
        let salt_kc_item = KeychainItem(service: Self.keyChainService, account: salt_account, accessGroup: accessGroup)
        let key_kc_item = KeychainItem(service: Self.keyChainService, account: identifier, accessGroup: accessGroup)
        try salt_kc_item.deleteItem()
        try key_kc_item.deleteItem()
    }
    
    
#endif
    
}



#endif
