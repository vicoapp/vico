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
	NSUInteger baseLocation;
	NSMutableString *value;
	ViTabstop *parent;
	ViTabstop *mirror;
	ViRegexp *rx;
	NSString *format;
	NSString *options;
	NSString *filter;
}
@property(readwrite) int num;
@property(readwrite) NSUInteger baseLocation;
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
@synthesize num, baseLocation, parent, mirror, range, value, rx, format, options, filter;
- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViTabstop %i@%@+%lu: [%@], pipe: [%@], parent: %@, mirror of: %@>",
	    num, NSStringFromRange(range), baseLocation, value, filter, parent, mirror];
}
@end

@interface ViSnippet (private)
- (void)updateTabstopsFromLocation:(NSUInteger)location
                withChangeInLength:(NSInteger)delta
                             error:(NSError **)outError;
- (BOOL)updateTabstopsError:(NSError **)outError;
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
	[task setEnvironment:environment];

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

#define RXFLAG_UPPERCASE_ONCE	1
#define RXFLAG_LOWERCASE_ONCE	2
#define RXFLAG_UPPERCASE	4
#define RXFLAG_LOWERCASE	8

#define test(wp, f)		((((*wp)) & (f)) == (f))

- (void)appendString:(NSString *)source
            toString:(NSMutableString *)target
            caseFold:(NSUInteger *)flags
{
	if ([source length] == 0)
		return;

	if (test(flags, RXFLAG_UPPERCASE_ONCE)) {
		[target appendString:[[source substringWithRange:NSMakeRange(0, 1)] uppercaseString]];
		[target appendString:[source substringFromIndex:1]];
		*flags &= ~RXFLAG_UPPERCASE_ONCE;
	} else if (test(flags, RXFLAG_UPPERCASE_ONCE)) {
		[target appendString:[[source substringWithRange:NSMakeRange(0, 1)] lowercaseString]];
		[target appendString:[source substringFromIndex:1]];
		*flags &= ~RXFLAG_LOWERCASE_ONCE;
	} else if (test(flags, RXFLAG_UPPERCASE)) {
		[target appendString:[source uppercaseString]];
	} else if (test(flags, RXFLAG_LOWERCASE)) {
		[target appendString:[source lowercaseString]];
	} else
		[target appendString:source];
}

- (NSString *)expandFormat:(NSString *)format
                 withMatch:(ViRegexpMatch *)m
                 stopChars:(NSString *)stopChars
            originalString:(NSString *)value
             scannedLength:(NSUInteger *)scannedLength
                     error:(NSError **)outError
{
	NSScanner *scan = [NSScanner scannerWithString:format];
	[scan setCharactersToBeSkipped:nil];

	NSMutableString *s = [NSMutableString string];
	unichar ch;
	NSUInteger flags = 0;
	while ([scan scanCharacter:&ch]) {
		NSInteger capture = -1;
		if (ch == '\\') {
			/* Skip the backslash escape if it's followed by a reserved character. */
			if ([scan scanCharacter:&ch]) {
				if (ch == 'u' || ch == 'U' || ch == 'l' || ch == 'L' || ch == 'E') {
					switch (ch) {
					case 'u':
						flags |= RXFLAG_UPPERCASE_ONCE;
						flags &= ~RXFLAG_LOWERCASE_ONCE;
						break;
					case 'U':
						flags |= RXFLAG_UPPERCASE;
						flags &= ~RXFLAG_LOWERCASE;
						break;
					case 'l':
						flags &= ~RXFLAG_UPPERCASE_ONCE;
						flags |= RXFLAG_LOWERCASE_ONCE;
						break;
					case 'L':
						flags &= ~RXFLAG_UPPERCASE;
						flags |= RXFLAG_LOWERCASE;
						break;
					case 'E':
						flags &= ~RXFLAG_UPPERCASE;
						flags &= ~RXFLAG_LOWERCASE;
						break;
					}
				} else {
					NSString *insChar = [NSString stringWithFormat:@"%C", ch];
					if (ch == 'n')
						insChar = @"\n";
					else if (ch == 't')
						insChar = @"\t";
					else if (ch != '$' && ch != '\\' && ch != '(' &&
					    [stopChars rangeOfString:insChar].location == NSNotFound)
						[self appendString:@"\\" toString:s caseFold:&flags];
					[self appendString:insChar toString:s caseFold:&flags];
				}
			} else
				[self appendString:@"\\" toString:s caseFold:&flags];
		} else if (ch == '$') {
			if (![scan scanInteger:&capture])
				[s appendString:@"$"];
			else if (capture < 0) {
				if (outError)
					*outError = [ViError errorWithFormat:
					    @"Negative capture group not allowed."];
				return nil;
			} else {
				NSRange r = [m rangeOfSubstringAtIndex:capture];
				DEBUG(@"got capture %i range %@ in string [%@]",
				    capture, NSStringFromRange(r), value);
				if (r.location != NSNotFound) {
					NSString *captureValue = [value substringWithRange:r];
					[self appendString:captureValue toString:s caseFold:&flags];
				}
			}
		} else if (ch == '(' &&
		    [scan scanString:@"?" intoString:nil] &&
		    [scan scanInteger:&capture] &&
		    [scan scanString:@":" intoString:nil]) {
			if (capture < 0) {
				if (outError)
					*outError = [ViError errorWithFormat:
					    @"Capture group in conditional insertion block is negative: %li",
					    capture];
				return nil;
			}

			NSString *conditionalString = [format substringFromIndex:[scan scanLocation]];
			NSUInteger len = 0;
			NSString *insertion = [self expandFormat:conditionalString 
			                               withMatch:m
			                               stopChars:@":)"
			                          originalString:value
			                           scannedLength:&len
			                                   error:outError];
			if (insertion == nil)
				return nil;
			DEBUG(@"nested parse scanned %lu characters and returned [%@]", len, insertion);
			[scan setScanLocation:[scan scanLocation] + len];

			NSString *otherwise = @"";
			if ([scan scanString:@":" intoString:nil]) {
				conditionalString = [format substringFromIndex:[scan scanLocation]];
				len = 0;
				otherwise = [self expandFormat:conditionalString
				                     withMatch:m
				                     stopChars:@")"
				                originalString:value
				                 scannedLength:&len
				                         error:outError];
				if (otherwise == nil)
					return nil;
				DEBUG(@"nested parse scanned %lu characters and returned [%@]", len, otherwise);
				[scan setScanLocation:[scan scanLocation] + len];
			}

			if (![scan scanString:@")" intoString:nil]) {
				if (outError)
					*outError = [ViError errorWithFormat:
					    @"Missing closing parenthesis for conditional insertion at %lu",
					    [scan scanLocation] + 1];
				return nil;
			}

			NSRange r = [m rangeOfSubstringAtIndex:capture];
			if (r.location != NSNotFound)
				[self appendString:insertion toString:s caseFold:&flags];
			else
				[self appendString:otherwise toString:s caseFold:&flags];
		} else {
			NSString *insChar = [NSString stringWithFormat:@"%C", ch];
			if ([stopChars rangeOfString:insChar].location != NSNotFound) {
				[scan setScanLocation:[scan scanLocation] - 1];
				break;
			}
			[self appendString:insChar toString:s caseFold:&flags];
		}
	}

	DEBUG(@"expanded format [%@] -> [%@]", format, s);

	if (scannedLength)
		*scannedLength = [scan scanLocation];

	return s;
}

- (NSString *)transformValue:(NSString *)value
                 withPattern:(ViRegexp *)rx
                      format:(NSString *)format
                     options:(NSString *)options
                       error:(NSError **)outError
{
	NSMutableString *text = [value mutableCopy];
	NSArray *matches = [rx allMatchesInString:value];
	NSInteger delta = 0;
	for (ViRegexpMatch *m in matches) {
		NSRange r = [m rangeOfMatchedString];
		DEBUG(@"/%@/ matched range %@ in string [%@], total %i matches",
		    rx, NSStringFromRange(r), value, [m count]);
		r.location += delta;
		NSString *expFormat = [self expandFormat:format
		                               withMatch:m
		                               stopChars:@""
		                          originalString:value
		                           scannedLength:nil
		                                   error:outError];
		if (expFormat == nil) {
			if (outError)
				return nil;
			expFormat = @"";
		}
		delta += [expFormat length] - r.length;
		DEBUG(@"replace range %@ with expanded format [%@]", NSStringFromRange(r), expFormat);
		[text replaceCharactersInRange:r withString:expFormat];
		if ([options rangeOfString:@"g"].location == NSNotFound)
			break;
	}
	DEBUG(@"transformed [%@] -> [%@]", value, text);
	return text;
}

- (NSMutableString *)parseString:(NSString *)aString
                       stopChars:(NSString *)stopChars
                   parentTabstop:(ViTabstop *)parentTabstop
                   allowTabstops:(BOOL)allowTabstops
                    baseLocation:(NSUInteger)baseLocation
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
				ts.baseLocation = baseLocation;
				ts.parent = parentTabstop;
				[tabstops addObject:ts];
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

					NSCharacterSet *optionsCharacters = [NSCharacterSet characterSetWithCharactersInString:@"gi"];
					[scan scanCharactersFromSet:optionsCharacters
					                 intoString:&options];
					if (options == nil)
						options = @"";
					DEBUG(@"regexp = %@", regexp);
					DEBUG(@"format = %@", format);
					DEBUG(@"options = %@", options);

					rx = [[ViRegexp alloc] initWithString:regexp options:0 syntax:0 error:outError];
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
				ts.range = NSMakeRange(baseLocation + [s length], [value length]);

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
	                               baseLocation:0
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

	[self sortTabstops:tabstops];
	DEBUG(@"tabstops = %@", tabstops);

	DEBUG(@"string = [%@]", string);
	delegate = aDelegate;
	[delegate snippet:self replaceCharactersInRange:NSMakeRange(aLocation, 0) withString:string];

	finished = ([tabstops count] == 0);

	if (![self updateTabstopsError:outError])
		return NO;
	DEBUG(@"inserted string = [%@]", [self string]);

	if (finished)
		caret = NSMaxRange(range);
	else {
		currentTabIndex = -1;
		[self advance];
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
	if (finished)
		return NO;

	if (currentTabStop.filter) {
		currentTabStop.value  = [self runShellCommand:currentTabStop.filter
		                                    withInput:(currentTabStop.value ?: @"")
		                                        error:nil];
		[self updateTabstopsError:nil];
	}

	ViTabstop *candidate = nil;
	NSInteger i, candidateIndex;
	for (i = ++currentTabIndex; i < [tabstops count]; i++) {
		ViTabstop *ts = [tabstops objectAtIndex:i];
		DEBUG(@"testing candidate at index %i: %@", i, ts);
		if (currentTabStop && currentTabStop.num == ts.num)
			continue;

		if (candidate == nil || candidate.num == ts.num) {
			candidate = ts;
			candidateIndex = i;
		}

		if (candidate.mirror == nil)
			break;
	}

	if (candidate == nil) {
		DEBUG(@"%s", "no candidate found");
		finished = YES;
		return NO;
	}

	currentTabIndex = candidateIndex;
	currentTabStop = candidate;

	DEBUG(@"advancing to tab stop %i range %@",
	    currentTabStop.num, NSStringFromRange(currentTabStop.range));

	if (currentTabStop.num == 0) {
		if (currentTabStop.filter) {
			currentTabStop.value = [self runShellCommand:currentTabStop.filter
						           withInput:(currentTabStop.value ?: @"")
							       error:nil];
			[self updateTabstopsError:nil];
		}
		finished = YES;
	}

	NSRange r = currentTabStop.range;
	caret = beginLocation + r.location;
	selectedRange = NSMakeRange(caret, r.length);

	return YES;
}

- (NSRange)tabRange
{
	if (finished || currentTabStop == nil)
		return NSMakeRange(NSNotFound, 0);
	NSRange r = currentTabStop.range;
	return NSMakeRange(beginLocation + r.location, r.length);
}

- (void)updateTabstopsFromLocation:(NSUInteger)location
                withChangeInLength:(NSInteger)delta
                          inParent:(ViTabstop *)parent
{
	DEBUG(@"update tabstops from location %lu with change %li in parent %@", location, delta, parent);

	for (ViTabstop *ts in tabstops) {
		if (ts.parent == parent) {
			NSRange r = ts.range;
#ifndef NO_DEBUG
			NSUInteger bs = ts.baseLocation;
#endif
			if (ts.baseLocation > location)
				ts.baseLocation += delta;
			if (r.location >= location)
				r.location += delta;
			DEBUG(@"tabstop %u range %@+%lu -> %@+%lu",
			    ts.num, NSStringFromRange(ts.range), bs, NSStringFromRange(r), ts.baseLocation);
			ts.range = r;
		} else
			DEBUG(@"tabstop %u range %@+%lu unchanged",
			    ts.num, NSStringFromRange(ts.range), ts.baseLocation);
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
			DEBUG(@"update tab stop %i range %@+%lu with value [%@] in string [%@]",
			    ts.num, NSStringFromRange(r), ts.baseLocation, value, s);
			r.location -= ts.baseLocation;
			[s replaceCharactersInRange:r withString:value];
			r.location += ts.baseLocation;
			DEBUG(@"string -> [%@]", s);
			[self updateTabstop:ts.parent error:outError];
		} else {
			DEBUG(@"update tab stop %i range %@+%lu with value [%@] in string [%@]",
			    ts.num, NSStringFromRange(r), ts.baseLocation, value, [delegate string]);
			r.location += beginLocation;
			[delegate snippet:self replaceCharactersInRange:r withString:value];
			r.location -= beginLocation;
			DEBUG(@"string -> [%@]", [delegate string]);
		}

		NSInteger delta = [value length] - r.length;
		[self updateTabstopsFromLocation:r.location withChangeInLength:delta inParent:ts.parent];

		r.length = [value length];
		ts.range = r;
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

	for (found = YES; found; found = NO) {
		for (i = 0; i < [tabstops count]; i++) {
			ViTabstop *ts = [tabstops objectAtIndex:i];
			if (ts.parent == parent) {
				[self removeNestedIn:ts];
				DEBUG(@"removing nested tabstop %@", ts);
				[tabstops removeObjectAtIndex:i];
				if (currentTabIndex >= i)
					--currentTabIndex;
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
	if (currentTabStop.value == nil)
		currentTabStop.value = [NSMutableString string];
	[currentTabStop.value replaceCharactersInRange:normalizedRange withString:replacementString];
	return [self updateTabstopsError:nil];
}

- (BOOL)activeInRange:(NSRange)aRange
{
	if (finished || currentTabStop == nil) {
		DEBUG(@"%s", "current tab stop is nil");
		return NO;
	}

	NSRange normalizedRange = aRange;
	normalizedRange.location -= beginLocation;

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
