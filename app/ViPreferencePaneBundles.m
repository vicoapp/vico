#import "ViPreferencePaneBundles.h"
#import "ViBundleStore.h"
#import "JSON.h"
#include "logging.h"

@implementation repoUserTransformer
+ (Class)transformedValueClass { return [NSDictionary class]; }
+ (BOOL)allowsReverseTransformation { return YES; }
- (id)init { return [super init]; }
- (id)transformedValue:(id)value
{
	if (![value isKindOfClass:[NSArray class]])
		return nil;

	NSArray *array = value;
	if ([array count] == 0)
		return value;

	if ([[array objectAtIndex:0] isKindOfClass:[NSString class]]) {
		/* Convert an array of strings to an array of dictionaries with "username" key. */
		NSMutableArray *a = [NSMutableArray array];
		NSArray *usernames = [array sortedArrayUsingSelector:@selector(compare:)];
		for (NSString *username in usernames)
			[a addObject:[NSMutableDictionary dictionaryWithObject:[username mutableCopy] forKey:@"username"]];
		return a;
	} else if ([[array objectAtIndex:0] isKindOfClass:[NSDictionary class]]) {
		/* Convert an array of dictionaries with "username" keys to an array of strings. */
		NSMutableArray *a = [NSMutableArray array];
		for (NSDictionary *dict in array)
			[a addObject:[[dict objectForKey:@"username"] mutableCopy]];
		[a sortUsingSelector:@selector(compare:)];
		return a;
	}

	return nil;
}
@end

@implementation statusIconTransformer
+ (Class)transformedValueClass { return [NSImage class]; }
+ (BOOL)allowsReverseTransformation { return NO; }
- (id)init {
	self = [super init];
	installedIcon = [NSImage imageNamed:NSImageNameStatusAvailable];
	return self;
}
- (id)transformedValue:(id)value
{
	if ([value isEqualToString:@"Installed"])
		return installedIcon;
	return nil;
}
@end

@implementation ViPreferencePaneBundles

- (id)init
{
	self = [super initWithNibName:@"BundlePrefs"
				 name:@"Bundles"
				 icon:[NSImage imageNamed:NSImageNameNetwork]];

	repositories = [NSMutableArray array];
	repoNameRx = [[ViRegexp alloc] initWithString:@"([^[:alnum:]]*(tmbundle|textmate-bundle)$)"
					      options:ONIG_OPTION_IGNORECASE];

	/* Show an icon in the status column of the repository table. */
	[NSValueTransformer setValueTransformer:[[statusIconTransformer alloc] init]
					forName:@"statusIconTransformer"];

	[NSValueTransformer setValueTransformer:[[repoUserTransformer alloc] init]
					forName:@"repoUserTransformer"];

	/* Sort repositories by installed status, then by name. */
	NSSortDescriptor *statusSort = [[NSSortDescriptor alloc] initWithKey:@"status"
								   ascending:NO];
	NSSortDescriptor *nameSort = [[NSSortDescriptor alloc] initWithKey:@"name"
								 ascending:YES];
	[bundlesController setSortDescriptors:[NSArray arrayWithObjects:statusSort, nameSort, nil]];

	NSArray *repoUsers = [[NSUserDefaults standardUserDefaults] arrayForKey:@"bundleRepositoryUsers"];
	for (NSDictionary *repo in repoUsers)
		[self loadBundlesFromRepo:[repo objectForKey:@"username"]];

	[bundlesTable setDoubleAction:@selector(installBundles:)];
	[bundlesTable setTarget:self];

	return self;
}

- (NSString *)repoPathForUser:(NSString *)username readonly:(BOOL)readonly
{
	NSString *path = [[NSString stringWithFormat:@"%@/%@-bundles.json",
	    [ViBundleStore bundlesDirectory], username]
	    stringByExpandingTildeInPath];

	if (!readonly)
		return path;

	if ([[NSFileManager defaultManager] fileExistsAtPath:path])
		return path;

	NSString *bundlePath = [[NSString stringWithFormat:@"%@/Contents/Resources/%@-bundles.json",
	    [[NSBundle mainBundle] bundlePath], username]
	    stringByExpandingTildeInPath];

	if ([[NSFileManager defaultManager] fileExistsAtPath:bundlePath])
		return bundlePath;

	return nil;
}

- (void)updateBundleStatus
{
	NSDate *date = [[NSUserDefaults standardUserDefaults] objectForKey:@"LastBundleRepoReload"];
	if (date) {
		NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
		[dateFormatter setDateStyle:NSDateFormatterMediumStyle];
		[dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
		[bundlesInfo setStringValue:[NSString stringWithFormat:@"%u installed, %u available. Last updated %@.",
		    (unsigned)[[[ViBundleStore defaultStore] allBundles] count],
		    [repositories count], [dateFormatter stringFromDate:date]]];
	} else {
		[bundlesInfo setStringValue:[NSString stringWithFormat:@"%u installed, %u available.",
		    (unsigned)[[[ViBundleStore defaultStore] allBundles] count], [repositories count]]];
	}
}

- (void)loadBundlesFromRepo:(NSString *)username
{
	/* Remove any existing repositories owned by this user. */
	[repositories filterUsingPredicate:[NSPredicate predicateWithFormat:@"NOT owner == %@", username]];

	NSString *path = [self repoPathForUser:username readonly:YES];
	if (path == nil)
		return;
	NSData *JSONData = [NSData dataWithContentsOfFile:path];
	NSString *JSONString = [[NSString alloc] initWithData:JSONData encoding:NSUTF8StringEncoding];
	NSDictionary *dict = [JSONString JSONValue];
	if (![dict isKindOfClass:[NSDictionary class]]) {
		INFO(@"%s", "failed to parse JSON");
		return;
	}

	NSArray *userBundles = [dict objectForKey:@"repositories"];

	/* Remove any non-tmbundle repositories. */
	[repositories addObjectsFromArray:userBundles];
	[repositories filterUsingPredicate:[NSPredicate predicateWithFormat:@"(name ENDSWITH \"tmbundle\") OR (name ENDSWITH \"textmate-bundle\")"]];

	for (NSMutableDictionary *bundle in repositories) {
		NSString *name = [bundle objectForKey:@"name"];
		NSString *owner = [bundle objectForKey:@"owner"];
		NSString *status = @"";
		if ([[ViBundleStore defaultStore] isBundleLoaded:[NSString stringWithFormat:@"%@-%@", owner, name]])
			status = @"Installed";
		[bundle setObject:status forKey:@"status"];

		/* Set displayName based on name, but trim any trailing .tmbundle. */
		NSString *displayName = [bundle objectForKey:@"name"];
		ViRegexpMatch *m = [repoNameRx matchInString:displayName];
		if (m)
			displayName = [displayName stringByReplacingCharactersInRange:[m rangeOfSubstringAtIndex:1] withString:@""];
		[bundle setObject:[displayName capitalizedString] forKey:@"displayName"];
	}

	[self filterRepositories:repoFilterField];
	[self updateBundleStatus];
}

#pragma mark -
#pragma mark Filtering GitHub bundle repositories

- (void)setFilteredRepositories:(NSArray *)anArray
{
	filteredRepositories = anArray;
}

- (IBAction)filterRepositories:(id)sender
{
	NSString *filter = [sender stringValue];
	if ([filter length] == 0) {
		[self setFilteredRepositories:repositories];
		return;
	}

	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(name CONTAINS[cd] %@) OR (description CONTAINS[cd] %@)", filter, filter];
	[self setFilteredRepositories:[repositories filteredArrayUsingPredicate:predicate]];
}

#pragma mark -
#pragma mark Managing GitHub repository users

- (void)selectRepoSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
}

- (IBAction)acceptSelectRepoSheet:(id)sender
{
	[NSApp endSheet:selectRepoSheet];

	/* Remove repositories for any deleted users. */
	for (NSDictionary *prevUser in previousRepoUsers) {
		NSString *prevOwner = [prevUser objectForKey:@"username"];
		BOOL found = NO;
		for (NSDictionary *repoUser in [repoUsersController arrangedObjects]) {
			if ([[repoUser objectForKey:@"username"] isEqualToString:prevOwner]) {
				found = YES;
				break;
			}
		}
		if (!found) {
			[repositories filterUsingPredicate:[NSPredicate predicateWithFormat:@"NOT owner == %@", prevOwner]];
			[self filterRepositories:repoFilterField];
		}
	}

	/* Reload repositories for any added users. */
	NSMutableArray *newUsers = [[NSMutableArray alloc] init];
	for (NSDictionary *repoUser in [repoUsersController arrangedObjects]) {
		BOOL found = NO;
		for (NSDictionary *prevUser in previousRepoUsers) {
			if ([[repoUser objectForKey:@"username"] isEqualToString:[prevUser objectForKey:@"username"]]) {
				found = YES;
				break;
			}
		}
		if (!found)
			[newUsers addObject:repoUser];
	}
	[self reloadRepositoriesFromUsers:newUsers];
}

- (IBAction)selectRepositories:(id)sender
{
	previousRepoUsers = [[repoUsersController arrangedObjects] copy];
	[NSApp beginSheet:selectRepoSheet
	   modalForWindow:[view window]
	    modalDelegate:self
	   didEndSelector:@selector(selectRepoSheetDidEnd:returnCode:contextInfo:)
	      contextInfo:nil];
}

- (IBAction)addRepoUser:(id)sender
{
	NSMutableDictionary *item = [NSMutableDictionary dictionaryWithObject:[NSMutableString string] forKey:@"username"];
	[repoUsersController addObject:item];
	[repoUsersController setSelectedObjects:[NSArray arrayWithObject:item]];
	[repoUsersTable editColumn:0 row:[repoUsersController selectionIndex] withEvent:nil select:YES];
}

#pragma mark -
#pragma mark Downloading GitHub repositories

- (void)progressSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
	progressCancelled = NO;
}

- (void)download:(NSURLDownload *)download didFailWithError:(NSError *)error
{
	[self cancelProgressSheet:nil];
	NSDictionary *repoUser = [processQueue lastObject];
	[progressDescription setStringValue:[NSString stringWithFormat:@"Failed to load %@'s repository: %@",
	    [repoUser objectForKey:@"username"], [error localizedDescription]]];
}

- (void)downloadDidFinish:(NSURLDownload *)download
{
	NSDictionary *repoUser = [processQueue lastObject];
	[self loadBundlesFromRepo:[repoUser objectForKey:@"username"]];
	[[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:@"LastBundleRepoReload"];

	[processQueue removeLastObject];
	if ([processQueue count] == 0)
		[NSApp endSheet:progressSheet];
	else
		[self reloadNextUser];
}

- (void)setExpectedContentLengthFromResponse:(NSURLResponse *)response
{
	long long expectedContentLength = [response expectedContentLength];
	if (expectedContentLength != NSURLResponseUnknownLength && expectedContentLength > 0) {
		[progressIndicator setIndeterminate:NO];
		[progressIndicator setMaxValue:expectedContentLength];
		[progressIndicator setDoubleValue:receivedContentLength];
	}
}

- (void)resetProgressIndicator
{
	receivedContentLength = 0;
	[progressButton setTitle:@"Cancel"];
	[progressButton setKeyEquivalent:@""];
	[progressIndicator setIndeterminate:YES];
	[progressIndicator startAnimation:self];
	installConnection = nil;
	repoDownload = nil;
}

- (void)download:(NSURLDownload *)download didReceiveResponse:(NSURLResponse *)response
{
	[self setExpectedContentLengthFromResponse:response];
}

- (void)download:(NSURLDownload *)download didReceiveDataOfLength:(NSUInteger)length
{
	receivedContentLength += length;
	[progressIndicator setDoubleValue:receivedContentLength];
}

- (IBAction)cancelProgressSheet:(id)sender
{
	if (progressCancelled) {
		[NSApp endSheet:progressSheet];
		return;
	}

	/* This action is connected to both repo downloads and bundle installation. */
	if (installConnection) {
		[installConnection cancel];
		[installTask terminate];
		installConnection = nil;
	} else if (userConnection) {
		[userConnection cancel];
		userConnection = nil;
	} else {
		[repoDownload cancel];
		repoDownload = nil;
	}

	progressCancelled = YES;
	[progressButton setTitle:@"OK"];
	[progressButton setKeyEquivalent:@"\r"];
	[progressIndicator stopAnimation:self];
	[progressDescription setStringValue:@"Cancelled download from GitHub"];
}

- (void)reloadNextUser
{
	NSDictionary *repo = [processQueue lastObject];
	NSString *username = [repo objectForKey:@"username"];
	if ([username length] == 0) {
		[processQueue removeLastObject];
		if ([processQueue count] == 0)
			[NSApp endSheet:progressSheet];
		else
			[self reloadNextUser];
	}

	[self resetProgressIndicator];
	[progressDescription setStringValue:[NSString stringWithFormat:@"Loading user %@...", username]];
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://github.com/api/v2/json/user/show/%@", username]];
	userConnection = [NSURLConnection connectionWithRequest:[NSURLRequest requestWithURL:url] delegate:self];
	userData = [[NSMutableData alloc] init];
	installConnection = nil;
}

- (void)reloadRepositoriesFromUsers:(NSArray *)users
{
	if ([users count] == 0)
		return;

	[progressDescription setStringValue:@"Loading bundle repositories from GitHub..."];
	[NSApp beginSheet:progressSheet
	   modalForWindow:[view window]
	    modalDelegate:self
	   didEndSelector:@selector(progressSheetDidEnd:returnCode:contextInfo:)
	      contextInfo:nil];

	processQueue = [NSMutableArray arrayWithArray:users];
	[self reloadNextUser];
}

- (IBAction)reloadRepositories:(id)sender
{
	[self reloadRepositoriesFromUsers:[repoUsersController arrangedObjects]];
}

#pragma mark -
#pragma mark Installing bundles from GitHub

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	[self cancelProgressSheet:nil];
	NSMutableDictionary *repo = [processQueue lastObject];
	if (connection == installConnection) {
		[progressDescription setStringValue:[NSString stringWithFormat:@"Download of %@ failed: %@", [repo objectForKey:@"displayName"], [error localizedDescription]]];
		[installTask terminate];
	} else if (connection == userConnection) {
		[progressDescription setStringValue:[NSString stringWithFormat:@"Download of %@ failed: %@", [repo objectForKey:@"username"], [error localizedDescription]]];
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	receivedContentLength += [data length];
	if (connection == installConnection) {
		[progressIndicator setDoubleValue:receivedContentLength];
		@try {
			[[installPipe fileHandleForWriting] writeData:data];
		}
		@catch (NSException *exception) {
			[installConnection cancel];
			[installTask terminate];

			[self cancelProgressSheet:nil];
			NSMutableDictionary *repo = [processQueue lastObject];
			[progressDescription setStringValue:[NSString stringWithFormat:@"Installation of %@ failed when unpacking.", [repo objectForKey:@"displayName"]]];
		}
	} else if (connection == userConnection) {
		[userData appendData:data];
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	if (connection == installConnection)
		[self setExpectedContentLengthFromResponse:response];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	if (connection == userConnection) {
		NSMutableDictionary *repo = [processQueue lastObject];
		NSString *username = [repo objectForKey:@"username"];

		NSString *JSONString = [[NSString alloc] initWithData:userData encoding:NSUTF8StringEncoding];
		NSDictionary *dict = [JSONString JSONValue];
		if (![dict isKindOfClass:[NSDictionary class]]) {
			[self cancelProgressSheet:nil];
			[progressDescription setStringValue:[NSString stringWithFormat:@"Failed to parse data for user %@.", username]];
			return;
		}

		DEBUG(@"got user %@: %@", username, dict);

		[progressDescription setStringValue:[NSString stringWithFormat:@"Loading repositories from %@...", username]];
		NSURL *url;
		NSString *type = [[dict objectForKey:@"user"] objectForKey:@"type"];
		if ([type isEqualToString:@"User"])
			url = [NSURL URLWithString:[NSString stringWithFormat:@"http://github.com/api/v2/json/repos/show/%@", username]];
		else if ([type isEqualToString:@"Organization"])
			url = [NSURL URLWithString:[NSString stringWithFormat:@"http://github.com/api/v2/json/organizations/%@/public_repositories", username]];
		else {
			[self cancelProgressSheet:nil];
			[progressDescription setStringValue:[NSString stringWithFormat:@"Unknown type %@ of user %@", type, username]];
			return;
		}

		DEBUG(@"loading repositories from %@", url);
		repoDownload = [[NSURLDownload alloc] initWithRequest:[NSURLRequest requestWithURL:url] delegate:self];
		[repoDownload setDestination:[self repoPathForUser:username readonly:NO] allowOverwrite:YES];
		return;
	}

	[[installPipe fileHandleForWriting] closeFile];

	[installTask waitUntilExit];
	int status = [installTask terminationStatus];
	[progressIndicator setIndeterminate:YES];

	NSMutableDictionary *repo = [processQueue lastObject];
	NSString *owner = [repo objectForKey:@"owner"];
	NSString *name = [repo objectForKey:@"name"];
	NSString *displayName = [repo objectForKey:@"displayName"];

	if (status == 0) {
		NSError *error = nil;
		NSString *downloadDirectory = [[ViBundleStore bundlesDirectory] stringByAppendingPathComponent:@"download"];
		NSString *prefix = [NSString stringWithFormat:@"%@-%@", owner, name];
		NSString *bundleDirectory = nil;
		NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:downloadDirectory error:NULL];
		for (NSString *filename in contents) {
			if ([filename hasPrefix:prefix]) {
				bundleDirectory = filename;
				break;
			}
		}

		if (bundleDirectory == nil) {
			[self cancelProgressSheet:nil];
			[progressDescription setStringValue:[NSString stringWithFormat:@"Installation of %@ failed: downloaded bundle not found", displayName]];
			return;
		}

		contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[ViBundleStore bundlesDirectory] error:NULL];
		for (NSString *filename in contents) {
			if ([filename hasPrefix:prefix]) {
				NSString *path = [[ViBundleStore bundlesDirectory] stringByAppendingPathComponent:filename];
				if (![[NSFileManager defaultManager] removeItemAtPath:path error:&error]) {
					[self cancelProgressSheet:nil];
					[progressDescription setStringValue:[NSString stringWithFormat:@"Installation of %@ failed: %@ (%li)",
					    displayName, [error localizedDescription], [error code]]];
					return;
				}
				break;
			}
		}

		/*
		 * Move the bundle from the download directory to the bundles directory.
		 */
		NSString *src = [downloadDirectory stringByAppendingPathComponent:bundleDirectory];
		NSString *dst = [[ViBundleStore bundlesDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@", owner, name]];
		if (![[NSFileManager defaultManager] moveItemAtPath:src toPath:dst error:&error])  {
			[self cancelProgressSheet:nil];
			[progressDescription setStringValue:[NSString stringWithFormat:@"Installation of %@ failed: %@",
			    displayName, [error localizedDescription]]];
		}

		if ([[ViBundleStore defaultStore] loadBundleFromDirectory:dst])
			[repo setObject:@"Installed" forKey:@"status"];
		[self updateBundleStatus];
	} else {
		[self cancelProgressSheet:nil];
		[progressDescription setStringValue:[NSString stringWithFormat:@"Installation of %@ failed when unpacking (status %d).",
		    displayName, status]];
		return;
	}

	[processQueue removeLastObject];
	if ([processQueue count] == 0)
		[NSApp endSheet:progressSheet];
	else
		[self installNextBundle];
}

- (void)installNextBundle
{
	NSMutableDictionary *repo = [processQueue lastObject];

	[self resetProgressIndicator];
	[progressDescription setStringValue:[NSString stringWithFormat:@"Downloading and installing %@ (by %@)...",
	    [repo objectForKey:@"name"], [repo objectForKey:@"owner"]]];

	/*
	 * Move away any existing (temporary) bundle directory.
	 */
	NSError *error = nil;
	NSString *downloadDirectory = [[ViBundleStore bundlesDirectory] stringByAppendingPathComponent:@"download"];
	if (![[NSFileManager defaultManager] removeItemAtPath:downloadDirectory error:&error] && [error code] != NSFileNoSuchFileError) {
		[self cancelProgressSheet:nil];
		[progressDescription setStringValue:[NSString stringWithFormat:@"Installation of %@ failed: %@",
		    [repo objectForKey:@"displayName"], [error localizedDescription]]];
		return;
	}

	if (![[NSFileManager defaultManager] createDirectoryAtPath:downloadDirectory withIntermediateDirectories:YES attributes:nil error:&error]) {
		[self cancelProgressSheet:nil];
		[progressDescription setStringValue:[NSString stringWithFormat:@"Installation of %@ failed: %@",
		    [repo objectForKey:@"displayName"], [error localizedDescription]]];
		return;
	}

	installTask = [[NSTask alloc] init];
	[installTask setLaunchPath:@"/usr/bin/tar"];
	[installTask setArguments:[NSArray arrayWithObjects:@"-x", @"-C", downloadDirectory, nil]];

	installPipe = [NSPipe pipe];
	[installTask setStandardInput:installPipe];

	@try {
		[installTask launch];
	}
	@catch (NSException *exception) {
		[self cancelProgressSheet:nil];
		[progressDescription setStringValue:[NSString stringWithFormat:@"Installation of %@ failed: %@",
		    [repo objectForKey:@"displayName"], [exception reason]]];
		return;
	}

	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/tarball/master", [repo objectForKey:@"url"]]];
	installConnection = [NSURLConnection connectionWithRequest:[NSURLRequest requestWithURL:url] delegate:self];
}

- (IBAction)installBundles:(id)sender
{
	NSArray *selectedBundles = [bundlesController selectedObjects];
	if ([selectedBundles count] == 0)
		return;

	[NSApp beginSheet:progressSheet
	   modalForWindow:[view window]
	    modalDelegate:self
	   didEndSelector:@selector(progressSheetDidEnd:returnCode:contextInfo:)
	      contextInfo:nil];

	processQueue = [NSMutableArray arrayWithArray:selectedBundles];
	[self installNextBundle];
}

- (IBAction)uninstallBundles:(id)sender
{
}

@end
