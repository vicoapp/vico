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
	NSRange range;
	NSUInteger index;
	NSMutableString *value;
	ViTabstop *parent;
	ViTabstop *mirror;
	ViRegexp *rx;
	NSString *format;
	NSString *options;
	NSString *filter;
}
@property(readwrite) int num;
@property(readwrite) NSUInteger index;
@property(readwrite) NSRange range;
@property(readwrite) ViTabstop *parent;
@property(readwrite) ViTabstop *mirror;
@property(readwrite) ViRegexp *rx;
@property(readwrite, assign) NSString *format;
@property(readwrite, assign) NSString *options;
@property(readwrite, assign) NSString *filter;
@property(readwrite, assign) NSMutableString *value;
@end


@implementation ViTabstop
@synthesize num, parent, mirror, range, value, rx, format, options, filter, index;
- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViTabstop %i@%@: [%@], pipe: [%@], parent: %@, mirror of: %@>",
	    num, NSStringFromRange(range), value, filter, parent, mirror];
}
@end

@interface ViSnippet (private)
- (BOOL)updateTabstopsError:(NSError **)outError;
- (void)removeNestedIn:(ViTabstop *)parent;
- (NSUInteger)parentLocation:(ViTabstop *)ts;
@end

@implementation ViSnippet

@synthesize range;
@synthesize selectedRange;
@synthesize caret;

- (NSMutableString *)runShellCommand:(NSString *)shellCommand
                           withInput:(NSString *)inputText
                               error:(NSError **)outError
{
	DEBUG(@"shell command = [%@]", shellCommand);

	if ([shellCommand length] == 0)
		return [NSMutableString stringWithString:@""];

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

	NSMutableDictionary *env = [environment mutableCopy];
	for (ViTabstop *ts in tabstops) {
		if (ts.mirror == nil)
			[env setObject:(ts.value ?: @"") forKey:[NSString stringWithFormat:@"TM_TABSTOP_%i", ts.num]];
	}
	[env setObject:([self string] ?: @"") forKey:@"TM_SNIPPET"];
	DEBUG(@"shell environment is %@", env);
	[task setEnvironment:env];

	[task launch];
	[[shellInput fileHandleForWriting] writeData:[inputText dataUsingEncoding:NSUTF8StringEncoding]];
	[[shellInput fileHandleForWriting] closeFile];
	[task waitUntilExit];
	int status = [task terminationStatus];

	if (status != 0)
		DEBUG(@"%@: exited with status %i", shellCommand, status);

	NSData *outputData = [[shellOutput fileHandleForReading] readDataToEndOfFile];
	NSMutableString *outputText = [[NSMutableString alloc] initWithData:outputData
	                                                           encoding:NSUTF8StringEncoding];

	if ([outputText length] > 0)
		[outputText replaceOccurrencesOfString:@"\n"
		                            withString:@""
		                               options:0
		                                 range:NSMakeRange([outputText length] - 1, 1)];

	if (fd != -1) {
		unlink(templateFilename);
		close(fd);
		free(templateFilename);
	}

	DEBUG(@"output is [%@]", outputText);
	return outputText;
}

- (NSMutableString *)parseString:(NSString *)aString
                       stopChars:(NSString *)stopChars
                   parentTabstop:(ViTabstop *)parentTabstop
                   allowTabstops:(BOOL)allowTabstops
                   scannedLength:(NSUInteger *)scannedLength
                           error:(NSError **)outError
{
	NSString *variable, *value;
	NSMutableString *defaultValue;
	NSScanner *scan;
	NSMutableString *s = [NSMutableString string];
	NSString *regexp, *format, *options, *filter;
	unichar ch;

	scan = [NSScanner scannerWithString:aString];
	[scan setCharactersToBeSkipped:nil];

	while ([scan scanCharacter:&ch]) {
		if (ch == '\\') {
			/* Skip the backslash escape if it's followed by a reserved character. */
			if ([scan scanCharacter:&ch]) {
				/* The TextMate escaping rules are totally insane! */
				NSString *insChar = [NSString stringWithFormat:@"%C", ch];
				if (ch != '$' && ch != '`' && ch != '\\' &&
				    [stopChars rangeOfString:insChar].location == NSNotFound)
					[s appendString:@"\\"];
				[s appendString:insChar];
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
				ts = [[ViTabstop alloc] init];
				ts.num = tabStop;
				ts.parent = parentTabstop;
				ts.index = [tabstops count];
				[tabstops addObject:ts];
				if (tabStop > maxTabNum)
					maxTabNum = tabStop;
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
			ViRegexp *rx = nil;
			filter = nil;
			defaultValue = nil;
			if (bracedExpression) {
				if ([scan scanString:@":" intoString:nil]) {
					/*
					 * Got a default value.
					 */
					NSString *substring = [aString substringFromIndex:[scan scanLocation]];
					NSUInteger len;
					defaultValue = [self parseString:substring
					                       stopChars:@"|}"
					                   parentTabstop:ts
					                   allowTabstops:ts ? YES : NO
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

					[scan scanCharactersFromSet:[NSCharacterSet alphanumericCharacterSet]
					                 intoString:&options];
					if (options == nil)
						options = @"";
					DEBUG(@"regexp = %@", regexp);
					DEBUG(@"format = %@", format);
					DEBUG(@"options = %@", options);

					int opts = 0;
					if ([options rangeOfString:@"i"].location != NSNotFound)
						opts |= ONIG_OPTION_IGNORECASE;

					rx = [[ViRegexp alloc] initWithString:regexp options:opts error:outError];
					if (rx == nil)
						return NO;

					value = [self transformValue:(value ?: @"")
					                 withPattern:rx
					                      format:format
					                     options:options
					                       error:outError];
					if (value == nil)
						return NO;
				}

				if ([scan scanString:@"|" intoString:nil]) {
					/*
					 * Shell pipe.
					 */
					NSUInteger startLocation = [scan scanLocation];
					if (![scan scanUpToUnescapedCharacter:'}' intoString:&filter]) {
						if (outError)
							*outError = [ViError errorWithFormat:
							    @"Unterminated shell pipe beginning at character %lu", startLocation + 1];
						return NO;
					}
					DEBUG(@"got shell pipe [%@], input is [%@]", filter, value);
					if (ts == nil) {
						value = [self runShellCommand:filter
								    withInput:(value ?: @"")
									error:outError];
						if (value == nil)
							return NO;
					}
				}

				if (![scan scanString:@"}" intoString:nil]) {
					if (outError)
						*outError = [ViError errorWithFormat:@"Missing closing brace at %lu",
						    [scan scanLocation] + 1];
					return NO;
				}
			}

			if (value == nil)
				value = defaultValue;

			if (ts != nil) {
				ts.rx = rx;
				ts.format = format;
				ts.options = options;
				ts.filter = filter;
				ts.value = defaultValue;
				ts.range = NSMakeRange([s length], [value length]);

				/*
				 * Find mirrors. The first defined tabstop with a default value is
				 * the master placeholder. All other tabstops mirrors that one.
				 */
				// First find the master.
				ViTabstop *master = nil;
				for (ViTabstop *candidate in tabstops)
					if (candidate.num == tabStop) {
						if (master == nil || candidate.value)
							master = candidate;
						if (master.value)
							break;
					}
				// Then update all other tabstops to mirror the master.
				for (ViTabstop *mirror in tabstops)
					if (mirror.num == tabStop && mirror != master)
						mirror.mirror = master;
			}

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
			NSMutableString *output = [self runShellCommand:shellCommand withInput:@"" error:outError];
			if (output == nil)
				return NO;
			[s appendString:output];
		} else {
			NSString *insChar = [NSString stringWithFormat:@"%C", ch];
			if ([stopChars rangeOfString:insChar].location != NSNotFound) {
				[scan setScanLocation:[scan scanLocation] - 1];
				break;
			}
			[s appendString:insChar];
		}
	}

	*scannedLength = [scan scanLocation];
	return s;
}

- (ViSnippet *)initWithString:(NSString *)aString
                   atLocation:(NSUInteger)aLocation
                     delegate:(id<ViSnippetDelegate>)aDelegate
                  environment:(NSDictionary *)env
                        error:(NSError **)outError
{
	self = [super init];
	if (self == nil)
		return nil;

	environment = env;
	tabstops = [[NSMutableArray alloc] init];

	DEBUG(@"snippet string = %@ at location %lu", aString, aLocation);

	NSUInteger len;
	NSMutableString *string = [self parseString:aString
	                                  stopChars:@""
	                              parentTabstop:nil
	                              allowTabstops:YES
	                              scannedLength:&len
	                                      error:outError];
	if (!string)
		return nil;
	DEBUG(@"scanned %lu chars", len);

	if (len != [aString length]) {
		DEBUG(@"whole string not parsed? length = %lu, i = %lu", [aString length], len);
		return nil;
	}

	beginLocation = aLocation;
	range = NSMakeRange(beginLocation, [string length]);

	delegate = aDelegate;
	[delegate snippet:self replaceCharactersInRange:NSMakeRange(aLocation, 0) withString:string];

	DEBUG(@"tabstops = %@", tabstops);

	finished = ([tabstops count] == 0);

	if (![self updateTabstopsError:outError])
		return NO;
	DEBUG(@"inserted string = [%@]", [self string]);

	if (finished)
		caret = NSMaxRange(range);
	else
		[self advance];

	return self;
}

- (void)deselect
{
	DEBUG(@"deselecting tab range %@", NSStringFromRange(selectedRange));
	selectedRange = NSMakeRange(NSNotFound, 0);
}

- (void)filterTabstop:(ViTabstop *)ts
{
	if (ts.filter) {
		ts.value  = [self runShellCommand:ts.filter
		                        withInput:(ts.value ?: @"")
		                            error:nil];
		[self removeNestedIn:ts];
		[self updateTabstopsError:nil];
	}
}

- (ViTabstop *)findTabstop:(NSUInteger)num
{
	ViTabstop *candidate = nil;
	NSInteger i;

	DEBUG(@"finding candidate for tabstop %lu", num);

	for (i = 0; i < [tabstops count]; i++) {
		ViTabstop *ts = [tabstops objectAtIndex:i];
		DEBUG(@"testing candidate at index %i: %@", i, ts);
		if (ts.num == num) {
			candidate = ts;
			if (candidate.mirror == nil)
				break;
		}
	}

	return candidate;
}

- (BOOL)advance
{
	if (finished)
		return NO;

	[self filterTabstop:currentTabStop];

	NSUInteger nextTabNum;
	for (nextTabNum = ++currentTabNum; ; nextTabNum++) {
		if (nextTabNum > maxTabNum)
			nextTabNum = 0;

		currentTabStop = [self findTabstop:nextTabNum];
		if (currentTabStop || nextTabNum == 0)
			break;
	}

	if (currentTabStop == nil) {
		DEBUG(@"%s", "next tabstop not found");
		finished = YES;
		return NO;
	}

	DEBUG(@"advancing to tab stop %i range %@",
	    currentTabStop.num, NSStringFromRange(currentTabStop.range));

	if (nextTabNum == 0) {
		[self filterTabstop:currentTabStop];
		finished = YES;
	}

	NSRange r = currentTabStop.range;
	caret = beginLocation + r.location;
	if (currentTabStop.parent)
		caret += [self parentLocation:currentTabStop];
	selectedRange = NSMakeRange(caret, r.length);
	currentTabNum = nextTabNum;

	DEBUG(@"tabstops = %@", tabstops);

	return YES;
}

- (NSRange)tabRange
{
	if (finished || currentTabStop == nil)
		return NSMakeRange(NSNotFound, 0);
	NSRange r = currentTabStop.range;
	return NSMakeRange(beginLocation + r.location, r.length);
}

- (void)pushTabstopsFromIndex:(NSUInteger)startIndex
           withChangeInLength:(NSInteger)delta
                     inParent:(ViTabstop *)parent
{
	DEBUG(@"update tabstops from index %lu with change %li in parent %@", startIndex, delta, parent);

	NSUInteger i;
	for (i = startIndex; i < [tabstops count]; i++) {
		ViTabstop *ts = [tabstops objectAtIndex:i];
		if (ts.parent == parent) {
			NSRange r = ts.range;
			r.location += delta;
			DEBUG(@"tabstop %u range %@ -> %@",
			    ts.num, NSStringFromRange(ts.range), NSStringFromRange(r));
			ts.range = r;
		} else
			DEBUG(@"tabstop %u range %@ unchanged",
			    ts.num, NSStringFromRange(ts.range));
	}

	if (parent == nil) {
		range.length += delta;
		DEBUG(@"snippet range -> %@", NSStringFromRange(range));
	}
}

- (BOOL)updateTabstop:(ViTabstop *)ts
                error:(NSError **)outError
{
	ViTabstop *mirror = ts.mirror;
	NSString *value;
	if (mirror) {
		value = mirror.value;
		if (ts.rx) {
			value = [self transformValue:value
			                 withPattern:ts.rx
			                      format:ts.format
			                     options:ts.options
			                       error:outError];
			if (outError && *outError)
				return NO;
		}

		if (ts.filter) {
			value = [self runShellCommand:ts.filter
			                    withInput:(value ?: @"")
			                        error:outError];
			if (value == nil)
				return NO;
		}
	} else
		value = ts.value;

	if (value) {
		NSRange r = ts.range;
		if (ts.parent) {
			NSMutableString *s = ts.parent.value;
			DEBUG(@"update tab stop %i range %@ with value [%@] in string [%@]",
			    ts.num, NSStringFromRange(r), value, s);
			[s replaceCharactersInRange:r withString:value];
			DEBUG(@"string -> [%@]", s);
			[self updateTabstop:ts.parent error:outError];
		} else {
			DEBUG(@"update tab stop %i range %@ with value [%@] in string [%@]",
			    ts.num, NSStringFromRange(r), value, [delegate string]);
			r.location += beginLocation;
			[delegate snippet:self replaceCharactersInRange:r withString:value];
			r.location -= beginLocation;
			DEBUG(@"string -> [%@]", [delegate string]);
		}

		NSInteger delta = [value length] - r.length;
		r.length = [value length];
		ts.range = r;

		[self pushTabstopsFromIndex:ts.index + 1 withChangeInLength:delta inParent:ts.parent];
	}

	return YES;
}

- (BOOL)updateTabstopsError:(NSError **)outError
{
	for (ViTabstop *ts in tabstops) {
		if (![self updateTabstop:ts error:outError])
			return NO;
	}

	return YES;
}

- (void)removeNestedIn:(ViTabstop *)parent
{
	BOOL found;
	NSUInteger i;

	for (found = YES; found;) {
		found = NO;
		for (i = 0; i < [tabstops count]; i++) {
			ViTabstop *ts = [tabstops objectAtIndex:i];
			if (ts.parent == parent) {
				[self removeNestedIn:ts];
				DEBUG(@"removing nested tabstop %@", ts);
				[tabstops removeObjectAtIndex:i];
				found = YES;
				break;
			}
		}
	}
}

- (BOOL)replaceRange:(NSRange)updateRange withString:(NSString *)replacementString
{
	[self deselect];

	if (![self activeInRange:updateRange])
		return NO;

	/* Remove any nested tabstops. */
	[self removeNestedIn:currentTabStop];

	NSRange normalizedRange = updateRange;
	normalizedRange.location -= beginLocation;

	DEBUG(@"replace range %@ with [%@]", NSStringFromRange(normalizedRange), replacementString);

	NSRange r = currentTabStop.range;
	normalizedRange.location -= r.location;
	normalizedRange.location -= [self parentLocation:currentTabStop];
	if (currentTabStop.value == nil)
		currentTabStop.value = [NSMutableString string];
	[currentTabStop.value replaceCharactersInRange:normalizedRange withString:replacementString];
	return [self updateTabstopsError:nil];
}

- (NSUInteger)parentLocation:(ViTabstop *)ts
{
	if (ts.parent)
		return ts.parent.range.location + [self parentLocation:ts.parent];
	return 0ULL;
}

- (BOOL)activeInRange:(NSRange)aRange
{
	if (finished || currentTabStop == nil) {
		DEBUG(@"%s", "current tab stop is nil");
		return NO;
	}

	NSRange normalizedRange = aRange;
	normalizedRange.location -= beginLocation;
	normalizedRange.location -= [self parentLocation:currentTabStop];

	NSRange r = currentTabStop.range;
	if (normalizedRange.location < r.location ||
	    normalizedRange.location > NSMaxRange(r) ||
	    NSMaxRange(normalizedRange) > NSMaxRange(r)) {
		DEBUG(@"update range %@ outside current tabstop %@",
		    NSStringFromRange(normalizedRange), NSStringFromRange(r));
		return NO;
	}

	return YES;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViSnippet at %@>", NSStringFromRange(range)];
}

- (NSString *)string
{
	return [delegate string];
}

@end
