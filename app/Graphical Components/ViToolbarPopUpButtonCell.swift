//
//  ViToolbarPopUpButtonCell.swift
//  vico
//
//  Created by Antonio Salazar Cardozo on 6/28/15.
//
//

import Foundation

class ViToolbarPopUpButtonCell: NSPopUpButtonCell {
    
    private var toolbarImage: NSImage?
    override var image: NSImage? {
        get {
            return toolbarImage
        }
        set {
            if let newImage = newValue {
                let flippedImage = NSImage(size: newImage.size)
                
                flippedImage.lockFocusFlipped(true)
                newImage.drawAtPoint(NSZeroPoint, fromRect: newImage.fullRect(), operation: NSCompositingOperation.CompositeSourceOver, fraction: 1.0)
                flippedImage.unlockFocus()
                
                toolbarImage = flippedImage
            } else {
                toolbarImage = nil
            }
        }
    }
}