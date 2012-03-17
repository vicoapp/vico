/*
 *  Copyright (C) 2009 Stephen F. Booth <me@sbooth.org>
 *  All Rights Reserved
 */

#import <Cocoa/Cocoa.h>

// ========================================
// Utility class for accessing useful system information
// ========================================
@interface SFBSystemInformation : NSObject
{
}

// Hardware information
- (NSString *) machine;
- (NSString *) model;
- (NSNumber *) numberOfCPUs;
- (NSNumber *) physicalMemory;
- (NSNumber *) busFrequency;
- (NSNumber *) CPUFrequency;
- (NSNumber *) CPUFamily;

// User-friendly versions
- (NSString *) modelName;
- (NSString *) CPUFamilyName;

// Mac OS version information
- (NSString *) systemVersion;
- (NSString *) systemBuildVersion;

@end
