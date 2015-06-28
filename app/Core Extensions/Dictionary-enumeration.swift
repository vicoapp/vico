//
//  Dictionary-enumeration.swift
//  vico
//
//  Created by Antonio Salazar Cardozo on 6/27/15.
//
//

import Foundation

extension Dictionary {
    func map<MappedKeyType: Hashable, MappedValueType>(mapper: (Key, Value) -> (MappedKeyType, MappedValueType?)) -> [MappedKeyType: MappedValueType] {
        var newMap = [MappedKeyType: MappedValueType]()
        for key in keys {
            if let value = self[key] {
                let (mappedKey, mappedValue) = mapper(key, value)
                newMap[mappedKey] = mappedValue
            }
        }
        
        return newMap
    }
}