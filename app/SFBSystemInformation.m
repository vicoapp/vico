/*
 *  Copyright (C) 2009 Stephen F. Booth <me@sbooth.org>
 *  All Rights Reserved
 */

#import "SFBSystemInformation.h"

#include <sys/sysctl.h>
#include <mach/machine.h>

// ========================================
// Utility functions for common sysctl to Cocoa tasks
// ========================================
static NSString * stringForMIB(int *mib, u_int mib_length, NSError **error)
{
	NSCParameterAssert(NULL != mib);

	char *buffer = NULL;
	size_t length = 0;

	// Determine the size of the data
	if(-1 == sysctl(mib, mib_length, NULL, &length, NULL, 0)) {
		if(error)
			*error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
		return nil;
	}

	// Allocate space (includes the terminator)
	buffer = malloc(length);
	if(!buffer) {
		if(error)
			*error = [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOMEM userInfo:nil];
		return nil;
	}

	// Fetch the property
	if(-1 == sysctl(mib, mib_length, buffer, &length, NULL, 0)) {
		free(buffer), buffer = NULL;
		if(error)
			*error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
		return nil;
	}

	// Ensure the memory is freed if an error occurs
	NSString *result = [[NSString alloc] initWithBytesNoCopy:buffer length:(length - 1) encoding:NSASCIIStringEncoding freeWhenDone:YES];
	if(!result) {
		free(buffer), buffer = NULL;
		if(error)
			*error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
		return nil;
	}

	return [result autorelease];
}

static NSNumber * intForMIB(int *mib, u_int mib_length, NSError **error)
{
	NSCParameterAssert(NULL != mib);

	int value = 0;
	size_t length = sizeof(value);

	// Fetch the property
	if(-1 == sysctl(mib, mib_length, &value, &length, NULL, 0)) {
		if(error)
			*error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
		return nil;
	}

	return [NSNumber numberWithInt:value];
}

static NSNumber * int64ForMIB(int *mib, u_int mib_length, NSError **error)
{
	NSCParameterAssert(NULL != mib);

	int64_t value = 0;
	size_t length = sizeof(value);

	// Fetch the property
	if(-1 == sysctl(mib, mib_length, &value, &length, NULL, 0)) {
		if(error)
			*error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
		return nil;
	}

	return [NSNumber numberWithLongLong:value];
}

static NSNumber * int32ForSysctlName(const char *name, NSError **error)
{
	NSCParameterAssert(NULL != name);

	int32_t value = 0;
	size_t length = sizeof(value);

	// Fetch the property
	if(-1 == sysctlbyname(name, &value, &length, NULL, 0)) {
		if(error)
			*error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
		return nil;
	}

	return [NSNumber numberWithLong:value];
}

static NSNumber * int64ForSysctlName(const char *name, NSError **error)
{
	NSCParameterAssert(NULL != name);

	int64_t value = 0;
	size_t length = sizeof(value);

	// Fetch the property
	if(-1 == sysctlbyname(name, &value, &length, NULL, 0)) {
		if(error)
			*error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
		return nil;
	}

	return [NSNumber numberWithLongLong:value];
}

@implementation SFBSystemInformation

- (NSString *) machine
{
	int mib [] = { CTL_HW, HW_MACHINE };
	return stringForMIB(mib, 2, NULL);
}

- (NSString *) model
{
	int mib [] = { CTL_HW, HW_MODEL };
	return stringForMIB(mib, 2, NULL);
}

- (NSString *) modelName
{
	return [self model];
#if 0
	NSString *model = [self model];
	NSString *path = [[NSBundle mainBundle] pathForResource:@"macmodels" ofType:@"plist"];
	if(model && path) {
		NSDictionary *models = [NSDictionary dictionaryWithContentsOfFile:path];
		return [models objectForKey:model];
	}
	else
		return nil;
#endif
}

- (NSNumber *) numberOfCPUs
{
	int mib [] = { CTL_HW, HW_NCPU };
	return intForMIB(mib, 2, NULL);
}

- (NSNumber *) physicalMemory
{
	int mib [] = { CTL_HW, HW_MEMSIZE };
	return int64ForMIB(mib, 2, NULL);
}

- (NSNumber *) busFrequency
{
	return int64ForSysctlName("hw.busfrequency", NULL);
}

- (NSNumber *) CPUFrequency
{
	return int64ForSysctlName("hw.cpufrequency", NULL);
}

- (NSNumber *) CPUFamily
{
	return int32ForSysctlName("hw.cpufamily", NULL);
}

- (NSString *) CPUFamilyName
{
	NSString *familyName = nil;
	switch([[self CPUFamily] intValue]) {
		case CPUFAMILY_POWERPC_G3:		familyName = NSLocalizedString(@"PowerPC G3", @"");					break;
		case CPUFAMILY_POWERPC_G4:		familyName = NSLocalizedString(@"PowerPC G4", @"");					break;
		case CPUFAMILY_POWERPC_G5:		familyName = NSLocalizedString(@"PowerPC G5", @"");					break;
		case CPUFAMILY_INTEL_6_13:		familyName = NSLocalizedString(@"Intel Core", @"");					break;
		case CPUFAMILY_INTEL_6_14:		familyName = NSLocalizedString(@"Intel Core (Yonah)", @"");			break;
		case CPUFAMILY_INTEL_6_15:		familyName = NSLocalizedString(@"Intel Core 2 (Merom)", @"");		break;
		case CPUFAMILY_INTEL_6_23:		familyName = NSLocalizedString(@"Intel Core 2 (Penryn)", @"");		break;
		case CPUFAMILY_INTEL_6_26:		familyName = NSLocalizedString(@"Intel Xeon (Nehalem)", @"");		break;
		case CPUFAMILY_ARM_9:			familyName = NSLocalizedString(@"ARM 9", @"");						break;
		case CPUFAMILY_ARM_11:			familyName = NSLocalizedString(@"ARM 11", @"");						break;

		default:						familyName = nil;													break;
	}

	return [[familyName retain] autorelease];
}

- (NSString *) systemVersion
{
	NSDictionary *systemVersionDictionary = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
	return [systemVersionDictionary objectForKey:@"ProductVersion"];
}

- (NSString *) systemBuildVersion
{
	NSDictionary *systemVersionDictionary = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
	return [systemVersionDictionary objectForKey:@"ProductBuildVersion"];
}

@end
