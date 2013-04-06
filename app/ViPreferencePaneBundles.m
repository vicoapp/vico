/*
 * Copyright (c) 2008-2012 Martin Hedenfalk <martin@vicoapp.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

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
			[a addObject:[NSMutableDictionary dictionaryWithObject:[[username mutableCopy] autorelease] forKey:@"username"]];
		return a;
	} else if ([[array objectAtIndex:0] isKindOfClass:[NSDictionary class]]) {
		/* Convert an array of dictionaries with "username" keys to an array of strings. */
		NSMutableArray *a = [NSMutableArray array];
		for (NSDictionary *dict in array)
			[a addObject:[[[dict objectForKey:@"username"] mutableCopy] autorelease]];
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
	_installedIcon = [[NSImage imageNamed:NSImageNameStatusAvailable] retain];
	return self;
}
- (void)dealloc
{
	[_installedIcon release];
	[super dealloc];
}
- (id)transformedValue:(id)value
{
	if ([value isEqualToString:@"Installed"])
		return _installedIcon;
	return nil;
}
@end

@implementation ViPreferencePaneBundles

@synthesize filteredRepositories = _filteredRepositories;

- (id)init
{
	self = [super initWithNibName:@"BundlePrefs"
				 name:@"Bundles"
				 icon:[NSImage imageNamed:NSImageNameNetwork]];
	if (self == nil)
		return nil;

	_repositories = [[NSMutableArray alloc] init];
	_repoNameRx = [[ViRegexp alloc] initWithString:@"(\\W*(tm|textmate|vico)\\W*bundle)$"
					       options:ONIG_OPTION_IGNORECASE];

	/* Show an icon in the status column of the repository table. */
	[NSValueTransformer setValueTransformer:[[[statusIconTransformer alloc] init] autorelease]
					forName:@"statusIconTransformer"];

	[NSValueTransformer setValueTransformer:[[[repoUserTransformer alloc] init] autorelease]
					forName:@"repoUserTransformer"];

	/* Sort repositories by installed status, then by name. */
	NSSortDescriptor *statusSort = [[[NSSortDescriptor alloc] initWithKey:@"status"
								    ascending:NO] autorelease];
	NSSortDescriptor *nameSort = [[[NSSortDescriptor alloc] initWithKey:@"name"
								  ascending:YES] autorelease];
	[bundlesController setSortDescriptors:[NSArray arrayWithObjects:statusSort, nameSort, nil]];

	NSArray *repoUsers = [[NSUserDefaults standardUserDefaults] arrayForKey:@"bundleRepoUsers"];
	for (NSString *username in repoUsers)
		[self loadBundlesFromRepo:username];

	[bundlesTable setDoubleAction:@selector(installBundles:)];
	[bundlesTable setTarget:self];

	return self;
}

- (void)dealloc
{
	[_repositories release];
	[_repoNameRx release];
	[_previousRepoUsers release];
	[_userData release];
	[_userConnection release];
	[_repoURL release];
	[_repoConnection release];
	[_repoData release];
	[_repoJson release];
	[_installConnection release];
	[_installPipe release];
	[_installTask release];
	// Release top-level nib objects
	[bundlesController release];
	[repoUsersController release];
	[progressSheet release];
	[selectRepoSheet release];
	[super dealloc];
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
		NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
		[dateFormatter setDateStyle:NSDateFormatterMediumStyle];
		[dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
		[bundlesInfo setStringValue:[NSString stringWithFormat:@"%u installed, %lu available. Last updated %@.",
		    (unsigned)[[[ViBundleStore defaultStore] allBundles] count],
		    [_repositories count], [dateFormatter stringFromDate:date]]];
	} else {
		[bundlesInfo setStringValue:[NSString stringWithFormat:@"%u installed, %lu available.",
		    (unsigned)[[[ViBundleStore defaultStore] allBundles] count], [_repositories count]]];
	}
}

- (void)loadBundlesFromRepo:(NSString *)username
{
	/* Remove any existing repositories owned by this user. */
	[_repositories filterUsingPredicate:[NSPredicate predicateWithFormat:@"NOT owner.login == %@", username]];

	if (!_repoJson) {
		NSString *path = [self repoPathForUser:username readonly:YES];
		if (path == nil)
			return;
		NSData *jsonData = [NSData dataWithContentsOfFile:path];
		NSString *jsonString = [[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] autorelease];
		NSArray *arry = [jsonString JSONValue];
		if (![arry isKindOfClass:[NSArray class]]) {
			INFO(@"%s", "failed to parse JSON");
			return;
		}
		[_repositories addObjectsFromArray: arry];
	} else {
		NSString *path = [self repoPathForUser:username readonly:NO];
		[[_repoJson JSONRepresentation] writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
		[_repositories addObjectsFromArray:_repoJson];
	}

	for (NSUInteger i = 0; i < [_repositories count];) {
		NSMutableDictionary *bundle = [_repositories objectAtIndex:i];

		/* Set displayName based on name, but trim any trailing .tmbundle. */
		NSString *displayName = [bundle objectForKey:@"name"];
		ViRegexpMatch *m = [_repoNameRx matchInString:displayName];
		if (m == nil) {
			/* Remove any non-bundle repositories. */
			[_repositories removeObjectAtIndex:i];
			continue;
		}
		++i;

		NSString *name = [bundle objectForKey:@"name"];
		NSString *owner = [[bundle objectForKey:@"owner"] objectForKey:@"login"];
		NSString *status = @"";
		if ([[ViBundleStore defaultStore] isBundleLoaded:[NSString stringWithFormat:@"%@-%@", owner, name]])
			status = @"Installed";
		[bundle setObject:status forKey:@"status"];

		displayName = [displayName stringByReplacingCharactersInRange:[m rangeOfSubstringAtIndex:1] withString:@""];
		[bundle setObject:[displayName capitalizedString] forKey:@"displayName"];
	}

	[self filterRepositories:repoFilterField];
	[self updateBundleStatus];
}

#pragma mark -
#pragma mark Filtering GitHub bundle repositories

- (IBAction)filterRepositories:(id)sender
{
	NSString *filter = [sender stringValue];
	if ([filter length] == 0) {
		[self setFilteredRepositories:_repositories];
		return;
	}

	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(owner.login CONTAINS[cd] %@) OR (name CONTAINS[cd] %@) OR (description CONTAINS[cd] %@)",
		filter, filter, filter];
	[self setFilteredRepositories:[_repositories filteredArrayUsingPredicate:predicate]];
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
	for (NSDictionary *prevUser in _previousRepoUsers) {
		NSString *prevOwner = [prevUser objectForKey:@"username"];
		BOOL found = NO;
		for (NSDictionary *repoUser in [repoUsersController arrangedObjects]) {
			if ([[repoUser objectForKey:@"username"] isEqualToString:prevOwner]) {
				found = YES;
				break;
			}
		}
		if (!found) {
			[_repositories filterUsingPredicate:[NSPredicate predicateWithFormat:@"NOT owner.login == %@", prevOwner]];
			[self filterRepositories:repoFilterField];
		}
	}

	/* Reload repositories for any added users. */
	NSMutableArray *newUsers = [NSMutableArray array];
	for (NSDictionary *repoUser in [repoUsersController arrangedObjects]) {
		BOOL found = NO;
		for (NSDictionary *prevUser in _previousRepoUsers) {
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
	[_previousRepoUsers release];
	_previousRepoUsers = [[repoUsersController arrangedObjects] copy];

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
	_progressCancelled = NO;
}

- (void)setExpectedContentLengthFromResponse:(NSURLResponse *)response
{
	long long expectedContentLength = [response expectedContentLength];
	if (expectedContentLength != NSURLResponseUnknownLength && expectedContentLength > 0) {
		[progressIndicator setIndeterminate:NO];
		[progressIndicator setMaxValue:expectedContentLength];
		[progressIndicator setDoubleValue:_receivedContentLength];
	}
}

- (void)resetProgressIndicator
{
	_receivedContentLength = 0;
	[progressButton setTitle:@"Cancel"];
	[progressButton setKeyEquivalent:@""];
	[progressIndicator setIndeterminate:YES];
	[progressIndicator startAnimation:self];

	[_installConnection release];
	_installConnection = nil;

	[_repoConnection release];
	_repoConnection = nil;
	[_repoData release];
	_repoData = nil;
}

- (IBAction)cancelProgressSheet:(id)sender
{
	if (_progressCancelled) {
		[NSApp endSheet:progressSheet];
		return;
	}

	/* This action is connected to both repo downloads and bundle installation. */
	if (_installConnection) {
		[_installConnection cancel];
		[_installTask terminate];
		[_installConnection release];
		[_installTask release];
		_installConnection = nil;
		_installTask = nil;
	} else if (_userConnection) {
		[_userConnection cancel];
		[_userConnection release];
		_userConnection = nil;
	} else {
		[_repoConnection cancel];
		[_repoConnection release];
		_repoConnection = nil;
	}

	_progressCancelled = YES;
	[progressButton setTitle:@"OK"];
	[progressButton setKeyEquivalent:@"\r"];
	[progressIndicator stopAnimation:self];
	[progressDescription setStringValue:@"Cancelled download from GitHub"];
}

- (void)reloadNextUser
{
	NSDictionary *repo = [_processQueue lastObject];
	NSString *username = [repo objectForKey:@"username"];
	if ([username length] == 0) {
		[_processQueue removeLastObject];
		if ([_processQueue count] == 0)
			[NSApp endSheet:progressSheet];
		else
			[self reloadNextUser];
	}

	[self resetProgressIndicator];
	[progressDescription setStringValue:[NSString stringWithFormat:@"Loading user %@...", username]];
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.github.com/users/%@", username]];

	[_userConnection release];
	_userConnection = [[NSURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:url] delegate:self];

	[_userData release];
	_userData = [[NSMutableData alloc] init];

	[_installConnection release];
	_installConnection = nil;
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

	[_processQueue release];
	_processQueue = [[NSMutableArray alloc] initWithArray:users];
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
	NSMutableDictionary *repo = [_processQueue lastObject];
	if (connection == _installConnection) {
		[progressDescription setStringValue:[NSString stringWithFormat:@"Download of %@ failed: %@", [repo objectForKey:@"displayName"], [error localizedDescription]]];
		[_installTask terminate];
		[_installTask release];
		_installTask = nil;
	} else if (connection == _userConnection) {
		[progressDescription setStringValue:[NSString stringWithFormat:@"Download of %@ failed: %@", [repo objectForKey:@"username"], [error localizedDescription]]];
	} else if (connection == _repoConnection) {
		[self cancelProgressSheet:nil];
		NSDictionary *repoUser = [_processQueue lastObject];
		[progressDescription setStringValue:[NSString stringWithFormat:@"Failed to load %@'s repository: %@",
						     [repoUser objectForKey:@"username"], [error localizedDescription]]];
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	_receivedContentLength += [data length];
	if (connection == _installConnection) {
		[progressIndicator setDoubleValue:_receivedContentLength];
		@try {
			[[_installPipe fileHandleForWriting] writeData:data];
		}
		@catch (NSException *exception) {
			[_installConnection cancel];
			[_installTask terminate];
			[_installTask release];
			_installTask = nil;

			[self cancelProgressSheet:nil];
			NSMutableDictionary *repo = [_processQueue lastObject];
			[progressDescription setStringValue:[NSString stringWithFormat:@"Installation of %@ failed when unpacking.", [repo objectForKey:@"displayName"]]];
		}
	} else if (connection == _userConnection) {
		[_userData appendData:data];
	} else if (connection == _repoConnection) {
		[_repoData appendData:data];

		_receivedContentLength += data.length;
		[progressIndicator setDoubleValue:_receivedContentLength];
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	if (connection == _installConnection)
		[self setExpectedContentLengthFromResponse:response];

	if (connection == _repoConnection) {
		[self setExpectedContentLengthFromResponse:response];
	}
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	if (connection == _userConnection) {
		NSMutableDictionary *repo = [_processQueue lastObject];
		NSString *username = [repo objectForKey:@"username"];

		NSString *jsonString = [[[NSString alloc] initWithData:_userData encoding:NSUTF8StringEncoding] autorelease];
		[_userData release];
		_userData = nil;
		NSDictionary *dict = [jsonString JSONValue];
		if (![dict isKindOfClass:[NSDictionary class]]) {
			[self cancelProgressSheet:nil];
			[progressDescription setStringValue:[NSString stringWithFormat:@"Failed to parse data for user %@.", username]];
			return;
		}

		DEBUG(@"got user %@: %@", username, dict);

		[progressDescription setStringValue:[NSString stringWithFormat:@"Loading repositories from %@...", username]];

		[_repoURL release];
		_repoURL = nil;
		NSString *type = [dict objectForKey:@"type"];
		if ([type isEqualToString:@"User"])
			_repoURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.github.com/users/%@/repos", username]];
		else if ([type isEqualToString:@"Organization"])
			_repoURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.github.com/orgs/%@/repos", username]];
		else {
			[self cancelProgressSheet:nil];
			[progressDescription setStringValue:[NSString stringWithFormat:@"Unknown type %@ of user %@", type, username]];
			return;
		}
		[_repoURL retain];
		_repoPage = 1;

		DEBUG(@"loading repositories from %@", _repoURL);

		[_repoJson release];
		_repoJson = [NSMutableArray new];
		[_repoData release];
		_repoData = [NSMutableData new];
		_repoConnection = [[NSURLConnection alloc] initWithRequest:
				   [NSURLRequest requestWithURL:_repoURL] delegate:self startImmediately:YES];
		return;
	}

	if (connection == _repoConnection) {
		NSString *jsonString = [[[NSString alloc] initWithData:_repoData encoding:NSUTF8StringEncoding] autorelease];
		NSArray *repoJson = [jsonString JSONValue];
		[_repoJson addObjectsFromArray:repoJson];

		NSDictionary *repoUser = [_processQueue lastObject];
		[self loadBundlesFromRepo:[repoUser objectForKey:@"username"]];
		[[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:@"LastBundleRepoReload"];

		if (repoJson.count == 0) {
			[_processQueue removeLastObject];
			if ([_processQueue count] == 0) {
				[NSApp endSheet:progressSheet];
			} else {
				[self reloadNextUser];
			}
		} else {
			NSURL *noQueryURL = [[[NSURL alloc] initWithScheme:_repoURL.scheme
								      host:_repoURL.host
								      path:_repoURL.path] autorelease];
			_repoPage++;
			[_repoURL release];
			_repoURL = [[NSURL URLWithString:
				     [NSString stringWithFormat:@"%@?page=%d", noQueryURL.absoluteString, _repoPage]] retain];
			DEBUG(@"Loading next page of repositories: %@", _repoURL);

			[_repoData release];
			_repoData = [NSMutableData new];
			[_repoConnection release];
			_repoConnection = [[NSURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:_repoURL]
									  delegate:self startImmediately:YES];
		}

		return;
	}

	[[_installPipe fileHandleForWriting] closeFile];

	[_installTask waitUntilExit];
	int status = [_installTask terminationStatus];
	[progressIndicator setIndeterminate:YES];

	NSMutableDictionary *repo = [_processQueue lastObject];
	NSString *owner = [[repo objectForKey:@"owner"] objectForKey:@"login"];
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

	[_processQueue removeLastObject];
	if ([_processQueue count] == 0)
		[NSApp endSheet:progressSheet];
	else
		[self installNextBundle];
}

- (void)installNextBundle
{
	NSMutableDictionary *repo = [_processQueue lastObject];

	[self resetProgressIndicator];
	[progressDescription setStringValue:[NSString stringWithFormat:@"Downloading and installing %@ (by %@)...",
	    [repo objectForKey:@"name"], [[repo objectForKey:@"owner"] objectForKey:@"login"]]];

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

	[_installTask release];
	_installTask = [[NSTask alloc] init];
	[_installTask setLaunchPath:@"/usr/bin/tar"];
	[_installTask setArguments:[NSArray arrayWithObjects:@"-x", @"-C", downloadDirectory, nil]];

	[_installPipe release];
	_installPipe = [[NSPipe alloc] init];
	[_installTask setStandardInput:_installPipe];

	@try {
		[_installTask launch];
	}
	@catch (NSException *exception) {
		[self cancelProgressSheet:nil];
		[progressDescription setStringValue:[NSString stringWithFormat:@"Installation of %@ failed: %@",
		    [repo objectForKey:@"displayName"], [exception reason]]];
		return;
	}

	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/tarball/master", [repo objectForKey:@"url"]]];

	[_installConnection release];
	_installConnection = [[NSURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:url] delegate:self];
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

	[_processQueue release];
	_processQueue = [[NSMutableArray alloc] initWithArray:selectedBundles];
	[self installNextBundle];
}

- (IBAction)uninstallBundles:(id)sender
{
}

@end
