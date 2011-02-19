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
	NSArray			*continuations;
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

@interface ViTextStorage : NSTextStorage
{
	NSMutableString		*string;
	NSDictionary		*typingAttributes;
	NSUInteger		 lineCount;
	struct skiplist		 skiphead;
}

- (id)init;

- (void)setTypingAttributes:(NSDictionary *)attributes;

- (NSString *)string;
- (NSDictionary *)attributesAtIndex:(unsigned)anIndex effectiveRange:(NSRangePointer)aRange;
- (void)replaceCharactersInRange:(NSRange)aRange withString:(NSString *)str;
- (void)insertString:(NSString *)aString atIndex:(NSUInteger)anIndex;
- (void)setAttributes:(NSDictionary *)attributes range:(NSRange)aRange;

- (NSInteger)locationForStartOfLine:(NSUInteger)lineNumber length:(NSUInteger *)lengthPtr contentsEnd:(NSUInteger *)eolPtr;
- (NSInteger)locationForStartOfLine:(NSUInteger)aLineNumber;
- (NSRange)rangeOfLine:(NSUInteger)lineNumber;
- (NSUInteger)lineIndexAtLocation:(NSUInteger)aLocation;
- (NSUInteger)lineNumberAtLocation:(NSUInteger)aLocation;
- (NSUInteger)lineCount;

- (NSUInteger)skipCharactersInSet:(NSCharacterSet *)characterSet from:(NSUInteger)startLocation to:(NSUInteger)toLocation backward:(BOOL)backwardFlag;
- (NSUInteger)skipCharactersInSet:(NSCharacterSet *)characterSet fromLocation:(NSUInteger)startLocation backward:(BOOL)backwardFlag;
- (NSUInteger)skipWhitespaceFrom:(NSUInteger)startLocation toLocation:(NSUInteger)toLocation;
- (NSUInteger)skipWhitespaceFrom:(NSUInteger)startLocation;

- (NSString *)wordAtLocation:(NSUInteger)aLocation range:(NSRange *)returnRange;
- (NSString *)wordAtLocation:(NSUInteger)aLocation;

- (NSUInteger)columnOffsetAtLocation:(NSUInteger)aLocation;
- (NSUInteger)columnAtLocation:(NSUInteger)aLocation;
- (NSUInteger)locationForColumn:(NSUInteger)column fromLocation:(NSUInteger)aLocation acceptEOL:(BOOL)acceptEOL;

- (NSString *)lineForLocation:(NSUInteger)aLocation;
- (BOOL)isBlankLineAtLocation:(NSUInteger)aLocation;

@end
