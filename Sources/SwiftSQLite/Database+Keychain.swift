//
//  Database+Keychain.swift
//  SwiftSQLite
//
//  Created by Moshe Gottlieb on 03.12.24.
//

import Foundation

#if !os(Linux)

#if SWIFT_SQLITE_CIPHER

public extension Database {
    
    internal static var keyChainService : String {
        return "com.sharkfood.swiftsqlite.keychain.service"
    }
    
    func saveToKeyChain(account:String,key:String?,accessGroup:String?=nil) throws {
        deleteFromKeyChain(account: account,accessGroup: accessGroup)
        guard let newValue = key else { return }
        let keychain = KeychainItem(service: Self.keyChainService, account: account, accessGroup: accessGroup)
        try? keychain.saveItem(newValue)
    }
    
    func deleteFromKeyChain(account:String,accessGroup:String? = nil) {
        let old_keychain = KeychainItem(service: Self.keyChainService, account: account, accessGroup: accessGroup)
        try? old_keychain.deleteItem() // remove old data
    }
    
    func readFromKeyChain(account:String,accessGroup:String?=nil) throws -> String? {
        let keychain = KeychainItem(service: Self.keyChainService, account: account, accessGroup: accessGroup)
        return try? keychain.readItem()
    }
    
}




internal struct KeychainItem {
    // MARK: Types
    
    public enum KeychainError: Error {
        case noPassword
        case generalError
    }
    
    // MARK: Properties
    
    let service: String
    
    private(set) var account: String
    
    let accessGroup: String?
    
    // MARK: Intialization
    
    public init(service: String, account: String, accessGroup: String? = nil) {
        self.service = service
        self.account = account
        self.accessGroup = accessGroup
    }
    
    // MARK: Keychain access
    
    
    public func readItemData() throws -> Data {
        /*
         Build a query to find the item that matches the service, account and
         access group.
         */
        var query = KeychainItem.keychainQuery(withService: service, account: account, accessGroup: accessGroup)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnAttributes as String] = kCFBooleanTrue
        query[kSecReturnData as String] = kCFBooleanTrue
        
        // Try to fetch the existing keychain item that matches the query.
        var queryResult: AnyObject?
        let status = withUnsafeMutablePointer(to: &queryResult) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }
        
        // Check the return status and throw an error if appropriate.
        guard status == noErr else { throw KeychainError.noPassword }
        
        // Parse the password string from the query result.
        guard let existingItem = queryResult as? [String: AnyObject],
            let passwordData = existingItem[kSecValueData as String] as? Data
            else {
            throw KeychainError.noPassword
        }
        
        return passwordData
    }
    
    public func readItem() throws -> String {
        guard let password = String(data: try readItemData(), encoding: String.Encoding.utf8) else {
            throw KeychainError.noPassword
        }
        return password
    }
    
    public func saveItem(_ data: Data) throws {
        
        do {
            // Check for an existing item in the keychain.
            try _ = readItem()
            
            // Update the existing item with the new password.
            var attributesToUpdate = [String: AnyObject]()
            attributesToUpdate[kSecValueData as String] = data as AnyObject?
            let query = KeychainItem.keychainQuery(withService: service, account: account, accessGroup: accessGroup)
            let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
            
            // Throw an error if an unexpected status was returned.
            guard status == noErr else { throw KeychainError.generalError }
        } catch KeychainError.noPassword {
            /*
             No password was found in the keychain. Create a dictionary to save
             as a new keychain item.
             */
            var newItem = KeychainItem.keychainQuery(withService: service, account: account, accessGroup: accessGroup)
            newItem[kSecValueData as String] = data as AnyObject?
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as AnyObject?
            // Add a the new item to the keychain.
            let status = SecItemAdd(newItem as CFDictionary, nil)
            
            // Throw an error if an unexpected status was returned.
            guard status == noErr else { throw KeychainError.generalError }
        }
    }
    
    public func saveItem(_ password: String) throws {
        // Encode the password into an Data object.
        let data = password.data(using: String.Encoding.utf8)!
        try saveItem(data)
    }
        
    
    public func deleteItem() throws {
        // Delete the existing item from the keychain.
        let query = KeychainItem.keychainQuery(withService: service, account: account, accessGroup: accessGroup)
        let status = SecItemDelete(query as CFDictionary)
        
        // Throw an error if an unexpected status was returned.
        guard status == noErr || status == errSecItemNotFound else { throw KeychainError.generalError }
    }
    
    // MARK: Convenience
    
    private static func keychainQuery(withService service: String, account: String? = nil, accessGroup: String? = nil) -> [String: AnyObject] {
        var query = [String: AnyObject]()
        query[kSecClass as String] = kSecClassGenericPassword
        query[kSecAttrService as String] = service as AnyObject?
        
        if let account = account {
            query[kSecAttrAccount as String] = account as AnyObject?
        }
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup as AnyObject?
        }
        return query
    }
}

#endif

#endif
