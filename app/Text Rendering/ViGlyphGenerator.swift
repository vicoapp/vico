import Foundation
import Cocoa

/**
 * This glyph generator does custom work for Vico. Its main use currently is to
 * produce null glyphs for code that has been folded. Code that has been folded
 * is marked with the `ViFoldedAttributeName` attribute set to `true`.
 *
 * This is pulled largely from WWDC 2010 Session 114: Advanced Cocoa Text Tips
 * and Tricks, as linked to on [cocoa-dev](http://lists.apple.com/archives/cocoa-dev/2012/Nov/msg00378.html).
 */
class ViGlyphGenerator: NSGlyphGenerator, NSGlyphStorage {
    // The original requester of glyph generation.
    internal var originalStorage: NSGlyphStorage?
    
    override func generateGlyphsForGlyphStorage(destinationStorage: NSGlyphStorage, desiredNumberOfCharacters numberOfCharacters: Int, glyphIndex: UnsafeMutablePointer<Int>, characterIndex: UnsafeMutablePointer<Int>) {
        // Store the original destination (likely a ViLayoutManager).
        originalStorage = destinationStorage
        
        // Call the usual glyph generator to generate the glyphs, but tell it the requesting
        // NSGlyphStorage object is us, so that we can intercept the changes and do whatever
        // we need to do there.
        NSGlyphGenerator.sharedGlyphGenerator().generateGlyphsForGlyphStorage(self, desiredNumberOfCharacters: numberOfCharacters, glyphIndex: glyphIndex, characterIndex: characterIndex)
        
        originalStorage = nil
    }
    
    @objc func insertGlyphs(glyphs: UnsafePointer<NSGlyph>, length incomingGlyphLength: Int, forStartingGlyphAtIndex glyphIndex: Int, characterIndex: Int) {
        var effectiveRange: NSRange = NSMakeRange(0, 0)
        let foundAttribute =
            self.attributedString().attribute(ViFoldedAttributeName, atIndex: characterIndex, longestEffectiveRange: &effectiveRange, inRange:NSMakeRange(0, characterIndex + incomingGlyphLength))
        
        if let foldedAttribute: NSNumber = foundAttribute as? NSNumber where
            foldedAttribute.boolValue {
            var allGlyphs: [NSGlyph] = [],
                controlGlyph = NSGlyph(NSControlGlyph),
                nullGlyph = NSGlyph(NSNullGlyph)
                
            if effectiveRange.location == characterIndex {
                allGlyphs = [controlGlyph]
            } else {
                allGlyphs = [nullGlyph]
            }
                
            for _ in 1..<incomingGlyphLength {
                allGlyphs.append(nullGlyph)
            }
                
            originalStorage?.insertGlyphs(allGlyphs, length: incomingGlyphLength, forStartingGlyphAtIndex: glyphIndex, characterIndex: characterIndex)
        } else {
            originalStorage?.insertGlyphs(glyphs, length: incomingGlyphLength, forStartingGlyphAtIndex: glyphIndex, characterIndex: characterIndex)
        }
    }
    
    @objc func setIntAttribute(attributeTag: Int, value: Int, forGlyphAtIndex glyphIndex: Int) {
        originalStorage?.setIntAttribute(attributeTag, value: value, forGlyphAtIndex: glyphIndex);
    }
    
    @objc func attributedString() -> NSAttributedString {
        return originalStorage!.attributedString()
    }
    
    @objc func layoutOptions() -> Int {
        return originalStorage!.layoutOptions()
    }
}
