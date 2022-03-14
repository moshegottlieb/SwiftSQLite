//
//  Value.swift
//  
//
//  Created by Moshe Gottlieb on 09.03.22.
//

import Foundation
import SQLite3

/// SQLValue wrapper
public class SQLValue {
    internal init(_ value:OpaquePointer?){
        self.value = value
    }
    
    public var intValue : Int {
        guard let value = value else {
            return 0
        }
        return Int(sqlite3_value_int64(value))
    }
    
    public var stringValue : String? {
        guard let value = value else {
            return nil
        }
        if let text = sqlite3_value_text(value) {
            return String(cString: text)
        }
        return nil
    }
    
    public var doubleValue : Double {
        guard let value = value else {
            return 0
        }
        return sqlite3_value_double(value)
    }
    
    public var dataValue : Data? {
        guard let value = value else {
            return nil
        }
        if let blob = sqlite3_value_blob(value) {
            let len = sqlite3_value_bytes(value)
            return Data(bytes: blob, count: Int(len))
        }
        return nil
    }
    
    public var dateValue : Date {
        return Date(epoch: Int64(intValue))
    }

    public enum SQLType {
        case Int
        case Double
        case Null
        case String
        case Data
        
        internal static func from(sqlType:Int32) -> SQLType {
            switch sqlType {
            case SQLITE_INTEGER:
                return Int
            case SQLITE_FLOAT:
                return Double
            case SQLITE_BLOB:
                return Data
            case SQLITE_NULL:
                fallthrough
            default:
                return Null
            }
        }
        
        
    }
    
    var defaultType : SQLType {
        return SQLType.from(sqlType: sqlite3_value_type(value))
    }
    
    private let value : OpaquePointer?
}
