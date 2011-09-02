#import "ViCommon.h"
#include "sys_queue.h"

/*
 * Maximum number of lines in a skip partition.
 * Increasing over this limit results in a split partition.
 */
#define MAXSKIPSIZE		 1000

/*
 * Minimum number of lines in a skip partition.
 * Decreasing below this limit results in a merged or partially merged partition.
 */
#define MINSKIPSIZE		 200

/*
 * Max number of lines in a skip partition for a complete merge.
 * If more than this number of lines, a partial merge is done, ie lines are
 * moved from the larger partition to the smaller to create two equally sized partitions.
 */
#define MERGESKIPSIZE		 500

struct line
{
	TAILQ_ENTRY(line)	 next;
	NSUInteger		 length;
	NSUInteger		 eol;
};
TAILQ_HEAD(skiplines, line);

struct skip
{
	TAILQ_ENTRY(skip)	 next;
	struct skiplines	 lines;
	NSUInteger		 nlines;
	NSUInteger		 length;
};
TAILQ_HEAD(skiplist, skip);

/** Text storage.
 *
 * Line numbers are 1-based. Columns are zero-based.
 */
@interface ViTextStorage : NSTextStorage
{
	NSMutableAttributedString	*attributedString;
	NSUInteger			 lineCount;
	struct skiplist			 skiphead;
}

- (id)init;

- (NSString *)string;
- (NSDictionary *)attributesAtIndex:(unsigned)anIndex
                     effectiveRange:(NSRangePointer)aRange;
- (void)replaceCharactersInRange:(NSRange)aRange
                      withString:(NSString *)str;
- (void)insertString:(NSString *)aString
             atIndex:(NSUInteger)anIndex;
- (void)setAttributes:(NSDictionary *)attributes
                range:(NSRange)aRange;

- (NSInteger)locationForStartOfLine:(NSUInteger)lineNumber
                             length:(NSUInteger *)lengthPtr
                        contentsEnd:(NSUInteger *)eolPtr;

/** Find the start location of a line.
 * @param aLineNumber The line number to lookup.
 * @returns The location for the start of the given line.
 */
- (NSInteger)locationForStartOfLine:(NSUInteger)aLineNumber;

/** Return the range of a line.
 * @param lineNumber The line number to return the range for.
 * @returns The range of the line, or (`NSNotFound`, `0`) if the
 * lineNumber is invalid.
 */
- (NSRange)rangeOfLine:(NSUInteger)lineNumber;

/** Return the range of a line.
 * @param aLocation The location of a character on the line to return the range for.
 * @returns The range of the line, or (`NSNotFound`, `0`) if the
 * location is invalid.
 */
- (NSRange)rangeOfLineAtLocation:(NSUInteger)aLocation;

/** Return the content of the line at a given location.
 * @param aLocation The location of a character on the line.
 * @returns A copy of the line at the given location. The line does not contain the newline.
 */
- (NSString *)lineAtLocation:(NSUInteger)aLocation;
- (NSString *)lineForLocation:(NSUInteger)aLocation;

/** Return the content of a line.
 * @param lineNumber The line number of the line. The first line is numbered 1.
 * @returns A copy of the line, or nil if `lineNumber` is invalid. The line does not contain the newline.
 */
- (NSString *)line:(NSUInteger)lineNumber;

- (NSUInteger)lineIndexAtLocation:(NSUInteger)aLocation;

/** Find the line number of a location.
 * @param aLocation The location of the line number to return.
 * @returns The line number at a given location. Returns 0 if the
 * document is empty.
 */
- (NSUInteger)lineNumberAtLocation:(NSUInteger)aLocation;

/** Return the number of lines.
 * @returns The number of lines, or zero if the document is empty.
 */
- (NSUInteger)lineCount;

- (NSUInteger)skipCharactersInSet:(NSCharacterSet *)characterSet
                             from:(NSUInteger)startLocation
                               to:(NSUInteger)toLocation
                         backward:(BOOL)backwardFlag;
- (NSUInteger)skipCharactersInSet:(NSCharacterSet *)characterSet
                     fromLocation:(NSUInteger)startLocation
                         backward:(BOOL)backwardFlag;
- (NSUInteger)skipWhitespaceFrom:(NSUInteger)startLocation
                      toLocation:(NSUInteger)toLocation;
- (NSUInteger)skipWhitespaceFrom:(NSUInteger)startLocation;
- (NSRange)rangeOfCharactersFromSet:(NSCharacterSet *)characterSet
                         atLocation:(NSUInteger)aLocation
                        acceptAfter:(BOOL)acceptAfter;

- (NSString *)pathAtLocation:(NSUInteger)aLocation
                       range:(NSRange *)returnRange
                 acceptAfter:(BOOL)acceptAfter;

- (NSRange)rangeOfWordAtLocation:(NSUInteger)aLocation
                     acceptAfter:(BOOL)acceptAfter
                 extraCharacters:(NSString *)extraCharacters;
- (NSRange)rangeOfWordAtLocation:(NSUInteger)aLocation
                     acceptAfter:(BOOL)acceptAfter;
- (NSString *)wordAtLocation:(NSUInteger)aLocation
                       range:(NSRange *)returnRange
                 acceptAfter:(BOOL)acceptAfter
	     extraCharacters:(NSString *)extraCharacters;
- (NSString *)wordAtLocation:(NSUInteger)aLocation
                       range:(NSRange *)returnRange
                 acceptAfter:(BOOL)acceptAfter;
- (NSString *)wordAtLocation:(NSUInteger)aLocation
                       range:(NSRange *)returnRange;
- (NSString *)wordAtLocation:(NSUInteger)aLocation;

- (NSUInteger)columnOffsetAtLocation:(NSUInteger)aLocation;

/** Find the column of a location.
 * @param aLocation The location to check for column.
 * @returns The logical column from the start of the line.
 * @bug This method always uses the default tab size when determining the column.
 */
- (NSUInteger)columnAtLocation:(NSUInteger)aLocation;

- (NSUInteger)locationForColumn:(NSUInteger)column
                   fromLocation:(NSUInteger)aLocation
                      acceptEOL:(BOOL)acceptEOL;

/** Determine if a line is blank.
 * @param aLocation A location on the line to check.
 * @returns YES if the line at the given location is blank.
 */
- (BOOL)isBlankLineAtLocation:(NSUInteger)aLocation;

/** Find the range of leading whitespace on a line.
 * @param aLocation A location on the line to check.
 * @returns A range of leading whitespace for the given line.
 * Returns (`NSNotFound`, `0`) if `aLocation` is beyond the end of the document.
 */
- (NSRange)rangeOfLeadingWhitespaceForLineAtLocation:(NSUInteger)aLocation;

/** Return the leading whitespace on a line.
 * @param aLocation A location on the line to check.
 * @returns The leading whitespace for the given line.
 * Returns `nil` if `aLocation` is beyond the end of the document.
 */
- (NSString *)leadingWhitespaceForLineAtLocation:(NSUInteger)aLocation;

/** Find the first non-blank character on a line.
 * @param aLocation A location on the line to check.
 * @returns The location of the first non-blank character on the given line.
 * If the line is blank (no non-blanks found), then the location of the end of the line is returned.
 * Returns `NSNotFound` if `aLocation` is beyond the end of the document.
 */
- (NSUInteger)firstNonBlankForLineAtLocation:(NSUInteger)aLocation;

@end
