#import "ViRegexp.h"
#import "ViError.h"
#import "logging.h"

@implementation ViRegexp

+ (BOOL)shouldIgnoreCaseForString:(NSString *)string
{
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	return ([defs integerForKey:@"ignorecase"] == NSOnState &&
	       ([defs integerForKey:@"smartcase"] == NSOffState ||
		[string rangeOfCharacterFromSet:[NSCharacterSet uppercaseLetterCharacterSet]].location == NSNotFound));
}

+ (int)defaultOptionsForString:(NSString *)string
{
	if ([self shouldIgnoreCaseForString:string])
		return ONIG_OPTION_IGNORECASE;
	return 0;
}

+ (NSCharacterSet *)reservedCharacters
{
	static NSCharacterSet *__reservedCharacters = nil;
	if (__reservedCharacters == nil)
		__reservedCharacters = [[NSCharacterSet characterSetWithCharactersInString:@".{[()|\\+?*^$"] retain];
	return __reservedCharacters;
}

+ (BOOL)needEscape:(unichar)ch
{
	return [[self reservedCharacters] characterIsMember:ch];
}

+ (NSString *)escape:(NSString *)string inRange:(NSRange)range
{
	NSMutableString *s = [NSMutableString string];
	for (NSUInteger i = 0; i < [string length]; i++) {
		unichar ch = [string characterAtIndex:i];
		if (NSLocationInRange(i, range) && [self needEscape:ch])
			[s appendString:@"\\"];
		[s appendFormat:@"%C", ch];
	}
	return s;
}

+ (NSString *)escape:(NSString *)string
{
	return [self escape:string inRange:NSMakeRange(0, [string length])];
}

+ (ViRegexp *)regexpWithString:(NSString *)aString
{
	return [[[ViRegexp alloc] initWithString:aString] autorelease];
}

+ (ViRegexp *)regexpWithString:(NSString *)aString options:(int)options
{
	return [[[ViRegexp alloc] initWithString:aString options:options] autorelease];
}

+ (ViRegexp *)regexpWithString:(NSString *)aString options:(int)options error:(NSError **)outError
{
	return [[[ViRegexp alloc] initWithString:aString options:options error:outError] autorelease];
}

- (ViRegexp *)initWithString:(NSString *)aString
{
	return [self initWithString:aString options:0 error:nil];
}

- (ViRegexp *)initWithString:(NSString *)aString
                    options:(int)options
{
	return [self initWithString:aString options:options error:nil];
}

- (ViRegexp *)initWithString:(NSString *)aString
                     options:(int)options
                       error:(NSError **)outError
{
	self = [super init];
	if (self == nil)
		return nil;

	_pattern = [aString retain]; // XXX: should copy, but we use it only for -description:

	size_t len = [aString length] * sizeof(unichar);
	unichar *pattern = malloc(len);
	[aString getCharacters:pattern];

	OnigEncoding enc;
#if defined(__BIG_ENDIAN__)
	enc = ONIG_ENCODING_UTF16_BE;
#else
	enc = ONIG_ENCODING_UTF16_LE;
#endif
	OnigErrorInfo einfo;
	int r = onig_new(&_regex, (const UChar *)pattern,
	    (const UChar *)pattern + len, options | ONIG_OPTION_CAPTURE_GROUP,
	    enc, ONIG_SYNTAX_RUBY, &einfo);
	free(pattern);
	if (r != ONIG_NORMAL) {
		if (outError) {
			unsigned char s[ONIG_MAX_ERROR_MESSAGE_LEN];
			onig_error_code_to_str(s, r, &einfo);
			DEBUG(@"pattern failed: %s", s);
			*outError = [ViError errorWithFormat:@"%s", s];
		}
		return nil;
	}

	return self;
}

- (void)dealloc
{
	if (_regex)
		onig_free(_regex);
	[_pattern release];
	[super dealloc];
}

- (void)finalize
{
	if (_regex)
		onig_free(_regex);
	[super finalize];
}

- (ViRegexpMatch *)matchInCharacters:(const unichar *)chars
                             options:(int)options
                               range:(NSRange)aRange
                               start:(NSUInteger)aLocation
{
	OnigRegion *region = onig_region_new();

	const unsigned char *str = (const unsigned char *)chars;
	const unsigned char *start = str + aRange.location * sizeof(unichar);
	const unsigned char *end = start + aRange.length * sizeof(unichar);

	int r = onig_search(_regex, str, end, start, end, region,
	    ONIG_OPTION_FIND_NOT_EMPTY | options);
	if (r >= 0)
		return [ViRegexpMatch regexpMatchWithRegion:region
					      startLocation:aLocation];
	onig_region_free(region, 1);
	return nil;
}

- (ViRegexpMatch *)matchInCharacters:(const unichar *)chars
                               range:(NSRange)aRange
                               start:(NSUInteger)aLocation
{
	return [self matchInCharacters:chars
			       options:0
				 range:aRange
				 start:aLocation];
}

- (ViRegexpMatch *)matchInString:(NSString *)aString range:(NSRange)aRange options:(int)options
{
	unichar *chars = malloc(aRange.length * sizeof(unichar));
	[aString getCharacters:chars range:aRange];
	ViRegexpMatch *match = [self matchInCharacters:chars
					       options:options
	                                         range:NSMakeRange(0, aRange.length)
	                                         start:aRange.location];

	free(chars);
	return match;
}

- (ViRegexpMatch *)matchInString:(NSString *)aString range:(NSRange)aRange
{
	return [self matchInString:aString range:aRange options:0];
}

- (ViRegexpMatch *)matchInString:(NSString *)aString
{
	return [self matchInString:aString
			     range:NSMakeRange(0, [aString length])];
}

- (BOOL)matchesString:(NSString *)aString
{
	return [self matchInString:aString
			     range:NSMakeRange(0, [aString length])] != nil;
}

- (NSArray *)allMatchesInCharacters:(const unichar *)chars
                            options:(int)options
                              range:(NSRange)aRange
                              start:(NSUInteger)aLocation
{
	NSMutableArray *matches = nil;

	NSRange range = aRange;
	while (range.location <= NSMaxRange(aRange)) {
		ViRegexpMatch *match = [self matchInCharacters:chars
						       options:options
							 range:range
							 start:aLocation];
		if (match == nil)
			break;

		if (matches == nil)
			matches = [NSMutableArray array];
		[matches addObject:match];

		NSRange r = [match rangeOfMatchedString];
		range.location = r.location + 1 - aLocation;
		range.length = NSMaxRange(aRange) - range.location;
	}

	return matches;
}

- (NSArray *)allMatchesInCharacters:(const unichar *)chars
                              range:(NSRange)aRange
                              start:(NSUInteger)aLocation
{
	return [self allMatchesInCharacters:chars
				    options:0
				      range:aRange
				      start:aLocation];
}

- (NSArray *)allMatchesInString:(NSString *)aString
                        options:(int)options
                          range:(NSRange)aRange
{
	unichar *chars = malloc(aRange.length * sizeof(unichar));
	[aString getCharacters:chars range:aRange];
	NSArray *matches = [self allMatchesInCharacters:chars
						options:options
						  range:NSMakeRange(0, aRange.length)
						  start:aRange.location];
	free(chars);
	return matches;
}

- (NSArray *)allMatchesInString:(NSString *)aString
                        options:(int)options
{
	return [self allMatchesInString:aString
				options:0
				  range:NSMakeRange(0, [aString length])];
}

- (NSArray *)allMatchesInString:(NSString *)aString
                          range:(NSRange)aRange
{
	return [self allMatchesInString:aString
				options:0
				  range:aRange];
}

- (NSArray *)allMatchesInString:(NSString *)aString
                          range:(NSRange)aRange
                          start:(NSUInteger)aLocation
{
	return [self allMatchesInString:aString
				  range:aRange];
}

- (NSArray *)allMatchesInString:(NSString *)aString
{
	return [self allMatchesInString:aString
				options:0
				  range:NSMakeRange(0, [aString length])];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViRegexp: /%@/>", _pattern];
}

@end

@implementation ViRegexpMatch

@synthesize startLocation;

+ (ViRegexpMatch *)regexpMatchWithRegion:(OnigRegion *)aRegion
                           startLocation:(NSUInteger)aLocation
{
	return [[[ViRegexpMatch alloc] initWithRegion:aRegion
					startLocation:aLocation] autorelease];
}

- (ViRegexpMatch *)initWithRegion:(OnigRegion *)aRegion
                    startLocation:(NSUInteger)aLocation
{
	if ((self = [super init]) != nil) {
		startLocation = aLocation;
		_region = aRegion;
	}
	return self;
}

- (NSRange)rangeOfMatchedString
{
	return [self rangeOfSubstringAtIndex:0];
}

- (NSRange)rangeOfSubstringAtIndex:(NSUInteger)idx
{
	if (idx >= _region->num_regs || _region->beg[idx] == -1)
		return NSMakeRange(NSNotFound, 0);

	return NSMakeRange(startLocation + (_region->beg[idx] / sizeof(unichar)),
	                   (_region->end[idx] - _region->beg[idx]) / sizeof(unichar));
}

- (NSUInteger)count
{
	return _region->num_regs;
}

- (void)dealloc
{
	if (_region)
		onig_region_free(_region, 1);
	[super dealloc];
}

- (void)finalize
{
	if (_region)
		onig_region_free(_region, 1);
	[super finalize];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViRegexpMatch %@, %lu captures>",
	    NSStringFromRange([self rangeOfMatchedString]), [self count]];
}

@end

