//
//  NSTask+CXAdditions.m
//
//  Created by Chris Thomas on 2006-10-20.
//  Copyright 2006 Chris Thomas. All rights reserved.
//

#import "NSTask+CXAdditions.h"

@interface NSFileHandle (CXAdditions)
- (NSData *) reallyReadDataToEndOfFile;
@end

@implementation NSFileHandle (CXAdditions)

// This method exists mainly for ease of debugging.  readDataToEndOfFile should actually do the job.
- (NSData *) reallyReadDataToEndOfFile
{
	NSMutableData *	outData = [[[NSMutableData alloc] init] autorelease];
	NSData *		currentData;
	
	currentData = [self availableData];
	while( currentData != nil && [currentData length] > 0 )
	{
		[outData appendData:currentData];
		currentData = [self availableData];
	}
		
	return outData;
}
@end

@implementation NSTask (CXAdditions)

// helper method called in its own thread and writes data to a file descriptor
+ (void)writeDataToFileHandleAndClose:(id)someArguments
{
	NSAutoreleasePool*	pool	= [NSAutoreleasePool new];
	NSFileHandle *		fh		= [someArguments objectForKey:@"fileHandle"];
	NSData *			data	= [someArguments objectForKey:@"data"];

	if( fh != nil && data != nil )
	{
		[fh writeData:data];
		[fh closeFile];
	}
	
	[pool release];
}

// Return a task (not yet launched) and optionally allocate stdout/stdin/stderr streams for communication with it
+ (NSTask *) taskWithArguments:(NSArray *)args
						input:(NSFileHandle **)outWriteHandle
						output:(NSFileHandle **)outReadHandle
						error:(NSFileHandle **)outErrorHandle
{
	NSTask *task = [[[NSTask alloc] init] autorelease];
    
	[task setLaunchPath:[args objectAtIndex:0]];
	[task setArguments:[args subarrayWithRange:NSMakeRange(1, [args count] - 1)]];
	
	if( outReadHandle != NULL )
	{
		NSPipe *		readPipe	= [NSPipe pipe];
		NSFileHandle *	readHandle	= [readPipe fileHandleForReading];

	    [task setStandardOutput:readPipe];
		*outReadHandle = readHandle;
	}
	
	if( outWriteHandle != NULL )
	{
		NSPipe *		writePipe	= [NSPipe pipe];
		NSFileHandle *	writeHandle	= [writePipe fileHandleForWriting];

	    [task setStandardInput:writePipe];
		*outWriteHandle = writeHandle;
	}
	
	if( outErrorHandle != NULL )
	{
		NSPipe *		errorPipe	= [NSPipe pipe];
		NSFileHandle *	errorHandle	= [errorPipe fileHandleForReading];

	    [task setStandardError:errorPipe];
		*outErrorHandle = errorHandle;
	}
	
	return task;
}

// Atomically execute the task and return output as data
+ (int) executeTaskWithArguments:(NSArray *)args
    					input:(id)inputDataOrString
                        outputData:(NSData **)outputData
                        errorString:(NSString **)errorString;
{
	
	NSFileHandle *		outputFile	= nil;
	NSFileHandle *		inputFile	= nil;
	NSFileHandle *		errorFile	= nil;
	NSTask *			task;
	
	task = [NSTask taskWithArguments:args
		 				input:(inputDataOrString == nil) ? NULL : &inputFile
						output:(outputData == NULL) ? NULL : &outputFile
						error:(errorString == NULL) ? NULL : &errorFile];

	if( inputDataOrString != nil )
	{
		// Convert string to UTF8 data
		if( [inputDataOrString isKindOfClass:[NSString class]] )
		{
			inputDataOrString = [inputDataOrString dataUsingEncoding:NSUTF8StringEncoding];
		}
	
		NSDictionary* arguments = [NSDictionary dictionaryWithObjectsAndKeys:
			inputFile,			@"fileHandle",
			inputDataOrString,	@"data",
			nil];
		[NSThread detachNewThreadSelector:@selector(writeDataToFileHandleAndClose:) toTarget:self withObject:arguments];
	}
	[task launch];

	// output data
	if( outputData != NULL )
	{
		*outputData = [outputFile reallyReadDataToEndOfFile];
	}

	// convert error data to string
	if( errorString != NULL )
	{
		NSData * errorData = [errorFile reallyReadDataToEndOfFile];
		
		*errorString = [[[NSString alloc] initWithData:errorData
										   	encoding:NSUTF8StringEncoding] autorelease];
	}

	[task waitUntilExit];
	return [task terminationStatus];
}

+ (int) executeTaskWithArguments:(NSArray *)args
    					input:(id)inputDataOrString
                        outputString:(NSString **)outputString
                        errorString:(NSString **)errorString;
{
	NSData *	outputData;
	int			terminationStatus;
	
	terminationStatus = [self executeTaskWithArguments:args
											input:inputDataOrString
											outputData:(outputString == NULL) ? NULL : &outputData
											errorString:errorString];
	
	if( outputString != nil )
	{
		*outputString = [[[NSString alloc] initWithData:outputData
										   	encoding:NSUTF8StringEncoding] autorelease];
	}
	
	return terminationStatus;
}

@end
