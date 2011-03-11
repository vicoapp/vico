#import <Cocoa/Cocoa.h>

#include <err.h>
#include <stdlib.h>
#include <unistd.h>

#import "ViAppController.h"

int
main(int argc, char **argv)
{
	NSProxy<ViShellCommandProtocol>		*proxy;
	NSString	*script = nil;
	NSString	*script_path = nil;
	const char	*eval_script = NULL;
	const char	*eval_file = NULL;
	int		 i, c;

	while ((c = getopt(argc, argv, "e:f:h")) != -1) {
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
		case '?':
		default:
			exit(1);
		}
	}

	proxy = [NSConnection rootProxyForConnectionWithRegisteredName:@"chunky bacon"
	                                                          host:nil];
	if (proxy == nil) {
		/* failed to connect, try to start it */
		if ([[NSWorkspace sharedWorkspace] launchApplication:@"Vibrant"]) {
			for (i = 0; i < 15 && proxy == nil; i++) {
				usleep(200000); // sleep for 0.2 seconds
				proxy = [NSConnection rootProxyForConnectionWithRegisteredName:@"chunky bacon"
											  host:nil];
			}
		}
		if (proxy == nil)
			errx(1, "failed to connect");
	}

	if (eval_file) {
		NSError *error = nil;
		NSFileHandle *handle;
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

	if (script) {
		NSString *errStr = nil;
		NSString *result = nil;
		@try {
			result = [proxy eval:script withScriptPath:script_path errorString:&errStr];
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

		if (result == nil) {
			fprintf(stderr, "%s\n", [errStr UTF8String]);
			return 3;
		}
		if ([result length] > 0)
			printf("%s\n", [result UTF8String]);
	}

	/*
	 * Treat remainder of arguments as files that should be opened.
	 */
	argc -= optind;
	argv += optind;

	for (i = 0; i < argc; i++) {
		NSString *path = [[NSString stringWithUTF8String:argv[i]] stringByExpandingTildeInPath];
		NSURL *url = [NSURL fileURLWithPath:path isDirectory:NO];
		NSError *error = [proxy openURL:url];
		if (error)
			errx(2, "%s: %s", argv[i], [[error localizedDescription] UTF8String]);
	}

	if (argc == 0) {
		/* just make it first responder */
		[proxy eval:@"NSApp.activateIgnoringOtherApps(YES)" withScriptPath:nil errorString:nil];
	}

	return 0;
}

