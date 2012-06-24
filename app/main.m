#import "Nu.h"

#include <sys/types.h>
#include <sys/ptrace.h>
#include <sys/time.h>

#include <pthread.h>
#include <signal.h>

#import "ViTextView.h"

pthread_mutex_t onig_mutex = PTHREAD_MUTEX_INITIALIZER;

struct timeval launch_start;
extern BOOL openUntitledDocument;

__attribute__((visibility("default"))) void
nu_log(NSString *msg)
{
	NSLog(@"%@", msg);
}

int
main(int argc, char *argv[])
{
	gettimeofday(&launch_start, NULL);
	signal(SIGPIPE, SIG_IGN);
	NuInit();

	for (int i = 1; i < argc; i++) {
		if (strcmp(argv[i], "-skip-untitled") == 0)
			openUntitledDocument = NO;
	}

	return NSApplicationMain(argc, (const char **) argv);
}
