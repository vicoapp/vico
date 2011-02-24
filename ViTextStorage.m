#import "ViTextStorage.h"
#include "logging.h"

@implementation ViTextStorage

static NSMutableCharacterSet *wordSet = nil;

#pragma mark -
#pragma mark Primitive methods

/*
 * http://developer.apple.com/library/mac/#documentation/Cocoa/Conceptual/TextStorageLayer/Tasks/Subclassing.html
 */

- (id)init
{
	self = [super init];
	if (self) {
		string = [[NSMutableString alloc] init];
		typingAttributes = [NSDictionary dictionaryWithObject:[NSFont userFixedPitchFontOfSize:20]
		                                               forKey:NSFontAttributeName];
		TAILQ_INIT(&skiphead);
	}
	return self;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViTextStorage %p>", self];
}

- (NSString *)string
{
	return string;
}

static inline struct skip *
skip_for_line(struct skiplist *head, NSUInteger lineIndex, NSUInteger *offset)
{
	struct skip	*skip;

	*offset = 0;

	TAILQ_FOREACH(skip, head, next) {
		if (*offset + skip->nlines > lineIndex ||
		    TAILQ_NEXT(skip, next) == NULL)
			break;
		*offset += skip->nlines;
	}

	return skip;
}

static void
skip_split(struct skiplist *head, struct skip *left)
{
	struct line	*ln;
	struct skip	*right;
	NSUInteger	 half;

	DEBUG(@"SPLITTING partition %p", left);

	right = calloc(1, sizeof(*right));
	TAILQ_INIT(&right->lines);
	TAILQ_INSERT_AFTER(head, left, right, next);

	half = left->nlines / 2;
	while (half--) {
		ln = TAILQ_LAST(&left->lines, skiplines);

		TAILQ_REMOVE(&left->lines, ln, next);
		TAILQ_INSERT_HEAD(&right->lines, ln, next);

		left->length -= ln->length;
		left->nlines--;

		right->length += ln->length;
		right->nlines++;
	}
}

- (void)insertLine:(NSUInteger)lineIndex withLength:(NSUInteger)length contentsEnd:(NSUInteger)eol
{
	struct skip	*skip;
	struct line	*ln;
	struct line	*newln;
	NSUInteger	 offset;

	skip = skip_for_line(&skiphead, lineIndex, &offset);

	if (skip == NULL) {
		/* This is the very first skip partition. */
		skip = calloc(1, sizeof(*skip));
		TAILQ_INIT(&skip->lines);
		TAILQ_INSERT_TAIL(&skiphead, skip, next);
	}

	/*
	 * Find where the new line should be inserted.
	 */
	TAILQ_FOREACH(ln, &skip->lines, next)
		if (offset++ == lineIndex)
			break;

	newln = calloc(1, sizeof(*ln));
	newln->length = length;
	newln->eol = eol;

	if (ln == NULL)
		TAILQ_INSERT_TAIL(&skip->lines, newln, next);
	else
		TAILQ_INSERT_BEFORE(ln, newln, next);

	skip->length += length;
	skip->nlines++;
	lineCount++;

	/*
	 * If we've reached the limit of a partition, split it in
	 * two equally sized partitions.
	 */
	if (skip->nlines > MAXSKIPSIZE)
		skip_split(&skiphead, skip);
}

static void
debug_skiplist(struct skiplist *head)
{
	INFO(@"%s", "current skiplist:");

	int n = 0;
	NSUInteger line = 0;
	struct skip *skip;
	TAILQ_FOREACH(skip, head, next) {
		INFO(@"partition %i: nlines %lu, length %lu",
		    n++, skip->nlines, skip->length);

		struct line *ln;
		TAILQ_FOREACH(ln, &skip->lines, next)
			INFO(@"    line %lu: length %lu", line++, ln->length);
	}
}

-  (void)debug
{
	debug_skiplist(&skiphead);
}

static void
skip_merge_right(struct skiplist *head, struct skip *from, struct skip *to, NSUInteger num)
{
	DEBUG(@"merge right %lu lines from %p to %p", num, from, to);
	struct line *ln;
	while (num-- > 0 && (ln = TAILQ_LAST(&from->lines, skiplines)) != NULL) {
		TAILQ_REMOVE(&from->lines, ln, next);
		TAILQ_INSERT_HEAD(&to->lines, ln, next);
		to->nlines++;
		from->nlines--;
		to->length += ln->length;
		from->length -= ln->length;
	}

	if (from->nlines == 0)
		TAILQ_REMOVE(head, from, next);
}

static void
skip_merge_left(struct skiplist *head, struct skip *from, struct skip *to, NSUInteger num)
{
	DEBUG(@"merge left %lu lines from %p to %p", num, from, to);
	struct line *ln;
	while (num-- > 0 && (ln = TAILQ_FIRST(&from->lines)) != NULL) {
		TAILQ_REMOVE(&from->lines, ln, next);
		TAILQ_INSERT_TAIL(&to->lines, ln, next);
		to->nlines++;
		from->nlines--;
		to->length += ln->length;
		from->length -= ln->length;
	}

	if (from->nlines == 0)
		TAILQ_REMOVE(head, from, next);
}

- (void)removeLine:(NSUInteger)lineIndex
{
	struct skip	*skip;
	struct line	*ln;
	NSUInteger	 offset;

	skip = skip_for_line(&skiphead, lineIndex, &offset);
	DEBUG(@"skip %p has offset %lu, and %lu lines", skip, offset, skip->nlines);

	/* Find the line to remove. */
	TAILQ_FOREACH(ln, &skip->lines, next)
		if (offset++ == lineIndex)
			break;

	if (ln == NULL) {
		INFO(@"line %lu not found in skip partition %p!", lineIndex, skip);
		debug_skiplist(&skiphead);
		assert(0);
	}

	skip->length -= ln->length;
	skip->nlines--;

	TAILQ_REMOVE(&skip->lines, ln, next);
	free(ln);

	/*
	 * If the partition now has less than the minimum lines required, try to merge
	 * from a neighbour partition.
	 */
	if (skip->nlines < MINSKIPSIZE) {
		struct skip *left_neighbour = TAILQ_PREV(skip, skiplist, next);
		struct skip *right_neighbour = TAILQ_NEXT(skip, next);

		if (right_neighbour && right_neighbour->nlines < MERGESKIPSIZE)
			skip_merge_right(&skiphead, skip, right_neighbour, skip->nlines);
		else if (left_neighbour && left_neighbour->nlines < MERGESKIPSIZE)
			skip_merge_left(&skiphead, skip, left_neighbour, skip->nlines);
		else {
			/* Do a partial merge. Move lines from left or right. */
			if (right_neighbour) {
				if (left_neighbour) {
					if (right_neighbour->nlines > left_neighbour->nlines)
						skip_merge_left(&skiphead, right_neighbour, skip, (right_neighbour->nlines - skip->nlines) / 2);
					else
						skip_merge_right(&skiphead, left_neighbour, skip, (left_neighbour->nlines - skip->nlines) / 2);
				} else
					skip_merge_left(&skiphead, right_neighbour, skip, (right_neighbour->nlines - skip->nlines) / 2);
			} else if (left_neighbour)
				skip_merge_right(&skiphead, left_neighbour, skip, (left_neighbour->nlines - skip->nlines) / 2);
		}
	}

/*
	if (skip->nlines == 0) {
		TAILQ_REMOVE(&skiphead, skip, next);
		free(skip);
	}
*/

	lineCount--;
}

- (void)replaceLine:(NSUInteger)lineIndex withLength:(NSUInteger)length contentsEnd:(NSUInteger)eol
{
	struct skip	*skip;
	struct line	*ln;
	NSUInteger	 offset;

	skip = skip_for_line(&skiphead, lineIndex, &offset);

	/* Find the line to replace. */
	TAILQ_FOREACH(ln, &skip->lines, next)
		if (offset++ == lineIndex)
			break;

	skip->length -= ln->length;
	skip->length += length;
	ln->length = length;
	ln->eol = eol;
}

- (void)replaceCharactersInRange:(NSRange)aRange withString:(NSString *)str
{
	/*
	 * Update our line number data structure.
	 */
	NSInteger diff = [str length] - aRange.length;
	DEBUG(@"edited range = %@, diff = %li, str = [%@]", NSStringFromRange(aRange), diff, str);

	NSUInteger lineIndex = [self lineIndexAtLocation:aRange.location];
	NSUInteger location = aRange.location;
	NSUInteger bol, eol, end;

	DEBUG(@"changing line index %lu, got %lu lines", lineIndex, lineCount);

	if (aRange.length > 0) /* delete or replace */
		/* Remove affected _whole_ lines. */
		for (;;) {
			[string getLineStart:&bol end:&end contentsEnd:NULL forRange:NSMakeRange(location, 0)];
			if (end > NSMaxRange(aRange))
				/* Line only partially affected, just update after modification. */
				break;
			if (lineIndex >= lineCount)
				break;
			DEBUG(@"remove line %lu: had length %li at location %lu, end at %lu",
			    lineIndex, end - bol, bol, end);
			[self removeLine:lineIndex];
			location = end;
		}

	[string replaceCharactersInRange:aRange withString:str];

	/* Update partially affected line. */
	location = aRange.location;
	if (lineIndex < lineCount) {
		[string getLineStart:&bol end:&end contentsEnd:&eol forRange:NSMakeRange(location, 0)];
		DEBUG(@"replace line %lu: has length %li at location %lu, end at %lu",
		    lineIndex, end - bol, bol, end);
		[self replaceLine:lineIndex withLength:end - bol contentsEnd:eol - bol];
		location = end;
		lineIndex++;
	}

	/* Insert whole new lines. */
	if ([str length] > 0) {
		NSUInteger endLocation = NSMaxRange(aRange) + diff;
		DEBUG(@"location = %lu, endLocation = %lu", location, endLocation);
		while (location < [self length]) {
			[string getLineStart:&bol end:&end contentsEnd:&eol forRange:NSMakeRange(location, 0)];
			if (bol > endLocation)
				break;
			DEBUG(@"insert line %lu: has length %li at location %lu, end at %lu",
			    lineIndex, end - bol, bol, end);
			[self insertLine:lineIndex withLength:end - bol contentsEnd:eol - bol];
			location = end;
			lineIndex++;
		}
	}
//	debug_skiplist(&skiphead);

	[self edited:NSTextStorageEditedCharacters range:aRange changeInLength:diff];
}

- (void)insertString:(NSString *)aString atIndex:(NSUInteger)anIndex
{
	[self replaceCharactersInRange:NSMakeRange(anIndex, 0) withString:aString];
}

- (NSDictionary *)attributesAtIndex:(unsigned)anIndex effectiveRange:(NSRangePointer)aRangePtr
{
	if (aRangePtr)
		*aRangePtr = NSMakeRange(0, [string length]);
	return typingAttributes;
}

- (void)setAttributes:(NSDictionary *)attributes range:(NSRange)range
{
	/* We always use the typing attributes. */
}

- (void)setTypingAttributes:(NSDictionary *)attributes
{
	typingAttributes = [attributes copy];
	[self edited:NSTextStorageEditedAttributes range:NSMakeRange(0, [self length]) changeInLength:0];
}

#pragma mark -
#pragma mark Line number handling

- (NSInteger)locationForStartOfLine:(NSUInteger)lineNumber length:(NSUInteger *)lengthPtr contentsEnd:(NSUInteger *)eolPtr
{
	if (lineNumber == 0)
		return 0;

	/* Line numbers are 1-based. Line indexes are 0-based. */
	NSUInteger lineIndex = lineNumber - 1;

	if (lineIndex >= lineCount)
		return -1LL;

	NSInteger location = 0, line = 0;

	/* Find the skip partition. */
	struct skip *skip;
	TAILQ_FOREACH(skip, &skiphead, next) {
		if (line + skip->nlines > lineIndex)
			break;
		line += skip->nlines;
		location += skip->length;
	}

	/* Find the line. */
	struct line *ln;
	TAILQ_FOREACH(ln, &skip->lines, next) {
		if (line++ == lineIndex)
			break;
		location += ln->length;
	}

	if (lengthPtr)
		*lengthPtr = ln->length;
	if (eolPtr)
		*eolPtr = location + ln->eol;

	return location;
}

- (NSRange)rangeOfLine:(NSUInteger)lineNumber
{
	NSRange r;
	r.location = [self locationForStartOfLine:lineNumber length:&r.length contentsEnd:nil];
	return r;
}

- (NSInteger)locationForStartOfLine:(NSUInteger)lineNumber
{
	return [self locationForStartOfLine:lineNumber length:nil contentsEnd:nil];
}

- (NSUInteger)lineIndexAtLocation:(NSUInteger)aLocation
{
	if ([self length] == 0)
		return 0;

	if (aLocation > [self length])
		aLocation = [self length];

	/* Find the skip partition. */
	NSUInteger line = 0;
	NSUInteger location = 0;
	struct skip *skip;
	TAILQ_FOREACH(skip, &skiphead, next) {
		if (location + skip->length >= aLocation)
			break;
		line += skip->nlines;
		location += skip->length;
	}

	if (skip == NULL)
		return line;

	/* Find the line. */
	struct line *ln;
	TAILQ_FOREACH(ln, &skip->lines, next) {
		if (location + ln->length > aLocation || ln->eol == ln->length)
			break;
		location += ln->length;
		line++;
	}
 
	return line;
}

- (NSUInteger)lineNumberAtLocation:(NSUInteger)aLocation
{
	if ([self length] == 0)
		return 0;
	return [self lineIndexAtLocation:aLocation] + 1;
}

- (NSUInteger)lineCount
{
	return lineCount;
}

#pragma mark -
#pragma mark Convenience methods

- (NSUInteger)skipCharactersInSet:(NSCharacterSet *)characterSet
                             from:(NSUInteger)startLocation
                               to:(NSUInteger)toLocation
                         backward:(BOOL)backwardFlag
{
	NSRange r;
	if (backwardFlag)
		r = NSMakeRange(toLocation, startLocation - toLocation + 1);
	else
		r = NSMakeRange(startLocation, toLocation - startLocation);

	r = [[self string] rangeOfCharacterFromSet:[characterSet invertedSet]
					   options:backwardFlag ? NSBackwardsSearch : 0
					     range:r];

	if (r.location == NSNotFound)
		return toLocation;
	return r.location;
}

- (NSUInteger)skipCharactersInSet:(NSCharacterSet *)characterSet
                     fromLocation:(NSUInteger)startLocation
                         backward:(BOOL)backwardFlag
{
	return [self skipCharactersInSet:characterSet
				    from:startLocation
				      to:backwardFlag ? 0 : [self length]
				backward:backwardFlag];
}

- (NSUInteger)skipWhitespaceFrom:(NSUInteger)startLocation
                      toLocation:(NSUInteger)toLocation
{
	return [self skipCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]
				    from:startLocation
				      to:toLocation
				backward:NO];
}

- (NSUInteger)skipWhitespaceFrom:(NSUInteger)startLocation
{
	return [self skipCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]
			    fromLocation:startLocation
				backward:NO];
}

- (NSString *)wordAtLocation:(NSUInteger)aLocation range:(NSRange *)returnRange
{
	if (aLocation >= [self length]) {
		if (returnRange != nil)
			*returnRange = NSMakeRange(0, 0);
		return @"";
	}

	if (wordSet == nil) {
		wordSet = [NSMutableCharacterSet characterSetWithCharactersInString:@"_"];
		[wordSet formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
	}

	NSUInteger word_start = [self skipCharactersInSet:wordSet fromLocation:aLocation backward:YES];
	if (word_start < aLocation && word_start > 0)
		word_start += 1;

	NSUInteger word_end = [self skipCharactersInSet:wordSet fromLocation:aLocation backward:NO];
	if (word_end > word_start) {
		NSRange range = NSMakeRange(word_start, word_end - word_start);
		if (returnRange)
			*returnRange = range;
		return [[self string] substringWithRange:range];
	}

	if (returnRange)
		*returnRange = NSMakeRange(0, 0);

	return nil;
}

- (NSString *)wordAtLocation:(NSUInteger)aLocation
{
	return [self wordAtLocation:aLocation range:nil];
}

- (NSUInteger)columnOffsetAtLocation:(NSUInteger)aLocation
{
	NSUInteger bol, end;
	[[self string] getLineStart:&bol end:&end contentsEnd:NULL forRange:NSMakeRange(aLocation, 0)];
	return aLocation - bol;
}

- (NSUInteger)columnAtLocation:(NSUInteger)aLocation
{
	NSUInteger bol, end;
	[[self string] getLineStart:&bol end:&end contentsEnd:NULL forRange:NSMakeRange(aLocation, 0)];
	NSUInteger c = 0, i;
	int ts = [[NSUserDefaults standardUserDefaults] integerForKey:@"tabstop"];
	for (i = bol; i <= aLocation && i < end; i++) {
		unichar ch = [[self string] characterAtIndex:i];
		if (ch == '\t')
			c += ts - (c % ts);
		else
			c++;
	}
	return c;
}

- (NSUInteger)locationForColumn:(NSUInteger)column
                   fromLocation:(NSUInteger)aLocation
                      acceptEOL:(BOOL)acceptEOL
{
	NSUInteger bol, eol;
	[[self string] getLineStart:&bol end:NULL contentsEnd:&eol forRange:NSMakeRange(aLocation, 0)];
	NSUInteger c = 0, i;
	int ts = [[NSUserDefaults standardUserDefaults] integerForKey:@"tabstop"];
	for (i = bol; i < eol; i++) {
		unichar ch = [[self string] characterAtIndex:i];
		if (ch == '\t')
			c += ts - (c % ts);
		else
			c++;
		if (c >= column)
			break;
	}
	if (!acceptEOL && i == eol && bol < eol)
		i = eol - 1;
	return i;
}

- (NSString *)lineForLocation:(NSUInteger)aLocation
{
	NSUInteger bol, eol;
	[[self string] getLineStart:&bol end:NULL contentsEnd:&eol forRange:NSMakeRange(aLocation, 0)];
	return [[self string] substringWithRange:NSMakeRange(bol, eol - bol)];
}

- (BOOL)isBlankLineAtLocation:(NSUInteger)aLocation
{
	NSString *line = [self lineForLocation:aLocation];
	NSCharacterSet *cset = [[NSCharacterSet whitespaceCharacterSet] invertedSet];
	return [line rangeOfCharacterFromSet:cset].location == NSNotFound;
}

- (NSString *)leadingWhitespaceForLineAtLocation:(NSUInteger)aLocation
{
	NSUInteger bol, eol;
	[[self string] getLineStart:&bol end:NULL contentsEnd:&eol forRange:NSMakeRange(aLocation, 0)];
	NSRange lineRange = NSMakeRange(bol, eol - bol);

	NSCharacterSet *cset = [[NSCharacterSet whitespaceCharacterSet] invertedSet];
	NSRange r = [[self string] rangeOfCharacterFromSet:cset options:0 range:lineRange];

	if (r.location == NSNotFound)
                r.location = eol;
	else if (r.location == bol)
		return @"";

        r = NSMakeRange(lineRange.location, r.location - lineRange.location);
        return [[self string] substringWithRange:r];
}

@end

