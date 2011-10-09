//
//  NSTask+CXAdditions.h
//
//  Created by Chris Thomas on 2006-10-20.
//  Copyright 2006 Chris Thomas. All rights reserved.
//


@interface NSTask (CXAdditions)

// For the three methods below:
//	Argument index 0 is an absolute path to the executable.
//	Each file/data/string output is allocated and returned to the caller unless the caller passes NULL.
//	input may be NULL, an NSString object, or an NSData object.

// Return a task (not yet launched) and optionally allocate stdout/stdin/stderr streams for communication with it
+ (NSTask *) taskWithArguments:(NSArray *)arguments
						input:(NSFileHandle **)outWriteHandle
						output:(NSFileHandle **)outReadHandle
						error:(NSFileHandle **)outErrorHandle;

// Atomically execute the task and return output as data
+ (int) executeTaskWithArguments:(NSArray *)args
    					input:(id)inputDataOrString
                        outputData:(NSData **)outputData
                        errorString:(NSString **)errorString;

// Atomically execute the task and return output as string
+ (int) executeTaskWithArguments:(NSArray *)args
    					input:(id)inputDataOrString
                        outputString:(NSString **)outputString
                        errorString:(NSString **)errorString;

@end
