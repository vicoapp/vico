#import "ExCommand.h"
#import "ViCompletionController.h"

/** Parser for ex commands.
 */
@interface ExParser : NSObject
{
	ExMap	*_map;
}

@property(nonatomic,readwrite,retain) ExMap *map;

/** @returns A shared ex parser instance. */
+ (ExParser *)sharedParser;

- (ExCommand *)parse:(NSString *)string
	       caret:(NSInteger)completionLocation
	  completion:(id<ViCompletionProvider> *)completionProviderPtr
	       range:(NSRange *)completionRangePtr
               error:(NSError **)outError;

/** Parse an ex command.
 *
 * @param string The whole ex command string to parse.
 * @param outError Return value parameter for errors. May be `nil`.
 * @returns An ExCommand, or nil on error.
 */
- (ExCommand *)parse:(NSString *)string
	       error:(NSError **)outError;

/** Expand filename metacharacters
 *
 * This method expands `%` and `#` to the current and alternate document URLs, respectively.
 * The following modifiers are recognized:
 *
 *  - `:p` -- replace with normalized path
 *  - `:h` -- head of url; delete the last path component (may be specified multiple times)
 *  - `:t` -- tail of url; replace with last path component
 *  - `:e` -- replace with the extension
 *  - `:r` -- root of url; delete the path extension
 *
 * To insert a literal `%` or `#` character, escape it with a backslash (`\`).
 * Escapes are removed.
 *
 * @param string The string to expand.
 * @param outError Return value parameter for errors. May be `nil`.
 * @returns The expanded string.
 */
- (NSString *)expand:(NSString *)string error:(NSError **)outError;

+ (BOOL)parseRange:(NSScanner *)scan
       intoAddress:(ExAddress **)addr;

+ (int)parseRange:(NSScanner *)scan
      intoAddress:(ExAddress **)addr1
     otherAddress:(ExAddress **)addr2;

@end
