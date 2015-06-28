//
//  ViTextIconCell.swift
//  vico
//
//  Created by Antonio Salazar Cardozo on 6/28/15.
//
//

import Foundation

// Helper that can be handed an image and will hold both it and a flipped
// version of it.
private struct FlippedImageHelper {
    let image: NSImage
    let flippedImage: NSImage
    
    init(image: NSImage) {
        self.image = image
        self.flippedImage = {
            let flippedImage = NSImage(size: image.size)
        
            flippedImage.lockFocusFlipped(true)
            image.drawAtPoint(NSZeroPoint, fromRect: NSMakeRect(0, 0, image.size.width, image.size.height), operation: NSCompositingOperation.CompositeSourceOver, fraction: 1.0)
            flippedImage.unlockFocus()
            
            return flippedImage
        }()
    }
}

class ViTextIconCell: MHTextIconCell {
    private var iconImageHelper: FlippedImageHelper?
    
    override var image: NSImage? {
        get {
            NSLog("Getting image based on \(controlView?.flipped)")
            if let control = controlView where control.flipped {
                return iconImageHelper?.flippedImage
            } else {
                return iconImageHelper?.image
            }
        }
        set {
            if let baseImage = newValue {
                iconImageHelper = FlippedImageHelper(image: baseImage)
            } else {
                iconImageHelper = nil
            }
        }
    }
}