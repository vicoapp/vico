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
	returnObject = obj;
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
	const char				*eval_script = NULL;
	const char				*eval_file = NULL;
	int					 i, c;
	BOOL					 runLoop = NO;
	BOOL					 params_from_stdin = NO;

	bindings = [NSMutableDictionary dictionary];

	while ((c = getopt(argc, argv, "e:f:hp:r")) != -1) {
		switch (c) {
		case 'e':
			eval_script = optarg;
			break;
		case 'f':
			eval_file = optarg;
			break;
		case 'h':
			printf("DON'T PANIC\n");
			return 0;
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
		case '?':
		default:
			exit(1);
		}
	}

	NSString *connName = [NSString stringWithFormat:@"vico.%u", (unsigned int)getuid()];
	proxy = [NSConnection rootProxyForConnectionWithRegisteredName:connName
	                                                          host:nil];
	if (proxy == nil) {
		/* failed to connect, try to start it */
		CFStringRef bundle_id = CFSTR("se.bzero.Vico");
		FSRef appRef;
		if (LSFindApplicationForInfo(kLSUnknownCreator, bundle_id, NULL, &appRef, NULL) == 0 &&
		    LSOpenFSRef(&appRef, NULL) == 0) {
			for (i = 0; i < 50 && proxy == nil; i++) {
				usleep(200000); // sleep for 0.2 seconds
				proxy = [NSConnection rootProxyForConnectionWithRegisteredName:connName
											  host:nil];
			}
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

	if (script) {
		NSConnection *backConn = nil;
		if (runLoop) {
			backConn = [NSConnection new];
			[backConn setRootObject:[[ShellThing alloc] init]];
			[backConn registerName:@"crunchy frog"];
		}

		NSString *errStr = nil;
		NSString *result = nil;
		@try {
			result = [proxy eval:script
			      withScriptPath:script_path
			  additionalBindings:bindings
			         errorString:&errStr
			         backChannel:runLoop ? @"crunchy frog" : nil];
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

		if (errStr) {
			fprintf(stderr, "%s\n", [errStr UTF8String]);
			return 3;
		}
		if (!runLoop && [result length] > 0)
			printf("%s\n", [result UTF8String]);
	}

	/*
	 * Treat remainder of arguments as files that should be opened.
	 */
	argc -= optind;
	argv += optind;

	for (i = 0; i < argc; i++) {
		NSString *path = [NSString stringWithUTF8String:argv[i]];
		if ([path rangeOfString:@"://"].location == NSNotFound) {
			path = [path stringByExpandingTildeInPath];
			if (![path isAbsolutePath])
				path = [[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:path];
			path = [[NSURL fileURLWithPath:path] absoluteString];
		}
		error = [proxy openURL:path];
		if (error)
			errx(2, "%s: %s", argv[i], [[error localizedDescription] UTF8String]);
	}

	if (argc == 0 && script == nil) {
		/* just make it first responder */
		[proxy eval:@"((NSApplication sharedApplication) activateIgnoringOtherApps:YES)"
	     withScriptPath:nil
	 additionalBindings:nil
	        errorString:nil
	        backChannel:nil];
	}

	if (runLoop && script) {
		NSRunLoop *loop = [NSRunLoop currentRunLoop];
		while (keepRunning && [loop runMode:NSDefaultRunLoopMode
				         beforeDate:[NSDate distantFuture]])
			;

		if (returnObject != nil) {
			NSString *returnJSON = [returnObject JSONRepresentation];
			printf("%s\n", [returnJSON UTF8String]);
		}
	}

	return returnCode;
}

