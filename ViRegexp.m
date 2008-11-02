#import "ViRegexp.h"
#import "logging.h"

@implementation ViRegexp

+ (ViRegexp *)regularExpressionWithString:(NSString *)aString
{
	return [[ViRegexp alloc] initWithString:aString];
}

- (ViRegexp *)initWithString:(NSString *)aString
{
	self = [super init];

	// INFO(@"initializing regexp with string [%@]", aString);

	size_t len = [aString length] * sizeof(unichar);
	unichar *pattern = malloc(len);
	[aString getCharacters:pattern];

	// const UChar *pattern = (const UChar *)CFStringGetCharactersPtr((CFStringRef)aString);
	// size_t len  = CFStringGetLength((CFStringRef)aString) * 2;
	OnigEncoding enc;
#if defined(__BIG_ENDIAN__)
	enc = ONIG_ENCODING_UTF16_BE;
#else
	enc = ONIG_ENCODING_UTF16_LE;
#endif
	OnigErrorInfo einfo;
	int r = onig_new(&regex, (const UChar *)pattern, (const UChar *)pattern + len, ONIG_OPTION_CAPTURE_GROUP, enc, ONIG_SYNTAX_RUBY, &einfo);
	if (r != ONIG_NORMAL)
	{
		unsigned char s[ONIG_MAX_ERROR_MESSAGE_LEN];
		onig_error_code_to_str(s, r, &einfo);
		INFO(@"pattern failed: %s", s);
		free(pattern);
		return nil;
	}

	free(pattern);
	return self;
}

- (void)finalize
{
	if (regex)
	{
		onig_free(regex);
	}
	[super finalize];
}

- (ViRegexpMatch *)matchInString:(NSString *)aString range:(NSRange)aRange
{
	OnigRegion *region = onig_region_new();

	// INFO(@"matching string in range %u + %u", aRange.location, aRange.length);

	/* if ([aString fastestEncoding] != 30) */
		/* INFO(@"fastest encoding = %u (expecting 0x%08X)", [aString fastestEncoding], NSUTF16LittleEndianStringEncoding); */

	size_t len = aRange.length * sizeof(unichar);
	const UChar *start = malloc(len);
	[aString getCharacters:(unichar *)start range:aRange];

	// const UChar *start = (const UChar *)CFStringGetCharactersPtr((CFStringRef)aString);
	// size_t len = aRange.length * 2;
	const UChar *end = start + len;

	int r = onig_search(regex, start, end, start, end, region, ONIG_OPTION_FIND_NOT_EMPTY);
	if (r >= 0)
		return [ViRegexpMatch regexpMatchWithString:aString region:region startLocation:aRange.location];

	return nil;
}

- (ViRegexpMatch *)matchInString:(NSString *)aString
{
	return [self matchInString:aString range:NSMakeRange(0, [aString length])];
}

- (NSArray *)allMatchesInString:(NSString *)aString range:(NSRange)aRange
{
	NSMutableArray *matches = nil;

	NSRange range = aRange;
	while (range.location < NSMaxRange(aRange))
	{
		ViRegexpMatch *match = [self matchInString:aString range:range];
		if (match == nil)
			break;

		if (matches == nil)
			matches = [[NSMutableArray alloc] init];

		[matches addObject:match];

		NSRange r = [match rangeOfMatchedString];
		if (r.length == 0)
			r.length = 1;
		range.location += r.length;
		range.length -= r.length;
	}

	return matches;
}

@end

@implementation ViRegexpMatch

+ (ViRegexpMatch *)regexpMatchWithString:(NSString *)aString region:(OnigRegion *)aRegion startLocation:(NSUInteger)aLocation
{
	return [[ViRegexpMatch alloc] initWithString:aString region:aRegion startLocation:aLocation];
}

- (ViRegexpMatch *)initWithString:(NSString *)aString region:(OnigRegion *)aRegion startLocation:(NSUInteger)aLocation
{
	self = [super init];
	startLocation = aLocation;
	region = aRegion;
	return self;
}

- (NSRange)rangeOfMatchedString
{
	return [self rangeOfSubstringAtIndex:0];
}

- (NSRange)rangeOfSubstringAtIndex:(unsigned)idx
{
	if ((idx >= region->num_regs) || (region->beg[idx] == -1))
		return NSMakeRange(NSNotFound, 0);

	return NSMakeRange(startLocation + (region->beg[idx] / sizeof(unichar)), (region->end[idx] - region->beg[idx]) / sizeof(unichar));
}

@end

