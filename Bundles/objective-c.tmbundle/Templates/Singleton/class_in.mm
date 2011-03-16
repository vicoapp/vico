//
//  ${TM_NEW_FILE_BASENAME}.mm
//
//  Created by ${TM_FULLNAME} on ${TM_DATE}.
//  Copyright (c) ${TM_YEAR} ${TM_ORGANIZATION_NAME}. All rights reserved.
//

#import "${TM_NEW_FILE_BASENAME}.h"

static ${TM_NEW_FILE_BASENAME}* SharedInstance;

@implementation ${TM_NEW_FILE_BASENAME}
+ (${TM_NEW_FILE_BASENAME}*)sharedInstance
{
	return SharedInstance ?: [[self new] autorelease];
}

- (id)init
{
	if(SharedInstance)
	{
		[self release];
	}
	else if(self = SharedInstance = [[super init] retain])
	{
		/* init code */
	}
	return SharedInstance;
}
@end
