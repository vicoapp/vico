#define FORCE_DEBUG
#import "ViTagsDatabase.h"
#import "ViURLManager.h"
#include "logging.h"

@interface ViTagsDatabase (private)
- (void)parseData:(NSData *)data;
- (void)onOpen:(void (^)(NSError *error))aBlock;
- (void)onDatabaseChanged:(void (^)(NSError *error))aBlock;
@end

@implementation ViTagsDatabase

- (ViTagsDatabase *)initWithBaseURL:(NSURL *)aURL
{
	self = [super init];
	if (self) {
		baseURL = aURL;
		tags = [NSMutableDictionary dictionary];
	}
	return self;
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
	
	NSURL *url = [baseURL URLByAppendingPathComponent:@"tags"];
	DEBUG(@"opening tags file [%@]", url);

	NSMutableData *tagsData = [NSMutableData data];
	void (^dataCallback)(NSData *data) = ^(NSData *data) {
		[tagsData appendData:data];
	};

	[um dataWithContentsOfURL:url onData:dataCallback onCompletion:^(NSError *error) {
		if (error) {
			aBlock(error);
		} else {
			/* There is a race here between reading and checking modtime. */
			[um attributesOfItemAtURL:url
				     onCompletion:^(NSDictionary *attributes, NSError *error) {
				if (error) {
					aBlock(error);
				} else {
					modificationDate = [attributes fileModificationDate];
					DEBUG(@"got modtime %@", modificationDate);
					databaseURL = url;
					[self parseData:tagsData];
					aBlock(nil);
				}
			}];
		}
	}];
}

- (void)parseData:(NSData *)data
{
	NSString *strdata = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	if (strdata == nil)
		strdata = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];

	NSString *line;
	for (line in [strdata componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
		NSScanner *scan = [NSScanner scannerWithString:line];
		NSCharacterSet *tabSet = [NSCharacterSet characterSetWithCharactersInString:@"\t"];
		[scan setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@""]];

		NSString *symbol;
		NSString *file;

		if ([scan scanUpToString:@"\t" intoString:&symbol] &&
		    [scan scanCharactersFromSet:tabSet intoString:nil] &&
		    [scan scanUpToString:@"\t" intoString:&file] &&
		    [scan scanCharactersFromSet:tabSet intoString:nil] &&
		   ![scan isAtEnd]) {
			NSURL *path = [baseURL URLByAppendingPathComponent:file];
			NSString *command = [[scan string] substringFromIndex:[scan scanLocation]];
			DEBUG(@"got symbol [%@] in file [%@]", symbol, path);
			command = [command stringByReplacingOccurrencesOfString:@"*" withString:@"\\*"];
			command = [command stringByReplacingOccurrencesOfString:@"(" withString:@"\\("];
	 		command = [command stringByReplacingOccurrencesOfString:@")" withString:@"\\)"];
			/*[command replaceOccurrencesOfRegularExpressionString:@"[\\*\\(\\)]"
								  withString:@"\\&"
								     options:OgreRubySyntax
								       range:NSMakeRange(0, [command length])];*/
			[tags setObject:[NSArray arrayWithObjects:path, command, nil] forKey:symbol];
		} else
			DEBUG(@"skipping tags line [%@]", line);
	}
}

- (void)onDatabaseChanged:(void (^)(NSError *error))aBlock
{
	DEBUG(@"checking if %@ has change modtime from %@", databaseURL, modificationDate);
	[[ViURLManager defaultManager] attributesOfItemAtURL:databaseURL
						onCompletion:^(NSDictionary *attributes, NSError *error) {
		if (error)
			aBlock(error);
		if ([modificationDate isEqualToDate:[attributes fileModificationDate]]) {
			DEBUG(@"tags file %@ unmodified: %@", databaseURL, modificationDate);
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
			aBlock([tags objectForKey:symbol], nil);
	};

	DEBUG(@"looking up symbol %@", symbol);
	if (modificationDate)
		[self onDatabaseChanged:fun];
	else
		[self onOpen:fun];
}

@end
