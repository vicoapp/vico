//
//  Dictionary-typedAccess.swift
//  vico
//
//  Created by Antonio Salazar Cardozo on 6/28/15.
//
//

import Foundation

// Extensions for providing typed access to Dictionary keys without
// explicit casting in client code.
//
// Meant to ease interaction with things like NSNotification userInfo
// dictionaries.
extension Dictionary { // FIXME limit to AnyObject dictionary somehow...
    func typedGet<T>(key: Key) -> T? {
        return self[key] as? T
    }
    func typedGet(key: Key) -> Int? {
        let number: NSNumber? = typedGet(key)
        
        return number?.unsignedIntegerValue
    }
}