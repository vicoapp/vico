/**
 * This typesetter does custom work for Vico. Its main use currently is to erase control
 * characters in a folded block using NSTypesetterZeroAdvancementAction.
 *
 * This is pulled largely from WWDC 2010 Session 114: Advanced Cocoa Text Tips
 * and Tricks, as linked to on cocoa-dev at
 * http://lists.apple.com/archives/cocoa-dev/2012/Nov/msg00378.html .
 */
@interface ViTypesetter : NSATSTypesetter {
}
@end
