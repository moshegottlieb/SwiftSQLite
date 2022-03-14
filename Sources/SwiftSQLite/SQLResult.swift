//
//  Result.swift
//  
//
//  Created by Moshe Gottlieb on 10.03.22.
//

import Foundation
import SQLite3

///
/// Result of a custom SQL function
/// @see Database+Function
///
public class SQLResult {
    
    public typealias SQLType = SQLValue.SQLType
    
    public init(){
        stringValue = nil
        dataValue = nil
        doubleValue = nil
        intValue = nil
        resultType = .Null
    }
    
    public init(_ value:Int?){
        stringValue = nil
        dataValue = nil
        doubleValue = nil
        if let value = value {
            resultType = .Int
            intValue = value
        } else {
            resultType = .Null
            intValue = nil
        }
    }
    public init(_ value:String?){
        intValue = nil
        dataValue = nil
        doubleValue = nil
        if let value = value {
            resultType = .String
            stringValue = value
        } else {
            resultType = .Null
            stringValue = nil
        }
    }
    
    public init(_ value:Data?){
        intValue = nil
        stringValue = nil
        doubleValue = nil
        if let value = value {
            resultType = .Data
            dataValue = value
        } else {
            resultType = .Null
            dataValue = nil
        }
    }
    
    public init(_ value:Double?){
        intValue = nil
        stringValue = nil
        dataValue = nil
        if let value = value {
            resultType = .Double
            doubleValue = value
        } else {
            resultType = .Null
            doubleValue = nil
        }
    }
    
    internal func apply(context:OpaquePointer){
        switch resultType {
        case .Int:
            sqlite3_result_int64(context, Int64(intValue!))
        case .Double:
            sqlite3_result_double(context, doubleValue!)
        case .Null:
            sqlite3_result_null(context)
        case .String:
            sqlite3_result_text(context, stringValue!.cString(using: .utf8), -1, SQLITE_TRANSIENT)
        case .Data:
            dataValue!.withUnsafeBytes { (ptr:UnsafeRawBufferPointer) in
                sqlite3_result_blob(context, ptr.baseAddress, Int32(dataValue!.count), SQLITE_TRANSIENT)
            }
        }
    }
    
    internal static func allocate(context:OpaquePointer) -> SQLResult{
        // what is the pointer size/
        let size = MemoryLayout<SQLResult>.size
        // ask SQLite to store a pointer size for later access
        let ptr = sqlite3_aggregate_context(context, Int32(size))
        // First call? if so, value would be zero
        if ptr?.load(as: Int.self) == 0 {
            // Create a standard result
            let result = SQLResult()
            // Get the address of result object (actual pointer numeric value)
            let addr = unsafeBitCast(result, to: Int.self)
            // Retain it, so it wouldn't be deleted when it falls out of scope in the next curly braces
            _ = Unmanaged<SQLResult>.passRetained(result) // Retain
            // Copy the address to the pointer allocated by sqlite
            ptr!.storeBytes(of: addr, as: Int.self)
        }
        // Return the pointer as a Result object
        let ret = ptr!.assumingMemoryBound(to: SQLResult.self).pointee
        return ret
    }
    
    internal static func final(context:OpaquePointer) -> SQLResult{
        // Retrieve the pointer, size no longer matters, as the result is already allocated, that's how the sqlite API works
        let ptr = sqlite3_aggregate_context(context, Int32(0))
        // Return the pointer as a Result object
        let ret = ptr!.assumingMemoryBound(to: SQLResult.self).pointee
        return ret
    }
    
    internal static func deallocate(context:OpaquePointer){
        let ptr = sqlite3_aggregate_context(context, Int32(0))
        // Get the pointer as a Result object
        let result = ptr!.assumingMemoryBound(to: SQLResult.self).pointee
        // Create an unmanged object of this result
        let unmngd:Unmanaged<SQLResult> = Unmanaged<SQLResult>.passUnretained(result)
        // Explicitly release it, balancing the retian from `allocate()`
        // the result should be destructed when it falls out of scope
        unmngd.release()
    }
    
    public var resultType : SQLType
    public var intValue : Int? {
        didSet {
            if let _ = intValue {
                resultType = .Int
            } else {
                resultType = .Null
            }
        }
    }
    
    public var stringValue : String? {
        didSet {
            if let _ = stringValue {
                resultType = .String
            } else {
                resultType = .Null
            }
        }
    }
    public var dataValue: Data? {
        didSet {
            if let _ = dataValue {
                resultType = .Data
            } else {
                resultType = .Null
            }
        }
    }
    public var doubleValue : Double? {
        didSet {
            if let _ = doubleValue {
                resultType = .Double
            } else {
                resultType = .Null
            }
        }
    }
}
