/** Register manager
 *
 * The register manager handles the content of registers.
 *
 * There are a number of special registers:
 *
 * - `"` -- The unnamed register. This is the default register.
 * - `+` or `*` -- The Mac OS clipboard.
 * - `%` -- The URL of the current document.
 * - `#` -- The URL of the alternate document.
 * - `/` -- The last search term.
 * - `_` (underscore) -- The null register; anything stored in this register is discarded.
 */

@interface ViRegisterManager : NSObject
{
	NSMutableDictionary	*registers;
}

/** Returns the global shared register manager.
 */
+ (id)sharedManager;

/** Returns the global shared register manager.
 * @param regName The name of the register.
 */
- (NSString *)contentOfRegister:(unichar)regName;

/** Set the content string of a register.
 * @param content The content of the register being set.
 * @param regName The name of the register.
 *
 * Uppercase register `A` to `Z` causes the content to be appended.
 */
- (void)setContent:(NSString *)content ofRegister:(unichar)regName;

/** Returns a description of a register.
 * @param regName The name of the register.
 */
- (NSString *)nameOfRegister:(unichar)regName;

@end