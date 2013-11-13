/**
 * This glyph generator does custom work for Vico. Its main use currently is to
 * produce null glyphs for code that has been folded. Code that has been folded
 * is marked with the ViFoldedAttributeName attribute set to @YES.
 *
 * This is pulled largely from WWDC 2010 Session 114: Advanced Cocoa Text Tips
 * and Tricks, as linked to on cocoa-dev at
 * http://lists.apple.com/archives/cocoa-dev/2012/Nov/msg00378.html .
 */
@interface ViGlyphGenerator : NSGlyphGenerator <NSGlyphStorage> {
    id<NSGlyphStorage> _originalStorage; // the original glyph generation requester
}
@end
