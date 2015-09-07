//
//  ViFoldMarginView.swift
//  vico
//
//  Created by Antonio Salazar Cardozo on 9/5/15.
//
//

import Foundation

/**
 * A view that presents fold margin indicators in a ViRulerView.
 *
 * A given fold indicator can be clicked to close or open that fold.
 */
class ViFoldMarginView: ViRulerHelperView {
    static let foldMarginWidth = CGFloat(10)
    
    required init?(coder: NSCoder) {
        fatalError("ViLineNumberView does not support encoding/decoding.")
    }
    
    init(textView: ViTextView) {        
        super.init(frame: NSZeroRect)
        
        self.textView = textView
        
        let userDefaults = NSUserDefaults.standardUserDefaults()
        userDefaults.addObserver(self, forKeyPath: "fontsize", options: NSKeyValueObservingOptions(), context: nil)
    }
    
    @objc override func textStorageDidChangeLines(notification: NSNotification) {
        let linesRemoved: Int = notification.userInfo?.typedGet("linesRemoved") ?? 0
        let linesAdded: Int = notification.userInfo?.typedGet("linesAdded") ?? 0
        
        if linesAdded - linesRemoved > 0 {
            updateViewFrame()
            needsDisplay = true
        }
    }
    
    func updateViewFrame() {
        self.setFrameSize(intrinsicContentSize)
        invalidateIntrinsicContentSize()
    }
    
    override var intrinsicContentSize: NSSize {
        get {
            return NSSize(width: ViFoldMarginView.foldMarginWidth, height: self.textView.bounds.size.height)
        }
    }
    
    override var flipped: Bool {
        get {
            return true
        }
    }

    override func drawRect(dirtyRect: NSRect) {
        let visibleRect =
            ((superview as? ViRulerView)?.scrollView?.contentView.bounds) ?? dirtyRect
        
        drawInRect(dirtyRect, visibleRect: visibleRect)
    }
    
    func drawInRect(rect: NSRect, visibleRect: NSRect) {
        if let layoutManager = textView.layoutManager,
            textContainer = textView.textContainer,
            textStorage = textView.textStorage as? ViTextStorage,
            document = textView.document {
                let yInset = textView.textContainerInset.height
                let characterRange = layoutManager.characterRangeForGlyphRange(
                    layoutManager.glyphRangeForBoundingRect(visibleRect, inTextContainer:textContainer),
                    actualGlyphRange: nil
                )
                
                let lastCharacterIndex = NSMaxRange(characterRange)
                let textStorageString: NSString = textStorage.string()
                
                var currentCharacterIndex = characterRange.location
                repeat {
                    let glyphIndex = layoutManager.glyphIndexForCharacterAtIndex(currentCharacterIndex)
                    let lineFragmentRect = layoutManager.lineFragmentRectForGlyphAtIndex(glyphIndex, effectiveRange: nil)

                    if let fold = document.foldAtLocation(UInt(currentCharacterIndex)) {
                        // Note that the ruler view is only as tall as the visible
                        // portion. Need to compensate for the clipview's coordinates.
                        let foldStartY = yInset + NSMinY(lineFragmentRect) - NSMinY(visibleRect)

                        let drawRect =
                            NSRect(
                                x: 0,
                                y: foldStartY,
                                width: ViFoldMarginView.foldMarginWidth,
                                height: lineFragmentRect.height
                            )

                        let foldDepthAlpha = 0.1 * Double(fold.depth + 1)
                        let foldColor = NSColor(calibratedWhite: CGFloat(0.42), alpha: CGFloat(foldDepthAlpha))
                        foldColor.set()
                        NSRectFillUsingOperation(drawRect, NSCompositingOperation.CompositeSourceOver)
                    }
                
                    // Protect against an improbable (but possible due to
                    // preceding exceptions in undo manager) out-of-bounds
                    // reference here.
                    if currentCharacterIndex >= textStorage.length {
                        break
                    }
                
                    textStorageString.getLineStart(nil,
                        end: &currentCharacterIndex,
                        contentsEnd: nil,
                        forRange: NSRange(location: Int(currentCharacterIndex),
                        length: 0)
                    )
                } while currentCharacterIndex < lastCharacterIndex
        }
    }
    
    override func mouseUp(theEvent: NSEvent) {
        let upPoint = textView.convertPoint(theEvent.locationInWindow, fromView:nil)
        
        self.needsDisplay = true
        textView.toggleFoldAtPoint(NSPoint(x: 0, y: upPoint.y))
    }
}