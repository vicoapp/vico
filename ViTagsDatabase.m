#import "ViTagsDatabase.h"
#import "logging.h"

@interface ViTagsDatabase (private)
- (void)parseData:(NSString *)data;
@end

@implementation ViTagsDatabase

- (ViTagsDatabase *)initWithFile:(NSString *)aFile inDirectory:(NSString *)aDirectory
{
	self = [super init];
	if (self) {
		tags = [[NSMutableDictionary alloc] init];

		/* If the file is not an absolute path, try to find it in the current directory.
		 * Look in parent directories if not found.
		 */
		NSFileManager *fm = [NSFileManager defaultManager];
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
		} else
			path = aFile;

		if (path == nil)
			return nil;

		DEBUG(@"opening tags file [%@]", path);

		NSStringEncoding encoding;
		NSError *error = nil;
		NSString *data = [NSString stringWithContentsOfFile:path usedEncoding:&encoding error:&error];
		if (error)
			[NSApp presentError:error];
		else {
			[self parseData:data];

			NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error];
			if (error)
				[NSApp presentError:error];
			else {
				modificationDate = [attributes fileModificationDate];
				databaseFile = path;
			}
		}
	}
	return self;
}

- (void)parseData:(NSString *)data
{
	NSString *line;
	for (line in [data componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
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
			NSString *path = [prefixPath stringByAppendingPathComponent:file];
			NSString *command = [[scan string] substringFromIndex:[scan scanLocation]];
			DEBUG(@"got symbol [%@] in file [%@]", symbol, path);
			command = [command stringByReplacingOccurrencesOfString:@"*" withString:@"\\*"];
			command = [command stringByReplacingOccurrencesOfString:@"(" withString:@"\\("];
	 		command = [command stringByReplacingOccurrencesOfString:@")" withString:@"\\)"];
			// [command replaceOccurrencesOfRegularExpressionString:@"[\\*\\(\\)]" withString:@"\\&" options:OgreRubySyntax range:NSMakeRange(0, [command length])];
			[tags setObject:[NSArray arrayWithObjects:path, command, nil] forKey:symbol];
		} else
			DEBUG(@"skipping tags line [%@]", line);
	}
}

- (NSArray *)lookup:(NSString *)symbol
{
	return [tags objectForKey:symbol];
}

- (BOOL)databaseHasChanged
{
	if (databaseFile) {
		NSError *error = nil;
		NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:databaseFile error:&error];
		if (error) {
			[NSApp presentError:error];
			return NO;
		}

		if ([modificationDate isEqualToDate:[attributes fileModificationDate]]) {
			DEBUG(@"tags file unmodified [%@], [%@]", databaseFile, modificationDate);
			return NO;
		}
	}
	return YES;
}

@end
