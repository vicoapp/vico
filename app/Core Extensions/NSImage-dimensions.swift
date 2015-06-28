//
//  NSImage-dimensions.swift
//  vico
//
//  Created by Antonio Salazar Cardozo on 6/28/15.
//
//

import Foundation

// Dimension helpers for NSImage.
extension NSImage {
    
    /**
     * Return a zero-origin `NSRect` with this image's dimensions.
     */
    func fullRect() -> NSRect {
        return NSMakeRect(0, 0, size.width, size.height)
    }
}