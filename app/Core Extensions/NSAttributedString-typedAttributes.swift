//
//  NSAttributedString-typedAttributes.swift
//  vico
//
//  Created by Antonio Salazar Cardozo on 6/27/15.
//
//

import Foundation

// Extensions for providing typed access to NSAttributedString attributes without
// explicit casting in client code.
extension NSAttributedString {
    
    func typedAttribute<T>(attrName: String, atIndex index: Int, effectiveRange: NSRangePointer) -> T? {
        return attribute(attrName, atIndex: index, effectiveRange: effectiveRange) as? T
    }
    func typedAttribute(attrName: String, atIndex index: Int, effectiveRange: NSRangePointer) -> Bool? {
        let foundAttribute: NSNumber? = typedAttribute(attrName, atIndex: index, effectiveRange: effectiveRange)
        
        return foundAttribute?.boolValue
    }
    
    func typedAttribute<T>(attrName: String, atIndex index: Int, longestEffectiveRange: NSRangePointer, inRange rangeRestriction: NSRange) -> T? {
        return attribute(attrName, atIndex: index, longestEffectiveRange: longestEffectiveRange, inRange: rangeRestriction) as? T
    }
    func typedAttribute(attrName: String, atIndex index: Int, longestEffectiveRange: NSRangePointer, inRange rangeRestriction: NSRange) -> Bool? {
        let foundAttribute: NSNumber? =  typedAttribute(attrName, atIndex: index, longestEffectiveRange: longestEffectiveRange, inRange: rangeRestriction)
        
        return foundAttribute?.boolValue
    }
}