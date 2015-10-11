//
//  ViToolbarPopUpButtonCell.swift
//  vico
//
//  Created by Antonio Salazar Cardozo on 6/28/15.
//
//

import Foundation

/**
 * By default, NSPopUpButtonCells display the image and text of their
 * first menu item. We want to be able to give some pop up buttons an
 * icon independent of their menu items, which are all generated. This
 * class restores the ability of the popup button cell to have its own
 * image, and to draw that image in the popup button's area.
 */
class ViToolbarPopUpButtonCell: NSPopUpButtonCell {
    
    private var toolbarImage: NSImage?
    override var image: NSImage? {
        get {
            return toolbarImage
        }
        set {
            toolbarImage = newValue
        }
    }
    
    override func drawInteriorWithFrame(cellFrame: NSRect, inView controlView: NSView) {
        if let buttonImage = toolbarImage {
            let imageSize = buttonImage.size
            let imageOrigin =
            NSPoint(x: (cellFrame.size.width - imageSize.width) / 2,
                y: (cellFrame.size.height - imageSize.height) / 2)
            
            image?.drawInRect(NSRect(origin: imageOrigin, size: imageSize))
        }
    }
}