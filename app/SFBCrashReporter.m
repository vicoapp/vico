/*
 *  Copyright (C) 2009, 2010 Stephen F. Booth <me@sbooth.org>
 *  All Rights Reserved
 */

#import "SFBCrashReporter.h"
#import "SFBCrashReporterWindowController.h"

@interface SFBCrashReporter (Private)
+ (NSArray *) crashLogPaths;
@end

@implementation SFBCrashReporter

+ (void) checkForNewCrashes
{
	// If no URL is found for the submission, we can't do anything
	NSString *crashSubmissionURLString = [[NSUserDefaults standardUserDefaults] stringForKey:@"SFBCrashReporterCrashSubmissionURL"];
	if(!crashSubmissionURLString) {
		crashSubmissionURLString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"SFBCrashReporterCrashSubmissionURL"];
		if(!crashSubmissionURLString)
			[NSException raise:@"Missing SFBCrashReporterCrashSubmissionURL" format:@"You must specify the URL for crash log submission as the SFBCrashReporterCrashSubmissionURL in either Info.plist or the user defaults!"];
	}

	// Determine when the last crash was reported
	NSDate *lastCrashReportDate = [[NSUserDefaults standardUserDefaults] objectForKey:@"SFBCrashReporterLastCrashReportDate"];

	// If a crash was never reported, use now as the starting point
	if(!lastCrashReportDate) {
		lastCrashReportDate = [NSDate date];
		[[NSUserDefaults standardUserDefaults] setObject:lastCrashReportDate forKey:@"SFBCrashReporterLastCrashReportDate"];
	}

	// Determine if it is even necessary to show the window (by comparing file modification dates to the last time a crash was reported)
	NSArray *crashLogPaths = [self crashLogPaths];
	for(NSString *path in crashLogPaths) {
		NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[path stringByResolvingSymlinksInPath] error:nil];
		NSDate *fileModificationDate = [fileAttributes fileModificationDate];

		// If the last time a crash was reported is earlier than the file's modification date, allow the user to report the crash
		if(NSOrderedAscending == [lastCrashReportDate compare:fileModificationDate]) {
			[SFBCrashReporterWindowController showWindowForCrashLogPath:path submissionURL:[NSURL URLWithString:crashSubmissionURLString]];

			// Don't prompt more than once
			break;
		}
	}
}

@end

@implementation SFBCrashReporter (Private)

+ (NSArray *) crashLogDirectories
{
	// Determine which directories contain crash logs based on the OS version
	// See http://developer.apple.com/technotes/tn2004/tn2123.html

	// Determine the OS version
	SInt32 versionMajor = 0;
	OSErr err = Gestalt(gestaltSystemVersionMajor, &versionMajor);
	if(noErr != err)
		NSLog(@"SFBCrashReporter: Unable to determine major system version (%i)", err);

	SInt32 versionMinor = 0;
	err = Gestalt(gestaltSystemVersionMinor, &versionMinor);
	if(noErr != err)
		NSLog(@"SFBCrashReporter: Unable to determine minor system version (%i)", err);

	NSArray *libraryPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask | NSLocalDomainMask, YES);
	NSString *crashLogDirectory = nil;

	// Snow Leopard (10.6) or later
	// Snow Leopard crash logs are located in ~/Library/Logs/DiagnosticReports with aliases placed in the Leopard location
	if(10 == versionMajor && 6 <= versionMinor)
		crashLogDirectory = @"Logs/DiagnosticReports";
	// Leopard (10.5) or earlier
	// Leopard crash logs have the form APPNAME_YYYY-MM-DD-hhmm_MACHINE.crash and are located in ~/Library/Logs/CrashReporter
	else if(10 == versionMajor && 5 >= versionMinor)
		crashLogDirectory = @"Logs/CrashReporter";

	NSMutableArray *crashFolderPaths = [[NSMutableArray alloc] init];

	for(NSString *libraryPath in libraryPaths) {
		NSString *path = [libraryPath stringByAppendingPathComponent:crashLogDirectory];

		BOOL isDir = NO;
		if([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] && isDir) {
			[crashFolderPaths addObject:path];
			break;
		}
	}

	return [crashFolderPaths autorelease];
}

+ (NSArray *) crashLogPaths
{
	NSString *applicationName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
	NSArray *crashLogDirectories = [self crashLogDirectories];

	NSMutableArray *paths = [[NSMutableArray alloc] init];

	for(NSString *crashLogDirectory in crashLogDirectories) {
		NSString *file = nil;
		NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:crashLogDirectory];
		while((file = [dirEnum nextObject]))
			if([file hasPrefix:applicationName])
				[paths addObject:[crashLogDirectory stringByAppendingPathComponent:file]];
	}

	return [paths autorelease];
}

@end
