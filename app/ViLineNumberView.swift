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
class ViLineNumberView: NSView {
    static let defaultThickness: CGFloat = 22.0
    static let lineNumberMargin: CGFloat = 5.0
    static let rerenderingDocumentNotifications = [ViFoldsChangedNotification, ViFoldOpenedNotification, ViFoldClosedNotification]
    
    private let lineNumberColor = NSColor(calibratedWhite: 0.42, alpha: 1.0)
    
    internal let backgroundColor: NSColor
    private var _textView: ViTextView? = nil
    internal var textView: ViTextView {
        set(newValue) {
            let oldValue = _textView
            _textView = newValue

            let notificationCenter = NSNotificationCenter.defaultCenter()
            
            if oldValue?.document !== newValue.document {
                if let oldDocument = oldValue?.document {
                    for notification in ViLineNumberView.rerenderingDocumentNotifications {
                        notificationCenter.removeObserver(self, name: notification, object: oldDocument)
                    }
                }
                
                let needsDisplayHandler: (NSNotification!)->Void = { [unowned self] (_) in
                    self.needsDisplay = true
                }
                
                for notification in ViLineNumberView.rerenderingDocumentNotifications {
                    notificationCenter.addObserverForName(notification, object: newValue.document, queue: nil, usingBlock: needsDisplayHandler)
                }
            }

            if oldValue?.textStorage !== newValue.textStorage {
                if let oldTextStorage = oldValue?.textStorage {
                    notificationCenter.removeObserver(self, name: ViTextStorageChangedLinesNotification, object: oldTextStorage)
                }
                
                notificationCenter.addObserver(self, selector: "textStorageDidChangeLines:", name: ViTextStorageChangedLinesNotification, object: newValue.textStorage)
            }

            if oldValue !== newValue {
                notificationCenter.removeObserver(self, name: ViCaretChangedNotification, object: oldValue)

                notificationCenter.addObserverForName(ViCaretChangedNotification, object: newValue, queue: nil) { [unowned self] (_) in
                    if self.relative {
                        self.needsDisplay = true
                    }
                }
            }
        }
        get {
            return _textView!
        }
    }
    
    var relative: Bool = false {
        didSet {
            if relative != oldValue {
                updateViewFrame()
                
                self.superview?.needsDisplay = true
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
            // TODO needsDisplayInRect
            needsDisplay = true
        }
    }
    
    // FIXME Must we?
    // We override this because due to how we do drawing here, simply
    // saying the line numbers need display isn't enough; we need to
    // tell the ruler view it needs display as well.
    override var needsDisplay: Bool {
        didSet {
            superview?.needsDisplay = needsDisplay
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
    
    @objc func textStorageDidChangeLines(notification: NSNotification) {
        let linesRemoved: Int = notification.userInfo?.typedGet("linesRemoved") ?? 0
        let linesAdded: Int = notification.userInfo?.typedGet("linesAdded") ?? 0
        
        if linesAdded - linesRemoved > 0 {
            updateViewFrame()
            needsDisplay = true
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
            
            let lineCount = textStorage.lineCount()
            let maxLineDigits = log10(CGFloat(lineCount)) + 1
            
            return ceil(
                max(
                    ViLineNumberView.defaultThickness,
                    (digitWidth * maxLineDigits) + (ViLineNumberView.lineNumberMargin * 2.0)
                )
            )
        }
    }
    
    private func updateViewFrame() {
        setFrameSize(NSMakeSize(requiredThickness, textView.bounds.size.height))
    }
    
    private func drawString(string: String, intoImage image: NSImage) -> NSImage {
        image.lockFocusFlipped(false)

        backgroundColor.set()
        NSRectFill(NSRect(x: 0, y: 0, width: digitSize.width, height: digitSize.height))
        string.drawAtPoint(NSPoint(x: 0.5, y: 0.5), withAttributes: textAttributes)

        image.unlockFocus()

        return image
    }
    
    private func drawLineNumber(number: Int, inRect rect: NSRect) {
        var remainingDigits = abs(number)
        
        var drawRect = rect
        repeat {
            let remainder = remainingDigits % 10
            remainingDigits /= 10
            
            drawRect = drawRect.rectByOffsetting(dx: -digitSize.width, dy: 0)
            digits[remainder].drawInRect(drawRect,
                fromRect: NSZeroRect,
                operation: NSCompositingOperation.CompositeSourceOver,
                fraction: 1.0,
                respectFlipped: true,
                hints: nil)
        } while remainingDigits > 0
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
                    
                    let rectFor0 = NSRect(
                        x: bounds.width - ViLineNumberView.lineNumberMargin,
                        y: yFor0 + 2.0,
                        width: digitSize.width,
                        height: digitSize.height
                    )

                    drawLineNumber(0, inRect: rectFor0)
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
                        
                        let rectForLineNumber = NSRect(
                            x: bounds.width - ViLineNumberView.lineNumberMargin,
                            y: floor(yForLineNumber + (lineRect.height - digitSize.height) / 2.0 + 1.0),
                            width: digitSize.width,
                            height: digitSize.height
                        )
                        
                        let numberToDraw = relative ? getNextLogicalLine(currentLineNumber, currentCharacterIndex) : Int(currentLineNumber)
                        drawLineNumber(numberToDraw, inRect: rectForLineNumber)
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
}