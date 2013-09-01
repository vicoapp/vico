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

#import "ViPathCell.h"
#import "ViPathComponentCell.h"
#import "ViURLManager.h"
#import "NSURL-additions.h"
#include "logging.h"

@implementation ViPathCell

+ (Class)pathComponentCellClass
{
	return [ViPathComponentCell class];
}

- (void)setURL:(NSURL *)url
{
        if ([url isFileURL]) {
                [super setURL:url];
                return;
        }

        NSMutableArray *components = [NSMutableArray array];
        NSImage *folderIcon = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode('fldr')];
        // NSImage *homeIcon = [NSImage imageNamed:NSImageNameHomeTemplate];
        NSImage *homeIcon = [[NSWorkspace sharedWorkspace] iconForFile:NSHomeDirectory()];
        NSURL *homeURL = [[ViURLManager defaultManager] normalizeURL:[NSURL URLWithString:@"~" relativeToURL:url]];

        while (![[url path] isEqualToString:@"/"]) {
                ViPathComponentCell *cell = [[ViPathComponentCell alloc] initTextCell:[url lastPathComponent]];
                [cell setURL:url];
                [cell setFont:[self font]];
                [components insertObject:cell atIndex:0];

                if ([homeURL isEqualToURL:url]) {
                        [cell setImage:homeIcon];
                        if ([components count] > 1) {
                                url = [NSURL URLWithString:@"/" relativeToURL:url];
                                /* Skip parents if we're in a subdirectory to the home directory. */
                                break;
                        }
                } else
                        [cell setImage:folderIcon];

                url = [url URLByDeletingLastPathComponent];
        }

        ViPathComponentCell *cell = [[ViPathComponentCell alloc] initTextCell:[url host]];
        [cell setImage:[NSImage imageNamed:NSImageNameNetwork]];
        [cell setURL:url];
        [cell setFont:[self font]];
        [components insertObject:cell atIndex:0];

        [self setPathComponentCells:components];
}

@end
