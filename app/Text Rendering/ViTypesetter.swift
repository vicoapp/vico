import Foundation
import Cocoa

/**
 * This typesetter does custom work for Vico. Its main use currently
 * is to produce zero advancements when typesetting characters that
 * are currently in a closed fold. Code that has been folded is marked
 * with the `ViFoldedAttributeName` attribute set to `true`.
 *
 * This is pulled largely from WWDC 2010 Session 114: Advanced Cocoa Text Tips
 * and Tricks, as linked to on [cocoa-dev](http://lists.apple.com/archives/cocoa-dev/2012/Nov/msg00378.html).
 */
class ViTypesetter: NSATSTypesetter {
    override func actionForControlCharacterAtIndex(characterIndex: Int) -> NSTypesetterControlCharacterAction {
        let folded: Bool? =
            self.attributedString?.typedAttribute(ViTextAttribute.Folded, atIndex: characterIndex, effectiveRange: nil)
        
        if folded ?? false {
            return NSTypesetterControlCharacterAction.ZeroAdvancementAction;
        } else {
            return super.actionForControlCharacterAtIndex(characterIndex);
        }
    }
}