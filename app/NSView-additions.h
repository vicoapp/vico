@class ViCommand;

/** Convenience NSView functions. */
@interface NSView (additions)
/** Find the target for a command action.
 *
 * The following objects are checked if they respond to the action selector:
 *
 * 1. The view itself and any of its superviews
 * 2. The views window
 * 3. The views windowcontroller
 * 4. The views delegate, if any
 * 5. The views document, if any
 * 6. The views key managers target, if any
 * 7. The application delegate
 *
 * @param action The command action being executed.
 * @returns The first object responding to the selector, or `nil` if not found.
 */
- (id)targetForSelector:(SEL)action;

- (NSString *)getExStringForCommand:(ViCommand *)command;
@end
