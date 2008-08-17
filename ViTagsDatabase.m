//
//  ViTagsDatabase.m
//  vizard
//
//  Created by Martin Hedenfalk on 2008-03-31.
//  Copyright 2008 Martin Hedenfalk. All rights reserved.
//

#import "ViTagsDatabase.h"

@interface ViTagsDatabase (private)
- (void)parseData:(NSString *)data;
@end

@implementation ViTagsDatabase

- (ViTagsDatabase *)initWithFile:(NSString *)aFile
{
	self = [super init];
	if(self)
	{
		tags = [[NSMutableDictionary alloc] init];

		/* If the file is not an absolute path, try to find it in the current directory.
		 * Look in parent directory if not found.
		 */
		NSFileManager *fm = [NSFileManager defaultManager];
		prefixPath = [[fm currentDirectoryPath] copy];
		NSString *path;
		if(![aFile isAbsolutePath])
		{
			while(true)
			{
				path = [prefixPath stringByAppendingPathComponent:aFile];
				NSLog(@"checking for tags file [%@]", path);
				if([fm fileExistsAtPath:path])
				{
					break;
				}
				NSString *parent = [prefixPath stringByAppendingPathComponent:@".."];
				if([parent isEqualToString:prefixPath])
				{
					/* file not found, continuing will show an error message */
					path = aFile;
					break;
				}
				prefixPath = parent;
			}
		}
		else
		{
			path = aFile;
		}

		NSLog(@"opening tags file [%@]", path);

		NSStringEncoding encoding;
		NSError *error = nil;
		NSString *data = [NSString stringWithContentsOfFile:path usedEncoding:&encoding error:&error];
		if(error)
		{
			[NSApp presentError:error];
		}
		else
		{
			[self parseData:data];
		}
	}
	return self;
}

- (void)parseData:(NSString *)data
{
	NSString *line;
	for(line in [data componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]])
	{
		NSScanner *scan = [NSScanner scannerWithString:line];
		NSCharacterSet *tabSet = [NSCharacterSet characterSetWithCharactersInString:@"\t"];
		[scan setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@""]];

		NSString *symbol;
		NSString *file;
		NSString *command;

		if([scan scanUpToString:@"\t" intoString:&symbol] &&
		   [scan scanCharactersFromSet:tabSet intoString:nil] &&
		   [scan scanUpToString:@"\t" intoString:&file] &&
		   [scan scanCharactersFromSet:tabSet intoString:nil] &&
		   ![scan isAtEnd])
		{
			NSString *path = [prefixPath stringByAppendingPathComponent:file];
			command = [[scan string] substringFromIndex:[scan scanLocation]];
			// NSLog(@"got symbol [%@] in file [%@]", symbol, path);
			[tags setObject:[NSArray arrayWithObjects:path, command, nil] forKey:symbol];
		}
		else
		{
			NSLog(@"skipping tags line [%@]", line);
		}
	}
}

- (NSArray *)lookup:(NSString *)symbol
{
	return [tags objectForKey:symbol];
}

@end
