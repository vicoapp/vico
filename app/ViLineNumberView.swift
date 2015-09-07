//
//  ViLineNumberView.swift
//  vico
//
//  Created by Antonio Salazar Cardozo on 6/28/15.
//
//

import Foundation

private struct DigitSettings {
    private let attributes: [String: AnyObject]
    private let digitView: ViLineNumberView
    
    init(digitView: ViLineNumberView, textAttributes: [String: AnyObject]) {
        self.digitView = digitView
        attributes = textAttributes
    }
    
    
    lazy var digitSize: NSSize = self.computeDigitSize()
    
    lazy var digits: [NSImage] = self.computeDigits()

    private func computeDigitSize() -> NSSize {
        return "8".sizeWithAttributes(attributes)
    }
    private mutating func computeDigits() -> [NSImage] {
        return (0..<10).map { digit -> NSImage in
            let digitString = String(digit)
            
            let digitImage = NSImage(size: digitSize)
            return digitView.drawString(digitString, intoImage: digitImage)
        }
    }
}

/**
 * A helper view that provides line number rendering for `ViRulerView`.
 */
class ViLineNumberView: ViRulerHelperView {
    static let defaultThickness: CGFloat = 22.0
    static let lineNumberMargin: CGFloat = 5.0
    
    private let lineNumberColor = NSColor(calibratedWhite: 0.42, alpha: 1.0)
    
    internal let backgroundColor: NSColor

    override internal var textView: ViTextView {
        set(newValue) {
            // Some nasty work here because the text view actually isn't
            // set before we deal with it here the first time, but this
            // property is non-optional so it will blow up if we try to
            // use didSet/willSet.

            let oldValue = _textView

            super.textView = newValue

            let notificationCenter = NSNotificationCenter.defaultCenter()
            if oldValue !== newValue {
                notificationCenter.removeObserver(self, name: ViCaretChangedNotification, object: oldValue)

                notificationCenter.addObserverForName(ViCaretChangedNotification, object: newValue, queue: nil) { [weak self] (_) in
                    if let view = self where view.relative {
                        view.needsDisplay = true
                    }
                }
            }
        }
        get {
            return _textView!
        }
    }
    
    private var relative: Bool = false {
        didSet {
            if relative != oldValue {
                updateViewFrame()
            }
        }
    }
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [NSObject : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if keyPath == "relativenumber" {
            self.relative = NSUserDefaults.standardUserDefaults().boolForKey(keyPath!)
        }
    }
    
    private var digitSettings: DigitSettings? = nil
    var textAttributes = [String: AnyObject]() {
        didSet {
            digitSettings = DigitSettings(digitView: self, textAttributes: textAttributes)
            
            updateViewFrame()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("ViLineNumberView does not support encoding/decoding.")
    }
    
    init(textView: ViTextView, backgroundColor: NSColor) {
        self.backgroundColor = backgroundColor

        super.init(frame: NSZeroRect)
        
        self.textView = textView
        resetTextAttributes()
        
        let userDefaults = NSUserDefaults.standardUserDefaults()
        
        userDefaults.addObserver(self, forKeyPath: "number", options: NSKeyValueObservingOptions(), context: nil)
        userDefaults.addObserver(self, forKeyPath:"relativenumber", options:NSKeyValueObservingOptions(), context: nil)
        userDefaults.addObserver(self, forKeyPath:"fontsize", options:NSKeyValueObservingOptions(), context: nil)
        
        self.relative = userDefaults.boolForKey("relativenumber")
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
        NSUserDefaults.standardUserDefaults().removeObserver(self, forKeyPath: "number")
        NSUserDefaults.standardUserDefaults().removeObserver(self, forKeyPath: "relativenumber")
        NSUserDefaults.standardUserDefaults().removeObserver(self, forKeyPath: "fontsize")
    }
    
    func resetTextAttributes() {
        textAttributes = [
            NSFontAttributeName: NSFont.labelFontOfSize(0.8 * ViThemeStore.font().pointSize),
            NSForegroundColorAttributeName: lineNumberColor
        ]
    }
    
    @objc override func textStorageDidChangeLines(notification: NSNotification) {
        let linesRemoved: Int = notification.userInfo?.typedGet("linesRemoved") ?? 0
        let linesAdded: Int = notification.userInfo?.typedGet("linesAdded") ?? 0
        
        if linesAdded - linesRemoved > 0 {
            updateViewFrame()
        }
    }
    
    override func setFrameSize(newSize: NSSize) {
        if newSize != frame.size {
            needsDisplay = true
        }
        
        super.setFrameSize(newSize)
    }
    
    // The logical line number of the given line with respect to the given
    // reference character index. This adjusts the line number to reflect
    // folds—lines that are inside a collapsed fold are considered to be
    // on the same logical line. This is used for relative line number
    // computation.
    private func logicalLineForLine(line: UInt, atCharacterIndex characterIndex: UInt) -> UInt {
        var logicalLine = line
        
        if characterIndex > 0 {
            if let textStorage = textView.textStorage as? ViTextStorage {
                textStorage.enumerateAttribute(
                    ViTextAttribute.Folded.rawValue,
                    inRange: NSMakeRange(0, Int(characterIndex)),
                    options: NSAttributedStringEnumerationOptions(),
                    usingBlock: { (maybeFold, foldedRange, _) -> Void in
                        if let _ = maybeFold {
                            var currentCharacterIndex: Int = NSMaxRange(textStorage.rangeOfLineAtLocation(UInt(foldedRange.location)))
                            while currentCharacterIndex < NSMaxRange(foldedRange) {
                                logicalLine -= 1
                                currentCharacterIndex = NSMaxRange(textStorage.rangeOfLineAtLocation(UInt(currentCharacterIndex + 1)))
                            }
                        }
                    }
                )
            }
        }
        
        return logicalLine
    }
    private func logicalLineForLine(line: UInt, atCharacterIndex: Int) -> UInt {
        return logicalLineForLine(line, atCharacterIndex: UInt(atCharacterIndex))
    }
    
    // The logical line for the current line in the TextView. If the current
    // line of the text view is inside a collapsed fold, this will correct for
    // that.
    private func textCurrentLogicalLine() -> UInt {
        return logicalLineForLine(textView.currentLine(), atCharacterIndex: textView.caret())
    }
    
    private var digitSize: NSSize {
        get {
            return digitSettings!.digitSize
        }
    }
    
    private var digits: [NSImage] {
        get {
            return digitSettings!.digits
        }
    }
    
    private var requiredThickness: CGFloat {
        get {
            guard let textStorage = textView.textStorage as? ViTextStorage else {
                return ViLineNumberView.defaultThickness
            }
            
            let digitWidth = digitSize.width
            
            var lineCount = textStorage.lineCount()
            var maxLineDigits = 0
            repeat {
                maxLineDigits++
                lineCount /= 10
            } while lineCount > 0
            
            return ceil(
                max(
                    ViLineNumberView.defaultThickness,
                    (digitWidth * CGFloat(maxLineDigits)) + (ViLineNumberView.lineNumberMargin * 2.0)
                )
            )
        }
    }
    
    private func updateViewFrame() {
        setFrameSize(intrinsicContentSize)
        invalidateIntrinsicContentSize()
    }
    
    override var intrinsicContentSize: NSSize {
        get {
            return NSSize(width: requiredThickness, height: textView.bounds.size.height)
        }
    }
    
    override var flipped: Bool {
        get {
            return true
        }
    }
    
    private func drawString(string: String, intoImage image: NSImage) -> NSImage {
        image.lockFocusFlipped(false)

        backgroundColor.set()
        NSRectFill(NSRect(x: 0, y: 0, width: digitSize.width, height: digitSize.height))
        string.drawAtPoint(NSPoint(x: 0.5, y: 0.5), withAttributes: textAttributes)

        image.unlockFocus()

        return image
    }
    
    private func drawLineNumber(number: Int, atPoint point: NSPoint) {
        var reverseDigits = [Int]()
        var remainingDigits = abs(number)
        repeat {
            reverseDigits.append(remainingDigits % 10)
            remainingDigits /= 10
        } while remainingDigits > 0
        
        let drawRect =
            NSRect(
                origin: point,
                size: digitSize
            ).offsetBy(
                dx: requiredThickness - digitSize.width,
                dy: 0
            )
        let _ = reverseDigits.reduce(drawRect, combine: { (drawRect, digit) in
            digits[digit].drawInRect(drawRect,
                fromRect: NSZeroRect,
                operation: NSCompositingOperation.CompositeSourceOver,
                fraction: 1.0,
                respectFlipped: true,
                hints: nil)
            
            return drawRect.offsetBy(dx: -digitSize.width, dy: 0)
        })
    }
    
    // Return a function that, given the current line number and current
    // character index, returns the current logical line number.
    //
    // Assumes the iterator will only be called once per logical line
    // (meaning the current line is not folded) and leverages this to
    // run logical line computations based on string attributes as little
    // as possible.
    private func logicalLineNumberIterator() -> (UInt, Int)->Int {
        var currentLogicalLine: UInt? = nil
        var textCurrentLogicalLine: UInt? = nil
            
        return { (currentLineNumber: UInt, currentCharacterIndex: Int) in
            // Lazy load or increment logical line, lazy load text-current logical line.
            if currentLogicalLine == nil {
                currentLogicalLine = self.logicalLineForLine(currentLineNumber, atCharacterIndex: currentCharacterIndex)
            } else {
                currentLogicalLine!++
            }
            if textCurrentLogicalLine == nil {
                textCurrentLogicalLine = self.textCurrentLogicalLine()
            }
            
            return Int(currentLogicalLine!) - Int(textCurrentLogicalLine!)
        }
    }
    
    override func drawRect(dirtyRect: NSRect) {
        let visibleRect = ((superview as? ViRulerView)?.scrollView?.contentView.bounds) ?? dirtyRect
        
        drawInRect(dirtyRect, visibleRect: visibleRect)
    }
    
    func drawInRect(rect: NSRect, visibleRect: NSRect) {
        if let layoutManager = textView.layoutManager,
            textContainer = textView.textContainer,
            textStorage = textView.textStorage as? ViTextStorage {
                let characterRange = layoutManager.characterRangeForGlyphRange(
                    layoutManager.glyphRangeForBoundingRect(visibleRect, inTextContainer:textContainer),
                    actualGlyphRange: nil
                )
                
                let firstCharacterIndex = UInt(characterRange.location)
                let lastCharacterIndex = UInt(NSMaxRange(characterRange))
                
                if firstCharacterIndex >= lastCharacterIndex {
                    // Draw line number "0" in empty documents.
                    let yFor0 = textView.textContainerInset.height - NSMinY(visibleRect)

                    drawLineNumber(0, atPoint: NSPoint(x: 0, y: yFor0 + 2.0))
                    return
                }
                
                let getNextLogicalLine = logicalLineNumberIterator()
                let textStorageString: NSString = textStorage.string()
                var currentCharacterIndex = Int(firstCharacterIndex)
                var currentLineNumber = textStorage.lineNumberAtLocation(UInt(currentCharacterIndex))
                repeat {
                    let currentGlyphIndex = layoutManager.glyphIndexForCharacterAtIndex(Int(currentCharacterIndex))
                    let lineRect = layoutManager.lineFragmentRectForGlyphAtIndex(currentGlyphIndex, effectiveRange: nil)

                    let attributesAtLineStart = textStorage.attributesAtIndex(UInt(currentCharacterIndex), effectiveRange: nil)
                    if attributesAtLineStart[ViFoldedAttributeName] == nil {
                        let yForLineNumber = textView.textContainerInset.height + NSMinY(lineRect) - NSMinY(visibleRect)
                       
                        let pointForLineNumber = NSPoint(
                            x: 0,
                            y: floor(yForLineNumber + (lineRect.height - digitSize.height) / 2.0 + 1.0)
                        )
                        
                        let numberToDraw = relative ? getNextLogicalLine(currentLineNumber, currentCharacterIndex) : Int(currentLineNumber)
                        drawLineNumber(numberToDraw, atPoint: pointForLineNumber)
                    }
                    
                    // Protect against an improbable (but possible due to preceding
                    // exceptions in undo manager) out-of-bounds reference here.
                    if currentCharacterIndex >= textStorage.length {
                        break
                    }
                    
                    textStorageString.getLineStart(nil, end: &currentCharacterIndex, contentsEnd: nil, forRange: NSMakeRange(Int(currentCharacterIndex), 0))
                    currentLineNumber++
                } while UInt(currentCharacterIndex) < lastCharacterIndex
        }
    }
    
    private var mouseDownY: CGFloat? = nil
    
    override func mouseDown(theEvent: NSEvent) {
        if let rulerView = self.superview as? NSRulerView {
            mouseDownY = textView.convertPoint(theEvent.locationInWindow, fromView: nil).y
            
            textView.rulerView(rulerView, selectFromPoint: NSPoint(x: 0, y: mouseDownY!), toPoint: NSPoint(x: 0, y: mouseDownY!))
        }
    }
    
    override func mouseDragged(theEvent: NSEvent) {
        if let rulerView = self.superview as? NSRulerView,
            startY = mouseDownY {
                let toY = textView.convertPoint(theEvent.locationInWindow, fromView: nil).y
                
                textView.rulerView(rulerView, selectFromPoint: NSPoint(x: 0, y: startY), toPoint: NSPoint(x: 0, y: toY))
        }
    }
}