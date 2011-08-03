/** Convenience NSEvent functions. */
@interface NSEvent (keyAdditions)

/**
 * @return The normalized key code from a key event.
 */
- (NSInteger)normalizedKeyCode;

@end
