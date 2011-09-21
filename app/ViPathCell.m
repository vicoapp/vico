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
                ViPathComponentCell *cell = [[[ViPathComponentCell alloc] initTextCell:[url lastPathComponent]] autorelease];
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

        ViPathComponentCell *cell = [[[ViPathComponentCell alloc] initTextCell:[url host]] autorelease];
        [cell setImage:[NSImage imageNamed:NSImageNameNetwork]];
        [cell setURL:url];
        [cell setFont:[self font]];
        [components insertObject:cell atIndex:0];

        [self setPathComponentCells:components];
}

@end
