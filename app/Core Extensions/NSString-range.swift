//
//  NSString-range.swift
//  vico
//
//  Created by Antonio Salazar Cardozo on 6/27/15.
//
//

import Foundation

// Additions for string ranges.
extension NSString {
    func fullRange() -> NSRange {
        return NSMakeRange(0, length)
    }
}