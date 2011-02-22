#include <sys/types.h>
#include <sys/stat.h>
#include "sys_queue.h"

#import "ViSnippet.h"
#import "ViBundle.h"
#import "ViError.h"
#import "NSScanner-additions.h"
#import "logging.h"

@interface ViTabstop : NSObject
{
	int num;
	NSUInteger baseLocation;
	NSMutableArray *ranges;
	NSMutableString *value;
	ViTabstop *parent;
}
@property(readwrite) int num;
@property(readwrite) NSUInteger baseLocation;
@property(readwrite) ViTabstop *parent;
@property(readonly) NSMutableArray *ranges;
@property(readwrite, assign) NSMutableString *value;
@end


@implementation ViTabstop
@synthesize num, baseLocation, parent, ranges, value;
- (ViTabstop *)init
{
	if ((self = [super init]) != NULL) {
		ranges = [[NSMutableArray alloc] init];
	}
	return self;
}
- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViTabstop %i@%lu: %@, parent: %@, ranges: %@>", num, baseLocation, value, parent, ranges];
}
@end

@interface ViSnippet (private)
- (void)updateTabstops:(NSArray *)tsArray fromLocation:(NSUInteger)location withChangeInLength:(NSInteger)delta;
- (void)updateTabstops:(NSArray *)tsArray;
@end

@implementation ViSnippet

@synthesize string;
@synthesize range;
@synthesize selectedRange;
@synthesize caret;

- (NSString *)runShellCommand:(NSString *)shellCommand error:(NSError **)outError
{
	DEBUG(@"shell command = [%@]", shellCommand);

	if ([shellCommand length] == 0)
		return @"";

	NSString *inputText = @"";
	NSTask *task = [[NSTask alloc] init];
	char *templateFilename = NULL;
	int fd = -1;

	if ([shellCommand hasPrefix:@"#!"]) {
		const char *tmpl = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"vibrant_cmd.XXXXXXXXXX"] fileSystemRepresentation];
		templateFilename = strdup(tmpl);
		fd = mkstemp(templateFilename);
		DEBUG(@"using template %s", templateFilename);
		if (fd == -1) {
			if (outError)
				*outError = [ViError errorWithFormat:@"Failed to open temporary file: %s", strerror(errno)];
			return NO;
		}
		const char *data = [shellCommand UTF8String];
		ssize_t rc = write(fd, data, strlen(data));
		DEBUG(@"wrote %i byte", rc);
		if (rc == -1) {
			if (outError)
				*outError = [ViError errorWithFormat:@"Failed to save temporary command file: %s", strerror(errno)];
			unlink(templateFilename);
			close(fd);
			free(templateFilename);
			return NO;
		}
		chmod(templateFilename, 0700);
		shellCommand = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:templateFilename length:strlen(templateFilename)];
	}

	if (templateFilename)
		[task setLaunchPath:shellCommand];
	else {
		[task setLaunchPath:@"/bin/bash"];
		[task setArguments:[NSArray arrayWithObjects:@"-c", shellCommand, nil]];
	}

	NSPipe *shellInput = [NSPipe pipe];
	NSPipe *shellOutput = [NSPipe pipe];

	[task setStandardInput:shellInput];
	[task setStandardOutput:shellOutput];
	[task setStandardError:shellOutput];
	[task setEnvironment:environment];

	[task launch];
	[[shellInput fileHandleForWriting] writeData:[inputText dataUsingEncoding:NSUTF8StringEncoding]];
	[[shellInput fileHandleForWriting] closeFile];
	[task waitUntilExit];
	int status = [task terminationStatus];

	if (status != 0)
		DEBUG(@"%@: exited with status %i", shellCommand, status);

	NSData *outputData = [[shellOutput fileHandleForReading] readDataToEndOfFile];
	NSMutableString *outputText = [[NSMutableString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];

	if ([outputText length] > 0)
		[outputText replaceOccurrencesOfString:@"\n" withString:@"" options:0 range:NSMakeRange([outputText length] - 1, 1)];

	if (fd != -1) {
		unlink(templateFilename);
		close(fd);
		free(templateFilename);
	}

	DEBUG(@"output is [%@]", outputText);
	return outputText;
}

- (void)sortTabstops:(NSMutableArray *)tsArray
{
	[tsArray sortUsingComparator:^(id obj1, id obj2) {
		ViTabstop *a = obj1;
		ViTabstop *b = obj2;
		if (a.num == 0) {
			if (b.num == 0)
				return (NSComparisonResult)NSOrderedSame;
			return (NSComparisonResult)NSOrderedDescending;
		} else if (b.num == 0)
			return (NSComparisonResult)NSOrderedAscending;
		if (a.num < b.num)
			return (NSComparisonResult)NSOrderedAscending;
		else if (a.num > b.num)
			return (NSComparisonResult)NSOrderedDescending;
		return (NSComparisonResult)NSOrderedSame;
	}];
}

- (NSMutableString *)parseString:(NSString *)aString
                     stopAtBrace:(BOOL)stopAtBrace
                   allowTabstops:(BOOL)allowTabstops
                    baseLocation:(NSUInteger)baseLocation
                   scannedLength:(NSUInteger *)scannedLength
                           error:(NSError **)outError
{
	NSString *variable, *value;
	NSMutableString *defaultValue;
	NSScanner *scan;
	NSMutableString *s = [NSMutableString string];
	NSString *regexp, *format, *options;
	unichar ch;

	scan = [NSScanner scannerWithString:aString];
	[scan setCharactersToBeSkipped:nil];

	while ([scan scanCharacter:&ch]) {
		if (ch == '\\') {
			/* Skip the backslash escape if it's followed by a reserved character. */
			if ([scan scanCharacter:&ch]) {
				/* The TextMate escaping rules are totally insane! */
				if (ch != '$' && ch != '`' && ch != '\\' && (!stopAtBrace || ch != '}'))
					[s appendString:@"\\"];
				[s appendFormat:@"%C", ch];
			} else
				[s appendString:@"\\"];
		} else if (ch == '$') {
			BOOL bracedExpression = [scan scanString:@"{" intoString:nil];
			NSInteger tabStop = -1;
			ViTabstop *ts = nil;
			if (allowTabstops && [scan scanInteger:&tabStop]) {
				/*
				 * Tab Stop.
				 */
				if (tabStop < 0) {
					if (outError)
						*outError = [ViError errorWithFormat:@"Negative tab stop number %li", tabStop];
					return NO;
				}
				value = nil;
				DEBUG(@"got tab stop %li at %lu", tabStop, [s length]);
				for (ts in tabstops)
					if (ts.num == tabStop)
						break;
				if (ts == nil) {
					ts = [[ViTabstop alloc] init];
					ts.num = tabStop;
					ts.baseLocation = baseLocation;
					[tabstops addObject:ts];
				} else {
					DEBUG(@"already got tab stop %i at %@", ts.num, NSStringFromRange([[ts.ranges objectAtIndex:0] rangeValue]));
				}
				[ts.ranges addObject:[NSValue valueWithRange:NSMakeRange([s length], 0)]];
			} else if ([scan scanShellVariableIntoString:&variable]) {
				/*
				 * Regular shell variable.
				 */
				value = [environment objectForKey:variable];
				DEBUG(@"got variable [%@] = [%@]", variable, value);
			} else {
				if (outError)
					*outError = [ViError errorWithFormat:@"Invalid shell variable name at character %lu", [scan scanLocation] + 1];
				return NO;
			}

			regexp = nil;
			format = nil;
			options = nil;
			defaultValue = nil;
			if (bracedExpression) {
				if ([scan scanString:@":" intoString:nil]) {
					/*
					 * Got a default value.
					 */
					NSString *substring = [aString substringFromIndex:[scan scanLocation]];
					NSUInteger len;
					defaultValue = [self parseString:substring
					                     stopAtBrace:YES
					                   allowTabstops:ts ? YES : NO
					                    baseLocation:baseLocation + [s length]
					                   scannedLength:&len
					                           error:outError];
					if (!defaultValue)
						return NO;
					DEBUG(@"nested parse scanned %lu characters and returned [%@]", len, defaultValue);
					[scan setScanLocation:[scan scanLocation] + len];
				} else if ([scan scanString:@"/" intoString:nil]) {
					/*
					 * Regexp replacement.
					 */
					if (![scan scanUpToUnescapedCharacter:'/' intoString:&regexp] ||
					    ![scan scanString:@"/" intoString:nil] ||
					    ![scan scanUpToUnescapedCharacter:'/' intoString:&format] ||
					    ![scan scanString:@"/" intoString:nil]) {
						if (outError)
							*outError = [ViError errorWithFormat:@"Missing separating slash at %lu",
							    [scan scanLocation] + 1];
						return NO;
					}
					[scan scanUpToString:@"}" intoString:&options];
					if (options == nil)
						options = @"";
					DEBUG(@"regexp = %@", regexp);
					DEBUG(@"format = %@", format);
					DEBUG(@"options = %@", options);

					ViRegexp *rx = [[ViRegexp alloc] initWithString:regexp options:0 syntax:0 error:outError];
					if (rx == nil)
						return NO;
					if (value == nil)
						value = @"";

					NSMutableString *text = [value mutableCopy];
					NSArray *matches = [rx allMatchesInString:value];
					NSInteger delta = 0;
					for (ViRegexpMatch *m in matches) {
						NSRange r = [m rangeOfMatchedString];
						DEBUG(@"/%@/ matched range %@ in string [%@]", regexp, NSStringFromRange(r), value);
						NSString *matchedText = [value substringWithRange:r];
						r.location += delta;
						delta += [format length] - r.length;
						[text replaceCharactersInRange:r withString:format];
						NSUInteger capture, nrep;
						for (capture = 0; capture < [m count] && capture < 10; capture++) {
							r = [m rangeOfSubstringAtIndex:capture];
							NSString *captureString = [NSString stringWithFormat:@"$%lu", capture];
							nrep = [text replaceOccurrencesOfString:captureString
							                             withString:[value substringWithRange:r]
							                                options:0
							                                  range:NSMakeRange(0, [text length])];
							delta += nrep * ([matchedText length] - [captureString length]);
						}
						if ([options rangeOfString:@"g"].location == NSNotFound)
							break;
					}
					DEBUG(@"transformed [%@] -> [%@]", value, text);
					value = text;
				}

				if (![scan scanString:@"}" intoString:nil]) {
					if (outError)
						*outError = [ViError errorWithFormat:@"Missing closing brace at %lu",
						    [scan scanLocation] + 1];
					return NO;
				}
			}
			if (ts != nil) {
				DEBUG(@"ts.value = [%@], value = [%@], defaultValue = [%@]", ts.value, value, defaultValue);
				if (ts.value == nil && defaultValue) {
					ts.value = defaultValue;
					// move the tabrange to the head of the list of ranges
					// this is where the caret will be placed
					if ([ts.ranges count] > 0) {
						NSValue *v = [ts.ranges lastObject];
						[ts.ranges removeLastObject];
						[ts.ranges insertObject:v atIndex:0];
					}
				}
			} else if (value == nil)
				value = defaultValue;
			if (value)
				[s appendString:value];
		} else if (ch == '`') {
			NSString *shellCommand;
			NSUInteger startLocation = [scan scanLocation];
			if (![scan scanUpToUnescapedCharacter:'`' intoString:&shellCommand] ||
			    ![scan scanString:@"`" intoString:nil]) {
				if (outError)
					*outError = [ViError errorWithFormat:@"Unterminated shell command beginning at character %lu", startLocation + 1];
				return NO;
			}
			NSString *output = [self runShellCommand:shellCommand error:outError];
			if (output == nil)
				return NO;
			[s appendString:output];
		} else if (ch == '}' && stopAtBrace) {
			[scan setScanLocation:[scan scanLocation] - 1];
			break;
		} else {
			[s appendFormat:@"%C", ch];
		}
	}

	*scannedLength = [scan scanLocation];
	return s;
}

- (ViSnippet *)initWithString:(NSString *)aString
                   atLocation:(NSUInteger)aLocation
                  environment:(NSDictionary *)env
                        error:(NSError **)outError
{
	self = [super init];
	if (self == nil)
		return nil;

	environment = env;
	tabstops = [[NSMutableArray alloc] init];

	DEBUG(@"snippet string = %@ at location %llu", aString, aLocation);

	NSUInteger len;
	string = [self parseString:aString stopAtBrace:NO allowTabstops:YES baseLocation:0 scannedLength:&len error:outError];
	if (!string)
		return nil;
	DEBUG(@"scanned %lu chars", len);

	if (len != [aString length]) {
		DEBUG(@"whole string not parsed? length = %lu, i = %lu", [aString length], len);
		return nil;
	}

	beginLocation = aLocation;
	range = NSMakeRange(beginLocation, [string length]);

	DEBUG(@"string = [%@]", string);
	DEBUG(@"tabstops = %@", tabstops);

	[self sortTabstops:tabstops];
	[self updateTabstops:tabstops];

	if ([tabstops count] == 0)
		caret = NSMaxRange(range);
	else {
		currentTabIndex = 0;
		currentTabStop = [tabstops objectAtIndex:0];
		NSRange r = [[currentTabStop.ranges objectAtIndex:0] rangeValue];
		caret = beginLocation + currentTabStop.baseLocation + r.location;
		selectedRange = NSMakeRange(caret, r.length);
	}

	return self;
}

- (void)deselect
{
	DEBUG(@"deselecting tab range %@", NSStringFromRange(selectedRange));
	selectedRange = NSMakeRange(NSNotFound, 0);
}

- (BOOL)advance
{
	if (++currentTabIndex >= [tabstops count]) {
		currentTabStop = NULL;
		return NO;
	}
	currentTabStop = [tabstops objectAtIndex:currentTabIndex];
	NSRange r = [[currentTabStop.ranges objectAtIndex:0] rangeValue];
	caret = beginLocation + currentTabStop.baseLocation + r.location;
	selectedRange = NSMakeRange(caret, r.length);
	return YES;
}

- (NSRange)tabRange
{
	if (currentTabStop == NULL)
		return NSMakeRange(NSNotFound, 0);
	NSRange r = [[currentTabStop.ranges objectAtIndex:0] rangeValue];
	return NSMakeRange(beginLocation + currentTabStop.baseLocation + r.location, r.length);
}

- (void)updateTabstops:(NSArray *)tsArray fromLocation:(NSUInteger)location withChangeInLength:(NSInteger)delta
{
	DEBUG(@"update tabstops from location %lu with change %li", location, delta);

	for (ViTabstop *ts in tsArray) {
		NSUInteger i;
		for (i = 0; i < [ts.ranges count]; i++) {
			NSRange r = [[ts.ranges objectAtIndex:i] rangeValue];
			if (r.location > location)
				r.location += delta;
			else if (NSMaxRange(r) >= location)
				r.length += delta;
			DEBUG(@"tabstop %u range %@ -> %@", ts.num, NSStringFromRange([[ts.ranges objectAtIndex:i] rangeValue]), NSStringFromRange(r));
			[ts.ranges replaceObjectAtIndex:i withObject:[NSValue valueWithRange:r]];
		}
	}

	range.length += delta;
	DEBUG(@"snippet range -> %@", NSStringFromRange(range));
}

- (void)updateTabstops:(NSArray *)tsArray
{
	for (ViTabstop *ts in tsArray) {
		NSUInteger i;
		for (i = 0; i < [ts.ranges count]; i++) {
			if (ts.value) {
				NSRange r = [[ts.ranges objectAtIndex:i] rangeValue];
				r.location += ts.baseLocation;
				DEBUG(@"update tab stop %i range %@ with value [%@]", ts.num, NSStringFromRange(r), ts.value);
				[string replaceCharactersInRange:r withString:ts.value];
				r.location -= ts.baseLocation;
				DEBUG(@"string -> [%@]", string);
				NSInteger delta = [ts.value length] - r.length;
				[self updateTabstops:tabstops fromLocation:r.location withChangeInLength:delta];
			}
		}
	}
}

- (BOOL)replaceRange:(NSRange)updateRange withString:(NSString *)replacementString
{
	[self deselect];

	if (currentTabStop == nil) {
		DEBUG(@"%s", "current tab stop is nil");
		return NO;
	}

	NSRange normalizedRange = updateRange;
	normalizedRange.location -= beginLocation;

	DEBUG(@"replace range %@ with [%@]", NSStringFromRange(normalizedRange), replacementString);

	NSRange r = [[currentTabStop.ranges objectAtIndex:0] rangeValue];
	if (normalizedRange.location < r.location ||
	    normalizedRange.location > NSMaxRange(r) ||
	    NSMaxRange(normalizedRange) > NSMaxRange(r)) {
		DEBUG(@"update range %@ outside current tabstop %@", NSStringFromRange(normalizedRange), NSStringFromRange(r));
		return NO;
	}

	normalizedRange.location -= r.location;
	if (currentTabStop.value == nil)
		currentTabStop.value = [NSMutableString string];
	[currentTabStop.value replaceCharactersInRange:normalizedRange withString:replacementString];
	[self updateTabstops:tabstops];

	return YES;
}

- (BOOL)activeInRange:(NSRange)aRange
{
	if (NSIntersectionRange(aRange, range).length > 0 || aRange.location == NSMaxRange(range))
		return YES;
	return NO;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViSnippet at %@>", NSStringFromRange(range)];
}

@end
