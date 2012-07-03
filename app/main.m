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
