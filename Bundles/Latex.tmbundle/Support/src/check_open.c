/*
*	check_open.c	version 3.0
*
*   usage:   check_open [-s | -q] application [document]
*
*   Check whether a particular document is open in a particular application.
*	This is MUCH faster than using AppleScript.
*
*   The result is indicated by the status code:
*		0 - document is open;
*		1 - application not running: explanation printed to stdout unless -q switch given;
*		2 - application running, but document not open: explanation printed to stdout
*			unless -q switch given;
*		3 - application running, but can't tell whether document is open
*			because supplied document name cannot be encoded in MacRoman, or is too long.
*			Explanation printed to stderr, unless -s switch is given.
*		255 - an error occurred. Explanation printed to stderr, even if -q switch is given.
*
*   To build a Universal Binary:
*		gcc -arch ppc -arch i386 -isysroot /Developer/SDKs/MacOSX10.4u.sdk \
            -framework ApplicationServices check_open.c -o check_open
*
*	Robin Houston, April 2007; updated January 2008
*/

#include <stdio.h>
#include <string.h>
#include <Carbon/Carbon.h>

static bool give_up_silently = FALSE;

void give_up(const char *message)
{
	if (!give_up_silently)
		fprintf(stderr, "check_open: %s\n", message);
	exit(3);
}

void die_usage()
{
	fprintf(stderr, "check_open: Usage: check_open [-q | -s] application [document]\n");
	exit (255);
}

void print_detailed_usage()
{
	printf("Usage: check_open [-q | -s] application [document]\n\n");
	printf("Options:\n\t-q: quiet mode - don't print anything to stdout\n"
			"\t-s: silent mode - print nothing unless there's an unexpected error\n\n");
	printf("The status code indicates the result:\n");
	printf("  0  - document is open; nothing is printed in this case.\n");
	printf("  1  - application not running.\n");
	printf("  2  - application running, but document not open.\n");
	printf("  3  - application running, but can't tell whether document is open.\n"
			"\tbecause supplied document name cannot be encoded in MacRoman,\n\tor is too long,\n"
			"\tor because the application doesn't understand the relevant request.\n");
	printf(" 255 - an unexpected error occurred. Explanation printed to stderr.\n\n");
	printf("If the supplied document name begins with a slash (/) it is treated as a\n"
			"pathname, otherwise it is treated as a document name. If no document name\n"
			"is given, just the application will be checked. Note that the application\n"
			"name is not necessarily the same as the name that appears in the dock,\n"
			"though it usually is.\n\n");
	exit (255);
}

void die(const char *message)
{
	fprintf(stderr, "check_open: Unexpected error: %s\n", message);
	exit (255);
}

void list_open_applications()
{
	OSStatus status;
    ProcessSerialNumber currentProcessPSN = {kNoProcess, kNoProcess};

	status = GetNextProcess(&currentProcessPSN);
	while (status == noErr) {
		CFStringRef processName = NULL;
		char name[32];
		
		status = CopyProcessName(&currentProcessPSN, &processName);
		if (status != noErr)
			die("CopyProcessName failed");
		if (NULL == processName)
			die("CopyProcessName succeeded, but the process name is NULL!");
			
		CFStringGetCString(processName, &name[0], 32, kCFStringEncodingUTF8);
		printf("{ 0x%x, 0x%08x }  %s\n",
			currentProcessPSN.highLongOfPSN, currentProcessPSN.lowLongOfPSN,
			&name);
		
		status = GetNextProcess(&currentProcessPSN);
	}
}

bool application_is_open(CFStringRef appName, ProcessSerialNumber *psn)
{
	OSStatus status;
    ProcessSerialNumber currentProcessPSN = {kNoProcess, kNoProcess};

	status = GetNextProcess(&currentProcessPSN);
	while (status == noErr) {
		CFStringRef processName = NULL;
		
		status = CopyProcessName(&currentProcessPSN, &processName);
		if (status != noErr)
			die("CopyProcessName failed");
		if (NULL == processName)
			die("CopyProcessName succeeded, but the process name is NULL!");
			
		if (kCFCompareEqualTo == CFStringCompare(processName, appName, 0))
		{
			memcpy(psn, &currentProcessPSN, sizeof(*psn));
			return TRUE;
		}
		status = GetNextProcess(&currentProcessPSN);
	}
	return FALSE;
}

bool document_is_open(CFStringRef docNameCF, ProcessSerialNumber *psn)
{
	char          docNameData[255];
	char          *docName = &docNameData[0];
	OSStatus      status;
	AppleEvent    ae, reply;
	AEBuildError  buildError;
	char          returnValue;
	char          *eventDescriptor;
	
	/* Apple Events only support MacRoman, I think */
	if (!CFStringGetCString(docNameCF, docName, 255, kCFStringEncodingMacRoman))
		give_up("Document name could not be encoded as MacRoman, or too long");
	
	if (docName[0] == '/')
		eventDescriptor =
			"'----':obj{form:enum('test'),want:type('docu'),seld:cmpd{relo:=,"
			"'obj1':obj{form:prop, want:type('prop'), seld:type('ppth'), from:exmn()},"
			"'obj2':TEXT(@)},from:null()}";
	else
		eventDescriptor =
			"'----':obj{form:enum('name'),want:type('docu'),seld:TEXT(@),from:null()}";

	status = AEBuildAppleEvent(kAECoreSuite, kAEDoObjectsExist,
		typeProcessSerialNumber, psn, sizeof(*psn),
		kAutoGenerateReturnID, kAnyTransactionID, &ae,
		&buildError, eventDescriptor, docName);
	if (status != noErr) {
		fprintf(stderr, "check_open: AEBuildAppleEvent failed: error %d at pos %lu\n",
			buildError.fError, buildError.fErrorPos);
		fprintf(stderr, "(See http://developer.apple.com/technotes/tn/tn2045.html#errstable)\n");
		exit(255);
	}
	
	status = AESendMessage(&ae, &reply,	kAEWaitReply, kAEDefaultTimeout);
	if (status != noErr)
		die("AESend failed");
	
	status = AEGetParamPtr (&reply, keyDirectObject, typeBoolean, 
		NULL, &returnValue, 1, NULL);
	if (status != noErr)
		/* Presumably this is because the reply is an error message */
		give_up("Application appears not to understand request");
	
	return (returnValue != 0);
	
    /* We don't need to bother disposing of things, because we're about to finish */
}

int main(int argc, const char **argv)
{
	ProcessSerialNumber psn;
	int resultCode;
	bool printResult = TRUE;
	
	if (argc < 2) print_detailed_usage();

	if (!strcmp(argv[1], "--")) {
		argc -= 1; argv += 1;
	}
	else if (!strcmp(argv[1], "-q")) {
		argc -= 1; argv += 1;
		printResult = FALSE;
	}
	else if (!strcmp(argv[1], "-s")) {
		argc -= 1; argv += 1;
		printResult = FALSE;
		give_up_silently = TRUE;
	}
	else if (!strcmp(argv[1], "-l")) {
		list_open_applications();
		return 0;
	}
	
	if (argc > 3 || argc < 2) die_usage();
	
	if (application_is_open(
		CFStringCreateWithCString(kCFAllocatorDefault, argv[1], kCFStringEncodingUTF8),
		&psn))
	{
		if (argc == 2
		|| document_is_open(
			CFStringCreateWithCString(kCFAllocatorDefault, argv[2], kCFStringEncodingUTF8),
			&psn))
		{
			resultCode = 0;			
		}
		else resultCode = 2;
	}
	else resultCode = 1;
	
	if (printResult) {
		switch (resultCode) {
		case 1:
			printf("Application '%s' not running\n", argv[1]);
			break;
		case 2:
			printf("Document '%s' not open in application\n", argv[2]);
		}
	}
	return resultCode;
}