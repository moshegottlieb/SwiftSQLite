//
//  DatabaseError.swift
//  
//
//  Created by Moshe Gottlieb on 18.08.20.
//

import Foundation

/// Database error
public struct DatabaseError : Error, CustomStringConvertible {
    public var description: String {
        return "\(reason) (\(code)"
    }
    public let reason : String
    public let code : Int32
}
