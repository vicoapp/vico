/*
 * Copyright (c) 2008-2012 Martin Hedenfalk <martin@vicoapp.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

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
	if ((self = [super init]) != nil) {
		_attributedString = [[NSMutableAttributedString alloc] init];
		TAILQ_INIT(&_skiphead);
	}
	return self;
}


- (void)dealloc
{
	DEBUG_DEALLOC();

	/* Free the skiplist. */
	struct skip *skip;
	while ((skip = TAILQ_FIRST(&_skiphead)) != NULL) {
		struct line *ln;
		while ((ln = TAILQ_FIRST(&skip->lines)) != NULL) {
			TAILQ_REMOVE(&skip->lines, ln, next);
			free(ln);
		}
		TAILQ_REMOVE(&_skiphead, skip, next);
		free(skip);
	}


}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViTextStorage %p>", self];
}

- (NSString *)string
{
	return [_attributedString string];
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

- (void)insertLine:(NSUInteger)lineIndex
        withLength:(NSUInteger)length
       contentsEnd:(NSUInteger)eol
{
	struct skip	*skip;
	struct line	*ln;
	struct line	*newln;
	NSUInteger	 offset;

	skip = skip_for_line(&_skiphead, lineIndex, &offset);

	if (skip == NULL) {
		/* This is the very first skip partition. */
		skip = calloc(1, sizeof(*skip));
		TAILQ_INIT(&skip->lines);
		TAILQ_INSERT_TAIL(&_skiphead, skip, next);
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
	_lineCount++;

	/*
	 * If we've reached the limit of a partition, split it in
	 * two equally sized partitions.
	 */
	if (skip->nlines > MAXSKIPSIZE)
		skip_split(&_skiphead, skip);
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
	debug_skiplist(&_skiphead);
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

	skip = skip_for_line(&_skiphead, lineIndex, &offset);
	DEBUG(@"skip %p has offset %lu, and %lu lines", skip, offset, skip->nlines);

	/* Find the line to remove. */
	TAILQ_FOREACH(ln, &skip->lines, next)
		if (offset++ == lineIndex)
			break;

	if (ln == NULL) {
		INFO(@"line %lu not found in skip partition %p!", lineIndex, skip);
		debug_skiplist(&_skiphead);
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
			skip_merge_right(&_skiphead, skip, right_neighbour, skip->nlines);
		else if (left_neighbour && left_neighbour->nlines < MERGESKIPSIZE)
			skip_merge_left(&_skiphead, skip, left_neighbour, skip->nlines);
		else {
			/* Do a partial merge. Move lines from left or right. */
			if (right_neighbour) {
				if (left_neighbour) {
					if (right_neighbour->nlines > left_neighbour->nlines)
						skip_merge_left(&_skiphead, right_neighbour, skip, (right_neighbour->nlines - skip->nlines) / 2);
					else
						skip_merge_right(&_skiphead, left_neighbour, skip, (left_neighbour->nlines - skip->nlines) / 2);
				} else
					skip_merge_left(&_skiphead, right_neighbour, skip, (right_neighbour->nlines - skip->nlines) / 2);
			} else if (left_neighbour)
				skip_merge_right(&_skiphead, left_neighbour, skip, (left_neighbour->nlines - skip->nlines) / 2);
		}
	}

	_lineCount--;
}

- (void)replaceLine:(NSUInteger)lineIndex
	 withLength:(NSUInteger)length
	contentsEnd:(NSUInteger)eol
{
	struct skip	*skip;
	struct line	*ln;
	NSUInteger	 offset;

	skip = skip_for_line(&_skiphead, lineIndex, &offset);

	/* Find the line to replace. */
	TAILQ_FOREACH(ln, &skip->lines, next)
		if (offset++ == lineIndex)
			break;

	if (ln) {
		skip->length -= ln->length;
		skip->length += length;
		ln->length = length;
		ln->eol = eol;
	}
}

- (void)replaceCharactersInRange:(NSRange)aRange withString:(NSString *)str
{
	/*
	 * Update our line number data structure.
	 */
	NSInteger diff = [str length] - aRange.length;
	DEBUG(@"edited range = %@, diff = %li, str = [%@]",
		NSStringFromRange(aRange), diff, str);

	if (str == nil)
		str = @"";

	NSUInteger lineIndex = [self lineIndexAtLocation:aRange.location];
	NSUInteger firstLineIndex = lineIndex;
	NSUInteger linesChanged = 0;
	NSUInteger linesRemoved = 0;
	NSUInteger linesAdded = 0;
	NSUInteger location = aRange.location;
	NSUInteger bol, eol, end;

	DEBUG(@"changing line index %lu, got %lu lines", lineIndex, _lineCount);

	if (aRange.length > 0) /* delete or replace */
		/* Remove affected _whole_ lines. */
		for (;;) {
			[[self string] getLineStart:&bol
						end:&end
					contentsEnd:NULL
					   forRange:NSMakeRange(location, 0)];
			if (end > NSMaxRange(aRange))
				/* Line only partially affected, just update after modification. */
				break;
			if (lineIndex >= _lineCount)
				break;
			DEBUG(@"remove line %lu: had length %li at location %lu, end at %lu",
			    lineIndex, end - bol, bol, end);
			[self removeLine:lineIndex];
			location = end;
			linesRemoved++;
			linesChanged++;
		}

	[_attributedString replaceCharactersInRange:aRange withString:str];

	/* Update partially affected line. */
	location = aRange.location;
	if (lineIndex < _lineCount) {
		[[self string] getLineStart:&bol
					end:&end
				contentsEnd:&eol
				   forRange:NSMakeRange(location, 0)];
		DEBUG(@"replace line %lu: has length %li at location %lu, end at %lu",
		    lineIndex, end - bol, bol, end);
		[self replaceLine:lineIndex
		       withLength:end - bol
		      contentsEnd:eol - bol];
		location = end;
		lineIndex++;
		linesChanged++;
	}

	/* Insert whole new lines. */
	if ([str length] > 0) {
		NSUInteger endLocation = NSMaxRange(aRange) + diff;
		DEBUG(@"location = %lu, endLocation = %lu", location, endLocation);
		while (location < [self length]) {
			[[self string] getLineStart:&bol
						end:&end
					contentsEnd:&eol
					   forRange:NSMakeRange(location, 0)];
			if (bol > endLocation)
				break;
			DEBUG(@"insert line %lu: has length %li at location %lu, end at %lu",
			    lineIndex, end - bol, bol, end);
			[self insertLine:lineIndex
			      withLength:end - bol
			     contentsEnd:eol - bol];
			location = end;
			lineIndex++;
			linesAdded++;
			linesChanged++;
		}
	}
//	debug_skiplist(&_skiphead);

	DEBUG(@"changed %li lines (removed %lu, inserted %lu) from line index %lu",
	    linesChanged, linesRemoved, linesAdded, firstLineIndex);

	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
	    [NSNumber numberWithUnsignedInteger:linesChanged], @"linesChanged",
	    [NSNumber numberWithUnsignedInteger:linesRemoved], @"linesRemoved",
	    [NSNumber numberWithUnsignedInteger:linesAdded], @"linesAdded",
	    [NSNumber numberWithUnsignedInteger:firstLineIndex], @"lineIndex",
	    nil];
	[center postNotificationName:ViTextStorageChangedLinesNotification
	                      object:self
	                    userInfo:userInfo];

	[self edited:NSTextStorageEditedCharacters range:aRange changeInLength:diff];
}

- (void)insertString:(NSString *)aString atIndex:(NSUInteger)anIndex
{
	[self replaceCharactersInRange:NSMakeRange(anIndex, 0) withString:aString];
}

- (NSDictionary *)attributesAtIndex:(NSUInteger)anIndex effectiveRange:(NSRangePointer)aRangePtr
{
	if (anIndex >= [_attributedString length])
		return nil;
	return [_attributedString attributesAtIndex:anIndex effectiveRange:aRangePtr];
}

- (void)setAttributes:(NSDictionary *)attributes range:(NSRange)aRange
{
	[_attributedString setAttributes:attributes range:aRange];
	[self edited:NSTextStorageEditedAttributes range:aRange changeInLength:0];
}

#pragma mark -
#pragma mark Line number handling

- (NSInteger)locationForStartOfLine:(NSUInteger)lineNumber
                             length:(NSUInteger *)lengthPtr
                        contentsEnd:(NSUInteger *)eolPtr
{
	if (lineNumber == 0) {
		if (_lineCount == 0) {
			if (lengthPtr)
				*lengthPtr = 0;
			if (eolPtr)
				*eolPtr = 0;
			return 0;
		}
		lineNumber++;
	}

	/* Line numbers are 1-based. Line indexes are 0-based. */
	NSUInteger lineIndex = lineNumber - 1;

	if (lineIndex >= _lineCount)
		return -1LL;

	NSInteger location = 0, line = 0;

	/* Find the skip partition. */
	struct skip *skip;
	TAILQ_FOREACH(skip, &_skiphead, next) {
		if (line + skip->nlines > lineIndex)
			break;
		line += skip->nlines;
		location += skip->length;
	}

	if (skip == NULL)
		return -1LL;

	/* Find the line. */
	struct line *ln;
	TAILQ_FOREACH(ln, &skip->lines, next) {
		if (line++ == lineIndex)
			break;
		location += ln->length;
	}

	if (ln == NULL)
		return -1LL;

	if (lengthPtr)
		*lengthPtr = ln->length;
	if (eolPtr)
		*eolPtr = location + ln->eol;

	return location;
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
	TAILQ_FOREACH(skip, &_skiphead, next) {
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
	return _lineCount;
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

- (NSRange)rangeOfCharactersFromSet:(NSCharacterSet *)characterSet
                         atLocation:(NSUInteger)aLocation
                        acceptAfter:(BOOL)acceptAfter
{
	if (acceptAfter &&
	   (aLocation >= [self length] ||
	    ![characterSet characterIsMember:[[self string] characterAtIndex:aLocation]]) &&
	   aLocation > 0)
		aLocation--;

	if (aLocation >= [self length])
		return NSMakeRange(NSNotFound, 0);

	NSUInteger word_start = [self skipCharactersInSet:characterSet
					     fromLocation:aLocation
						 backward:YES];
	if (word_start < aLocation && ![characterSet characterIsMember:[[self string] characterAtIndex:word_start]])
		/* We skipped past our word range. Back up. */
		word_start += 1;

	NSUInteger word_end = [self skipCharactersInSet:characterSet
					   fromLocation:aLocation
					       backward:NO];
	if (word_end > word_start)
		return NSMakeRange(word_start, word_end - word_start);

	return NSMakeRange(NSNotFound, 0);
}

- (NSString *)pathAtLocation:(NSUInteger)aLocation
                       range:(NSRange *)returnRange
                 acceptAfter:(BOOL)acceptAfter
{
	NSMutableCharacterSet *pathSet = [NSMutableCharacterSet characterSetWithCharactersInString:@"_/-.:~"];
	[pathSet formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];

	NSRange range = [self rangeOfCharactersFromSet:pathSet
					    atLocation:aLocation
					   acceptAfter:acceptAfter];
	if (returnRange)
		*returnRange = range;
	if (range.location == NSNotFound)
		return nil;

	return [[self string] substringWithRange:range];
}

- (NSRange)rangeOfWordAtLocation:(NSUInteger)aLocation
                     acceptAfter:(BOOL)acceptAfter
                 extraCharacters:(NSString *)extraCharacters
{
	if (wordSet == nil) {
		wordSet = [NSMutableCharacterSet characterSetWithCharactersInString:@"_"];
		[wordSet formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
	}
	NSMutableCharacterSet *set = wordSet;

	if (extraCharacters) {
		set = [wordSet mutableCopy];
		[set formUnionWithCharacterSet:[NSCharacterSet characterSetWithCharactersInString:extraCharacters]];
	}

	return [self rangeOfCharactersFromSet:set
				   atLocation:aLocation
				  acceptAfter:acceptAfter];
}

- (NSRange)rangeOfWordAtLocation:(NSUInteger)aLocation
                     acceptAfter:(BOOL)acceptAfter
{
	return [self rangeOfWordAtLocation:aLocation
                               acceptAfter:acceptAfter
                           extraCharacters:nil];
}

- (NSString *)wordAtLocation:(NSUInteger)aLocation
                       range:(NSRange *)returnRange
                 acceptAfter:(BOOL)acceptAfter
	     extraCharacters:(NSString *)extraCharacters
{
	NSRange range = [self rangeOfWordAtLocation:aLocation
                                        acceptAfter:acceptAfter
                                    extraCharacters:extraCharacters];
	if (returnRange)
		*returnRange = range;
	if (range.location == NSNotFound)
		return nil;

	return [[self string] substringWithRange:range];
}

- (NSString *)wordAtLocation:(NSUInteger)aLocation
                       range:(NSRange *)returnRange
                 acceptAfter:(BOOL)acceptAfter
{
	return [self wordAtLocation:aLocation
                              range:returnRange
                        acceptAfter:acceptAfter
                    extraCharacters:nil];
}

- (NSString *)wordAtLocation:(NSUInteger)aLocation
                       range:(NSRange *)returnRange
{
	return [self wordAtLocation:aLocation range:returnRange acceptAfter:NO];
}

- (NSString *)wordAtLocation:(NSUInteger)aLocation
{
	return [self wordAtLocation:aLocation range:nil];
}

- (NSUInteger)columnOffsetAtLocation:(NSUInteger)aLocation
{
	if (aLocation > [self length])
		return 0;

	NSUInteger bol, end;
	[[self string] getLineStart:&bol end:&end contentsEnd:NULL forRange:NSMakeRange(aLocation, 0)];
	return aLocation - bol;
}

- (NSUInteger)columnAtLocation:(NSUInteger)aLocation
{
	if (aLocation > [self length])
		return 0;

	NSUInteger bol, end;
	[[self string] getLineStart:&bol end:&end contentsEnd:NULL forRange:NSMakeRange(aLocation, 0)];
	NSUInteger c = 0, i;
	NSInteger ts = [[NSUserDefaults standardUserDefaults] integerForKey:@"tabstop"];
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
	if (aLocation > [self length])
		return NSNotFound;

	NSUInteger bol, eol;
	[[self string] getLineStart:&bol end:NULL contentsEnd:&eol forRange:NSMakeRange(aLocation, 0)];
	NSUInteger c = 0, i;
	NSInteger ts = [[NSUserDefaults standardUserDefaults] integerForKey:@"tabstop"];
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

- (NSRange)rangeOfLineAtLocation:(NSUInteger)aLocation
{
	if (aLocation > [self length])
		return NSMakeRange(NSNotFound, 0);

	NSUInteger bol, eol;
	[[self string] getLineStart:&bol end:NULL contentsEnd:&eol forRange:NSMakeRange(aLocation, 0)];
	return NSMakeRange(bol, eol - bol);
}

- (NSString *)lineAtLocation:(NSUInteger)aLocation
{
	NSRange r = [self rangeOfLineAtLocation:aLocation];
	if (r.location == NSNotFound)
		return nil;
	return [[self string] substringWithRange:r];
}

- (NSString *)lineForLocation:(NSUInteger)aLocation
{
	return [self lineAtLocation:aLocation];
}

- (NSRange)rangeOfLine:(NSUInteger)lineNumber
{
	NSRange r = NSMakeRange(NSNotFound, 0);
	NSUInteger eol;
	r.location = [self locationForStartOfLine:lineNumber length:NULL contentsEnd:&eol];
    if (r.location != -1) {
        r.length = eol - r.location;
    }
	return r;
}

- (NSString *)line:(NSUInteger)lineNumber
{
	NSRange r = [self rangeOfLine:lineNumber];
	if (r.location == -1LL)
		return nil;
	return [[self string] substringWithRange:r];
}

- (BOOL)isBlankLineAtLocation:(NSUInteger)aLocation
{
	NSRange r = [self rangeOfLineAtLocation:aLocation];
	if (r.location == NSNotFound)
		return YES;

	if (r.length == 0)
		return YES;

	NSCharacterSet *cset = [[NSCharacterSet whitespaceCharacterSet] invertedSet];
	return [[self string] rangeOfCharacterFromSet:cset
					      options:NSLiteralSearch
						range:r].location == NSNotFound;
}

- (NSRange)rangeOfLeadingWhitespaceForLineAtLocation:(NSUInteger)aLocation
{
	if (aLocation > [self length])
		return NSMakeRange(NSNotFound, 0);

	NSUInteger bol, eol;
	[[self string] getLineStart:&bol
				end:NULL
		        contentsEnd:&eol
			   forRange:NSMakeRange(aLocation, 0)];
	NSRange lineRange = NSMakeRange(bol, eol - bol);

	NSCharacterSet *cset = [[NSCharacterSet whitespaceCharacterSet] invertedSet];
	NSRange r = [[self string] rangeOfCharacterFromSet:cset
						   options:0
						     range:lineRange];

	if (r.location == NSNotFound)
		r.location = eol;

	return NSMakeRange(lineRange.location, r.location - lineRange.location);
}

- (NSString *)leadingWhitespaceForLineAtLocation:(NSUInteger)aLocation
{
	NSRange r = [self rangeOfLeadingWhitespaceForLineAtLocation:aLocation];
	if (r.location == NSNotFound)
		return nil;
	return [[self string] substringWithRange:r];
}

- (NSUInteger)firstNonBlankForLineAtLocation:(NSUInteger)aLocation
{
	if (aLocation > [self length])
		return NSNotFound;

	NSUInteger bol, eol;
	[[self string] getLineStart:&bol end:NULL contentsEnd:&eol forRange:NSMakeRange(aLocation, 0)];
	NSRange lineRange = NSMakeRange(bol, eol - bol);

	NSCharacterSet *cset = [[NSCharacterSet whitespaceCharacterSet] invertedSet];
	NSRange r = [[self string] rangeOfCharacterFromSet:cset options:0 range:lineRange];

	if (r.location == NSNotFound)
		return eol;
	return r.location;
}

- (void)fixAttachmentAttributeInRange:(NSRange)aRange
{
	// Do nothing; we actually *want* to be able to do attachments on
	// characters other than attachment characters, so we make this
	// function a no-op. This lets us keep the same string but display
	// a fold image.
}


@end

