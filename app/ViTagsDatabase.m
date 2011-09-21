#import "ViTagsDatabase.h"
#import "ViURLManager.h"
#import "NSScanner-additions.h"
#import "NSURL-additions.h"
#include "logging.h"

@implementation ViTagsDatabase

@synthesize baseURL = _baseURL;
@synthesize databaseURL = _databaseURL;
@synthesize modificationDate = _modificationDate;

- (ViTagsDatabase *)initWithBaseURL:(NSURL *)aURL
{
	if ((self = [super init]) != nil) {
		_baseURL = [aURL retain];
		_tags = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[_baseURL release];
	[_tags release];
	[_modificationDate release];
	[_databaseURL release];
	[super dealloc];
}

- (void)onOpen:(void (^)(NSError *error))aBlock
{
	/* If the file is not an absolute path, try to find it in the current directory.
	 * Look in parent directories if not found.
	 */
	ViURLManager *um = [ViURLManager defaultManager];
#if 0
	prefixPath = [aDirectory copy];
	DEBUG(@"prefix path = [%@]", prefixPath);
	NSString *path = nil;
	if (![aFile isAbsolutePath]) {
		NSString *component;
		NSString *p = nil;
		for (component in [prefixPath pathComponents]) {
			if (p)
				p = [p stringByAppendingPathComponent:component];
			else
				p = component;

			NSString *check = [p stringByAppendingPathComponent:aFile];
			DEBUG(@"checking for tags file [%@]", check);
			if ([fm fileExistsAtPath:check]) {
				/* We found a tags file. There might be more files
				 * closer to the current directory so we continue looking.
				 */
				path = check;
				prefixPath = p;
			}
		}
	} else {
		path = aFile;
	}
#endif
	
	NSURL *url = [_baseURL URLByAppendingPathComponent:@"tags"];
	DEBUG(@"opening tags file [%@]", url);

	NSMutableData *tagsData = [NSMutableData data];
	void (^dataCallback)(NSData *data) = ^(NSData *data) {
		[tagsData appendData:data];
	};

	[um dataWithContentsOfURL:url onData:dataCallback onCompletion:^(NSURL *normalizedURL, NSDictionary *attributes, NSError *error) {
		if (!error) {
			[self setModificationDate:[attributes fileModificationDate]];
			DEBUG(@"got modtime %@", _modificationDate);
			[self setDatabaseURL:normalizedURL];
			[self parseData:tagsData];
		}
		aBlock(error);
	}];
}

- (void)parseData:(NSData *)data
{
	NSString *strdata = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	if (strdata == nil)
		strdata = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];

	NSCharacterSet *tabSet = [NSCharacterSet characterSetWithCharactersInString:@"\t"];

	NSString *line;
	for (line in [strdata componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
		NSScanner *scan = [NSScanner scannerWithString:line];
		[scan setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@""]];

		NSString *symbol;
		NSString *file;
		NSString *pattern;

		if ([scan scanUpToString:@"\t" intoString:&symbol] &&
		    [scan scanCharactersFromSet:tabSet intoString:nil] &&
		    [scan scanUpToString:@"\t" intoString:&file] &&
		    [scan scanCharactersFromSet:tabSet intoString:nil] &&
		    [scan scanString:@"/" intoString:nil] &&
		    [scan scanUpToUnescapedCharacter:'/' intoString:&pattern stripEscapes:YES]) {
			NSURL *url = [_baseURL URLWithRelativeString:file];
			DEBUG(@"got symbol [%@] in file [%@], pattern [%@]", symbol, url, pattern);
			[_tags setObject:[NSArray arrayWithObjects:url, pattern, nil] forKey:symbol];
		} else
			DEBUG(@"skipping tags line [%@]", line);
	}
	[strdata release];
}

- (void)onDatabaseChanged:(void (^)(NSError *error))aBlock
{
	DEBUG(@"checking if %@ has change modtime from %@", _databaseURL, _modificationDate);
	[[ViURLManager defaultManager] attributesOfItemAtURL:_databaseURL
						onCompletion:^(NSURL *normalizedURL, NSDictionary *attributes, NSError *error) {
		if (error)
			aBlock(error);
		if ([_modificationDate isEqualToDate:[attributes fileModificationDate]]) {
			DEBUG(@"tags file %@ unmodified: %@", normalizedURL, _modificationDate);
			aBlock(nil);
		} else
			[self onOpen:aBlock];
	}];
}

- (void)lookup:(NSString *)symbol onCompletion:(void (^)(NSArray *tag, NSError *error))aBlock
{
	void (^fun)(NSError *error) = ^(NSError *error) {
		if (error)
			aBlock(nil, error);
		else
			aBlock([_tags objectForKey:symbol], nil);
	};

	DEBUG(@"looking up symbol %@", symbol);
	if (_modificationDate)
		[self onDatabaseChanged:fun];
	else
		[self onOpen:fun];
}

@end
