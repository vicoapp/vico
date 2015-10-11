import Foundation
import Cocoa

class ViLayoutManager: NSLayoutManager {
    // We handle our own rendering of invisible characters, so intercept
    // NSLayoutManager's showsInvisibleCharacters so that the super-implementation
    // never draws them.
    private var _showsInvisibleCharacters = false
    override var showsInvisibleCharacters: Bool {
        get {
            return false
        }
        set {
            _showsInvisibleCharacters = newValue
        }
    }
    
    private var _attributesForInvisibles = [String: AnyObject]()
    var attributesForInvisibles: [String: AnyObject] {
        set {
            _attributesForInvisibles = newValue
            _attributesForInvisibles[NSFontAttributeName] = ViThemeStore.font()
            
            for key in invisibleCharacterDictionary.keys {
                invisibleImageDictionary[key] = nil
            }
        }
        get {
            return _attributesForInvisibles
        }
    }
    
    // TODO Make customizable?
    private let invisibleCharacterDictionary: [Character: String] =
        [
            "\n": "↩",
            "\t": "⇥",
            " ": "･"
        ]
    private var invisibleImageDictionary = [Character: NSImage]()
    
    override init() {
        super.init()
        
        glyphGenerator = ViGlyphGenerator()
        typesetter = ViTypesetter()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        glyphGenerator = ViGlyphGenerator()
        typesetter = ViTypesetter()
    }

    // Draw standard glyphs, then our own invisibles if requested.
    override func drawGlyphsForGlyphRange(glyphsToShow: NSRange, atPoint origin: NSPoint) {
        super.drawGlyphsForGlyphRange(glyphsToShow, atPoint: origin)
        
        if let glyphRange = glyphsToShow.toRange(),
            content: NSString = textStorage?.string where _showsInvisibleCharacters {
                for glyphIndex in glyphRange {
                    let characterIndex = characterIndexForGlyphAtIndex(glyphIndex)
                    let character = Character(UnicodeScalar(content.characterAtIndex(characterIndex)))
                    
                    if let invisibleImage = imageForInvisible(character) {
                        let glyphOrigin = locationForGlyphAtIndex(glyphIndex)
                        let containingFragment = lineFragmentRectForGlyphAtIndex(glyphIndex, effectiveRange: nil)
                        
                        let glyphRect =
                            NSMakeRect(
                                glyphOrigin.x + containingFragment.origin.x,
                                containingFragment.origin.y,
                                invisibleImage.size.width,
                                invisibleImage.size.height
                            )
                        
                        invisibleImage.drawInRect(glyphRect, fromRect: NSZeroRect, operation: NSCompositingOperation.CompositeSourceOver, fraction: 1.0, respectFlipped: true, hints: nil)
                    }
                }
        }
    }
    
    // Access already-computed image for the invisible, or compute lazily.
    private func imageForInvisible(invisible: Character) -> NSImage? {

        if let existing = invisibleImageDictionary[invisible] {
            return existing
        } else if let visibleString = invisibleCharacterDictionary[invisible] {
            let size = visibleString.sizeWithAttributes(attributesForInvisibles)
            
            let image = NSImage(size: size)
            image.lockFocusFlipped(false)
            visibleString.drawAtPoint(NSMakePoint(0,0), withAttributes: attributesForInvisibles)
            image.unlockFocus()
            
            invisibleImageDictionary[invisible] = image
            
            return image
        } else {
            return nil
        }
    }
}
