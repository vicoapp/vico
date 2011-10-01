#import "ViFileCompletion.h"
#import "ViError.h"
#import "ViWindowController.h"
#import "ViFile.h"
#include "logging.h"

@implementation ViFileCompletion

- (void)appendFilter:(NSString *)string toPattern:(NSMutableString *)pattern
{
	NSUInteger i;
	for (i = 0; i < [string length]; i++) {
		unichar c = [string characterAtIndex:i];
		if (i != 0)
			[pattern appendString:@".*?"];
		[pattern appendFormat:@"(%s%C)", c == '.' ? "\\" : "", c];
	}
}

- (NSArray *)completionsForString:(NSString *)path
			  options:(NSString *)options
			    error:(NSError **)outError
{
	NSURL *relURL = [[ViWindowController currentWindowController] baseURL];
	DEBUG(@"relURL is %@", relURL);
	NSString *basePath = nil;
	NSURL *baseURL = nil;
	NSURL *url = nil;
	BOOL isAbsoluteURL = NO;
	if ([path rangeOfString:@"://"].location != NSNotFound) {
		isAbsoluteURL = YES;
		url = [NSURL URLWithString:
		    [path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
		if (url == nil) {
			if (outError)
				*outError = [ViError errorWithFormat:@"failed to parse url %@", path];
			return nil;
		}
		if ([[url path] length] == 0) {
			DEBUG(@"no path in url %@", url);
			url = [[NSURL URLWithString:@"/" relativeToURL:url] absoluteURL];
			DEBUG(@"added path in url %@", url);
			baseURL = url;
		} else if ([path hasSuffix:@"/"])
			baseURL = url;
		else
			baseURL = [url URLByDeletingLastPathComponent];
	} else if ([path isAbsolutePath]) {
		if ([path hasSuffix:@"/"])
			basePath = path;
		else
			basePath = [path stringByDeletingLastPathComponent];
		url = [[NSURL URLWithString:
		    [path stringByExpandingTildeInPath] relativeToURL:relURL] absoluteURL];
	} else {
		if ([path hasSuffix:@"/"])
			basePath = path;
		else
			basePath = [path stringByDeletingLastPathComponent];
		url = [[NSURL URLWithString:
		    [path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
			     relativeToURL:relURL] absoluteURL];
	}

	NSString *suffix = @"";
	if (isAbsoluteURL && ![[url absoluteString] hasSuffix:@"/"]) {
		suffix = [path lastPathComponent];
		url = [url URLByDeletingLastPathComponent];
	} else if (![path hasSuffix:@"/"] && ![path isEqualToString:@""]) {
		suffix = [path lastPathComponent];
		url = [url URLByDeletingLastPathComponent];
	}

	BOOL fuzzySearch = ([options rangeOfString:@"f"].location != NSNotFound);
	BOOL fuzzyTrigger = ([options rangeOfString:@"F"].location != NSNotFound);
	ViRegexp *rx = nil;
	if (fuzzyTrigger) { /* Fuzzy completion trigger. */
		NSMutableString *pattern = [NSMutableString string];
		[pattern appendString:@"^"];
		[self appendFilter:suffix toPattern:pattern];
		[pattern appendString:@".*$"];
		rx = [ViRegexp regexpWithString:pattern options:ONIG_OPTION_IGNORECASE];
	}

	DEBUG(@"suffix = [%@], rx = [%@], url = %@", suffix, rx, url);

	int opts = 0;
	if ([url isFileURL]) {
		/* Check if local filesystem is case sensitive. */
		NSNumber *isCaseSensitive;
		if ([url getResourceValue:&isCaseSensitive
				   forKey:NSURLVolumeSupportsCaseSensitiveNamesKey
				    error:NULL] && ![isCaseSensitive intValue] == 1) {
			opts |= NSCaseInsensitiveSearch;
		}
	}

	ViURLManager *um = [ViURLManager defaultManager];

	__block NSMutableArray *matches = nil;
	__block NSError *error = nil;

	id<ViDeferred> deferred = [um contentsOfDirectoryAtURL:url
						  onCompletion:^(NSArray *directoryContents, NSError *err) {
		if (err) {
			error = [err retain];
			return;
		}

		matches = [[NSMutableArray alloc] init];
		for (ViFile *file in directoryContents) {
			NSRange r = NSIntersectionRange(NSMakeRange(0, [suffix length]),
			    NSMakeRange(0, [file.name length]));
			BOOL match;
			ViRegexpMatch *m = nil;
			if (fuzzyTrigger)
				match = ((m = [rx matchInString:file.name]) != nil);
			else
				match = [file.name compare:suffix options:opts range:r] == NSOrderedSame;

			if (match) {
				/* Only show dot-files if explicitly requested. */
				if ([file.name hasPrefix:@"."] && ![suffix hasPrefix:@"."])
					continue;

				NSString *s;
				if (isAbsoluteURL)
					s = [[baseURL URLByAppendingPathComponent:file.name] absoluteString];
				else
					s = [basePath stringByAppendingPathComponent:file.name];

				if (file.isDirectory)
					s = [s stringByAppendingString:@"/"];

				ViCompletion *c;
				if (fuzzySearch)
					c = [ViCompletion completionWithContent:s fuzzyMatch:m];
				else {
					c = [ViCompletion completionWithContent:s];
					c.prefixLength = [basePath length] + r.length;
				}
				[matches addObject:c];
			}
		}
	}];

	[deferred wait];
	if (outError && error)
		*outError = [error autorelease];
	return [matches autorelease];
}

@end
