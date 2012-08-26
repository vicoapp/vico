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

#import <Cocoa/Cocoa.h>

#include <sys/time.h>

#include <err.h>
#include <stdlib.h>
#include <unistd.h>

#import "ViAppController.h"
#import "JSON.h"

BOOL keepRunning = YES;
int returnCode = 0;
id returnObject = nil;

@interface ShellThing : NSObject <ViShellThingProtocol>
{
}
@end

@implementation ShellThing

- (void)exit
{
	keepRunning = NO;
}

- (void)exitWithObject:(id)obj
{
	keepRunning = NO;
	returnObject = [obj retain];
}

- (void)exitWithError:(int)code
{
	keepRunning = NO;
	returnCode = code;
}

- (void)log:(NSString *)message
{
	fprintf(stderr, "%s\n", [message UTF8String]);
}

@end

void
usage(void)
{
	printf("syntax: vicotool [-hrw] [-e string] [-f file] [-p params] [file ...]\n");
	printf("options:\n");
	printf("    -h            show this help\n");
	printf("    -e string     evaluate the string as a Nu script\n");
	printf("    -f file       read file and evaluate as a Nu script\n");
	printf("    -n            open files in a new window\n");
	printf("    -p params     read script parameters as a JSON string\n");
	printf("    -p -          read script parameters as JSON from standard input\n");
	printf("    -r            enter runloop (don't exit script immediately)\n");
	printf("    -w            wait for document to close\n");
}

int
main(int argc, char **argv)
{
	NSProxy<ViShellCommandProtocol>		*proxy;
	NSString				*script = nil;
	NSString				*script_path = nil;
	NSString				*json;
	NSError					*error = nil;
	NSFileHandle				*handle;
	NSMutableDictionary			*bindings = nil;
	NSDictionary				*params;
	NSAutoreleasePool			*pool;
	const char				*eval_script = NULL;
	const char				*eval_file = NULL;
	int					 i, c;
	BOOL					 runLoop = NO;
	BOOL					 params_from_stdin = NO;
	BOOL					 wait_for_close = NO;
	BOOL					 new_window = NO;

	pool = [[NSAutoreleasePool alloc] init];
	bindings = [NSMutableDictionary dictionary];

	while ((c = getopt(argc, argv, "e:f:hnp:rw")) != -1) {
		switch (c) {
		case 'e':
			eval_script = optarg;
			break;
		case 'f':
			eval_file = optarg;
			break;
		case 'h':
			usage();
			return 0;
		case 'n':
			new_window = YES;
			break;
		case 'p':
			if (strcmp(optarg, "-") == 0) {
				params_from_stdin = YES;
			} else {
				if ((json = [NSString stringWithUTF8String:optarg]) == nil)
					errx(1, "parameters not proper UTF8");
				if ((params = [json JSONValue]) == nil)
					errx(1, "parameters not proper JSON");
				if (![params isKindOfClass:[NSDictionary class]])
					errx(1, "parameters not a JSON object");
				[bindings addEntriesFromDictionary:params];
			}
			break;
		case 'r':
			runLoop = YES;
			break;
		case 'w':
			wait_for_close = YES;
			break;
		case '?':
		default:
			exit(1);
		}
	}

	/*
	 * Treat remainder of arguments as files that should be opened.
	 */
	argc -= optind;
	argv += optind;

	if (argc > 1 && wait_for_close)
		errx(6, "can't wait for multiple files");
	if (argc == 0 && wait_for_close)
		errx(6, "no document to wait for");
	if (runLoop && eval_script == nil && eval_file == nil)
		errx(6, "no script to wait for");

	if (wait_for_close && (eval_script || eval_file))
		errx(1, "can't both evaluate script and wait for document");

	NSString *connName = [NSString stringWithFormat:@"vico.%u", (unsigned int)getuid()];
	proxy = (NSProxy<ViShellCommandProtocol> *)[NSConnection rootProxyForConnectionWithRegisteredName:connName
												     host:nil];
	if (proxy == nil) {
		/* failed to connect, try to start it */
		CFStringRef bundle_id = CFSTR("se.bzero.Vico");
		FSRef appRef;
		LSApplicationParameters params;
		bzero(&params, sizeof(params));
		params.flags = kLSLaunchNoParams;
		if (LSFindApplicationForInfo(kLSUnknownCreator, bundle_id, NULL, &appRef, NULL) != 0)
			errx(1, "failed to find Vico");

		params.application = &appRef;

		if (argc > 0) {
			const void *values[] = { CFSTR("-skip-untitled") };
			params.argv = CFArrayCreate(NULL, values, 1, &kCFTypeArrayCallBacks);
		}

		if (LSOpenApplication(&params, NULL) != 0)
			errx(1, "failed to start Vico");

		for (i = 0; i < 50 && proxy == nil; i++) {
			usleep(200000); // sleep for 0.2 seconds
			proxy = (NSProxy<ViShellCommandProtocol> *)[NSConnection rootProxyForConnectionWithRegisteredName:connName
														     host:nil];
		}

		if (proxy == nil)
			errx(1, "failed to connect");
	}

	if (eval_file) {
		if (strcmp(eval_file, "-") == 0) {
			handle = [NSFileHandle fileHandleWithStandardInput];
			script_path = @"stdin";
		} else {
			script_path = [[NSString stringWithUTF8String:eval_file] stringByExpandingTildeInPath];
			NSURL *url = [NSURL fileURLWithPath:script_path isDirectory:NO];
			handle = [NSFileHandle fileHandleForReadingFromURL:url error:&error];
		}

		if (error)
			errx(2, "%s: %s", eval_file, [[error localizedDescription] UTF8String]);
		NSData *data = [handle readDataToEndOfFile];
		if (data == nil)
			errx(2, "%s: read failure", eval_file);
		script = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		if (script == nil)
			errx(2, "%s: invalid UTF8 encoding", eval_file);
	} else if (eval_script) {
		script_path = @"command line";
		script = [NSString stringWithUTF8String:eval_script];
		if (script == nil)
			errx(2, "invalid UTF8 encoding");
	}

	if (params_from_stdin) {
		handle = [NSFileHandle fileHandleWithStandardInput];
		NSData *data = [handle readDataToEndOfFile];
		if (data == nil)
			errx(2, "stdin: read failure");
		if ((json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]) == nil)
			errx(1, "parameters not proper UTF8");
		if ((params = [json JSONValue]) == nil)
			errx(1, "parameters not proper JSON");
		if (![params isKindOfClass:[NSDictionary class]])
			errx(1, "parameters not a JSON object");
		[bindings addEntriesFromDictionary:params];
	}

	NSString *backChannelName = nil;
	if (runLoop || wait_for_close) {
		NSConnection *backConn = nil;
		backConn = [NSConnection new];
		[backConn setRootObject:[[ShellThing alloc] init]];
		backChannelName = [NSString stringWithFormat:@"vicotool.%u", getpid()];
		[backConn registerName:backChannelName];
	}

	@try {

		if (script) {
			NSString *errStr = nil;
			NSString *result = nil;
			result = [proxy eval:script
			  additionalBindings:bindings
				 errorString:&errStr
				 backChannel:backChannelName];

			if (errStr) {
				fprintf(stderr, "%s\n", [errStr UTF8String]);
				return 3;
			}
			if (!runLoop && [result length] > 0)
				printf("%s\n", [result UTF8String]);
		}

		if (argc > 0 && new_window)
			[proxy newProject:nil];

		for (i = 0; i < argc; i++) {
			NSString *path = [NSString stringWithUTF8String:argv[i]];

			if (i == 0 && [path isEqualToString:@"-"]) {
				handle = [NSFileHandle fileHandleWithStandardInput];
				NSData *data = [handle readDataToEndOfFile];
				[proxy newDocumentWithData:data andWait:wait_for_close backChannel:backChannelName];
				break;
			}
				
			if ([path rangeOfString:@"://"].location == NSNotFound) {
				path = [path stringByExpandingTildeInPath];
				if (![path isAbsolutePath])
					path = [[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:path];
				path = [[[NSURL fileURLWithPath:path] URLByResolvingSymlinksInPath] absoluteString];
			}
			error = [proxy openURL:path andWait:wait_for_close backChannel:backChannelName];
			if (error)
				errx(2, "%s: %s", argv[i], [[error localizedDescription] UTF8String]);
		}

		if (argc == 0 && script == nil) {
			/* just make it first responder */
			[proxy eval:@"((NSApplication sharedApplication) activateIgnoringOtherApps:YES)"
			      error:nil];
		}

		if ((runLoop && script) || wait_for_close) {
			NSRunLoop *loop = [NSRunLoop currentRunLoop];
			while (keepRunning && [loop runMode:NSDefaultRunLoopMode
						 beforeDate:[NSDate distantFuture]])
				;

			if (returnObject != nil) {
				NSString *returnJSON = [returnObject JSONRepresentation];
				printf("%s\n", [returnJSON UTF8String]);
			}
		}
	}
	@catch (NSException *exception) {
		NSString *msg = [NSString stringWithFormat:@"%@: %@",
		    [exception name], [exception reason]];
		/* We don't print the callStackSymbols, as
		 * they are not useful (they will just point
		 * to [NSConnection sendInvocation:]).
		 */
		fprintf(stderr, "%s\n", [msg UTF8String]);
		return 5;
	}

	[pool release];

	return returnCode;
}
