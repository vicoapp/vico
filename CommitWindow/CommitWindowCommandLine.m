//
//  CommitWindowCommandLine.m
//  CommitWindow
//
//  Created by Chris Thomas on 6/24/06.
//  Copyright 2006 Chris Thomas. All rights reserved.
//

#import "CommitWindowCommandLine.h"

#import "NSTask+CXAdditions.h"

@implementation CommitWindowController(CommandLine)

- (void) awakeFromNib
{
	NSProcessInfo * processInfo = [NSProcessInfo processInfo];
	NSArray *		args;
	int				i;
	int				argc;
	
	args = [processInfo arguments];
	argc = [args count];

	if( args == nil || argc < 2 )
	{
		fprintf(stderr, "commit window: Arguments required\n");
		[self cancel:nil];
	}
	
	//
	// Parse the command line.
	//
	// fDiffCommand and fActionCommands are set up according to the arguments given.
	//
	
	// Program name is the first argument -- get rid of it.
	argc -= 1;
	args = [args subarrayWithRange:NSMakeRange(1, argc)];

	// Populate our NSArrayController with the command line arguments
	for( i = 0; i < argc; i += 1 )
	{
		NSString *				argument	= [args objectAtIndex:i];
		
		if( [argument isEqualToString:@"--ask"] )
		{
			// Next argument should be the query text.
			if( i >= (argc - 1) )
			{
				fprintf(stderr, "commit window: missing text: --ask \"some text\"\n");
				[self cancel:nil];
			}
			
			i += 1;
			argument	= [args objectAtIndex:i];
			[fRequestText setStringValue:argument];
		}
		else if( [argument isEqualToString:@"--log"] )
		{
			// Next argument should be the initial log message text.
			if( i >= (argc - 1) )
			{
				fprintf(stderr, "commit window: missing text: --log \"log message text\"\n");
				[self cancel:nil];
			}
			
			i += 1;
			argument	= [args objectAtIndex:i];
			[fCommitMessage setString:argument];
		}
		else if( [argument isEqualToString:@"--status"] )
		{
			// Next argument should be a colon-seperated list of status strings, one for each path
			if( i >= (argc - 1) )
			{
				fprintf(stderr, "commit window: missing text: --status \"A:D:M:M:M\"\n");
				[self cancel:nil];
			}
			
			i += 1;
			argument	= [args objectAtIndex:i];
			fFileStatusStrings = [[argument componentsSeparatedByString:@":"] retain];
		}
		else if( [argument isEqualToString:@"--diff-cmd"] )
		{
			// Next argument should be a comma-seperated list of command arguments to use to execute the diff
			if( i >= (argc - 1) )
			{
				fprintf(stderr, "commit window: missing text: --diff-cmd \"/usr/bin/svn,diff\"\n");
				[self cancel:nil];
			}
			
			i += 1;
			argument	= [args objectAtIndex:i];
			fDiffCommand = [argument retain];
		}
		else if( [argument isEqualToString:@"--action-cmd"] )
		{
			//
			// --action-cmd provides an action that may be performed on a file.
			// Provide multiple action commands by passing --action-cmd multiple times, each with a different command argument.
			//
			// The argument to --action-cmd is two comma-seperated lists separated by a colon, of the form "A,M,D:Revert,/usr/local/bin/svn,revert"
			//	
			//	On the left side of the colon is a list of status character or character sequences; a file must have one of these
			//	for this command to be enabled.
			//
			//	On the right side  is a list:
			//		Item 1 is the human-readable name of the command.
			//		Item 2 is the path (either absolute or accessible via $PATH) to the executable.
			//		Items 3 through n are the arguments to the executable.
			//		CommitWindow will append the file path as the last argument before executing the command.
			//		Multiple paths may be appended in the future.
			//
			//	The executable should return a single line of the form "<new status character(s)><whitespace><file path>" for each path.
			//
			//  For Subversion, commands might be:
			//		"?:Add,/usr/local/bin/svn,add"
			//		"A:Mark Executable,/usr/local/bin/svn,propset,svn:executable,true"
			//		"A,M,D,C:Revert,/usr/local/bin/svn,revert"
			//		"C:Resolved,/usr/local/bin/svn,resolved"
			//
			//	Only the first colon is significant, so that, for example, 'svn:executable' in the example above works as expected.
			//	This does scheme assume that neither comma nor colon will be used in status sequences. The file paths themselves may contain
			//	commas, since those are handled out of bounds. We could introduce comma or colon quoting if needed. But I hope not.
			//	
			if( i >= (argc - 1) )
			{
				fprintf(stderr, "commit window: missing text: --action-cmd \"M,Revert,/usr/bin/svn,revert\"\n");
				[self cancel:nil];
			}
			
			i += 1;
			argument	= [args objectAtIndex:i];
			
			// Get status strings
			NSString *	statusSubstringString;
			NSString *	commandArgumentString;
			NSArray *	statusSubstrings;
			NSArray *	commandArguments;
			NSRange		range;
			
			range = [argument rangeOfString:@":"];
			if(range.location == NSNotFound)
			{
				fprintf(stderr, "commit window: missing ':' in --action-cmd\n");
				[self cancel:nil];
			}
			
			statusSubstringString	= [argument substringToIndex:range.location];
			commandArgumentString	= [argument substringFromIndex:NSMaxRange(range)];
			
			statusSubstrings	= [statusSubstringString componentsSeparatedByString:@","];
			commandArguments	= [commandArgumentString componentsSeparatedByString:@","];
			
			unsigned int	statusSubstringCount = [statusSubstrings count];
			
			// Add the command to each substring
			for(unsigned int index = 0; index < statusSubstringCount; index += 1)
			{
				NSString *	statusSubstring = [statusSubstrings objectAtIndex:index];

				[self addAction:[commandArguments objectAtIndex:0]
						command:[commandArguments subarrayWithRange:NSMakeRange(1, [commandArguments count] - 1)]
						forStatus:statusSubstring];
			}
		}
		else
		{
			NSMutableDictionary *	dictionary	= [fFilesController newObject];

			[dictionary setObject:[argument stringByAbbreviatingWithTildeInPath] forKey:@"path"];
			[fFilesController addObject:dictionary];
		}
	}
	
	//
	// Done processing arguments, now add status to each item
	// 								and choose default commit state
	//
	[self setupUserInterface];
	
}


#if 0
#pragma mark -
#pragma mark Actions
#endif



- (IBAction) commit:(id) sender
{
	NSArray *			objects = [fFilesController arrangedObjects];
	int					i;
	int					pathsToCommitCount = 0;
	NSMutableString *	commitString;
	
	[self saveSummary];
	
	//
	// Quote any single-quotes in the commit message
	// \' doesn't work with bash. We must use string concatenation.
	// This sort of thing is why the Unix Hater's Handbook exists.
	//
	commitString = [[[fCommitMessage string] mutableCopy] autorelease];
	[commitString replaceOccurrencesOfString:@"'" withString:@"'\"'\"'" options:0 range:NSMakeRange(0, [commitString length])];
	
	fprintf(stdout, "-m '%s' ", [commitString UTF8String] );
	
	//
	// Return only the files we care about
	//
	for( i = 0; i < [objects count]; i += 1 )
	{
		NSMutableDictionary *	dictionary;
		NSNumber *				commit;
		
		dictionary	= [objects objectAtIndex:i];
		commit		= [dictionary objectForKey:@"commit"];
		
		if( commit == nil || [commit boolValue] )	// missing commit key defaults to true
		{
			NSMutableString *		path;
			
			//
			// Quote any single-quotes in the path
			//
			path = [dictionary objectForKey:@"path"];
			path = [[[path stringByStandardizingPath] mutableCopy] autorelease];
			[path replaceOccurrencesOfString:@"'" withString:@"'\"'\"'" options:0 range:NSMakeRange(0, [path length])];

			fprintf( stdout, "'%s' ", [path UTF8String] );
			pathsToCommitCount += 1;
		}
	}
	
	fprintf( stdout, "\n" );
	
	//
	// SVN will commit the current directory, recursively, if we don't specify files.
	// So, to prevent surprises, if the user's unchecked all the boxes, let's be on the safe side and cancel.
	//
	if( pathsToCommitCount == 0 )
	{
		[self cancel:nil];
	}
	
	[NSApp terminate:self];
}

- (IBAction) cancel:(id) sender
{
	[self saveSummary];
		
	fprintf(stdout, "commit window: cancel\n");
	exit(-128);
}


- (IBAction) doubleClickRowInTable:(id)sender
{
	if( fDiffCommand != nil )
	{
		static NSString *	sCommandAbsolutePath = nil;

		NSMutableArray *	arguments	= [[fDiffCommand componentsSeparatedByString:@","] mutableCopy];
		NSString *			filePath	= [[[[fFilesController arrangedObjects] objectAtIndex:[sender selectedRow]] objectForKey:@"path"] stringByStandardizingPath];
		NSData *			diffData;
		NSString *			errorText;
		int					exitStatus;
		
		// Resolve the command to an absolute path (only do this once per launch)
		if(sCommandAbsolutePath == nil)
		{
			sCommandAbsolutePath = [[self absolutePathForPath:[arguments objectAtIndex:0]] retain];
		}
		[arguments replaceObjectAtIndex:0 withObject:sCommandAbsolutePath];

		// Run the diff
		[arguments addObject:filePath];
		exitStatus = [NSTask executeTaskWithArguments:arguments
			    					input:nil
			                        outputData:&diffData
			                        errorString:&errorText];
		[self checkExitStatus:exitStatus forCommand:arguments errorText:errorText];

		// Success, send the diff to TextMate
		arguments = [NSArray arrayWithObjects:[NSString stringWithFormat:@"%s/bin/mate", getenv("TM_SUPPORT_PATH")], @"-a", nil];
		
		exitStatus = [NSTask executeTaskWithArguments:arguments
			    					input:diffData
			                        outputData:nil
			                        errorString:&errorText];
		[self checkExitStatus:exitStatus forCommand:arguments errorText:errorText];
	}
}


@end
