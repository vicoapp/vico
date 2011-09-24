#import "ViPreferencePaneAdvanced.h"
#include "logging.h"

@implementation environmentVariableTransformer
+ (Class)transformedValueClass { return [NSDictionary class]; }
+ (BOOL)allowsReverseTransformation { return YES; }
- (id)init { return [super init]; }
- (id)transformedValue:(id)value
{
	if ([value isKindOfClass:[NSDictionary class]]) {
		/* Create an array of dictionaries with keys "name" and "value". */
		NSMutableArray *a = [NSMutableArray array];
		NSDictionary *dict = value;
		NSArray *keys = [[dict allKeys] sortedArrayUsingComparator:^(id a, id b) {
			return [(NSString *)a compare:b];
		}];
		for (NSString *key in keys) {
			[a addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
				[[key mutableCopy] autorelease], @"name",
				[[[dict objectForKey:key] mutableCopy] autorelease], @"value",
				nil]];
		}
		return a;
	} else if ([value isKindOfClass:[NSArray class]]) {
		NSArray *a = [(NSArray *)value sortedArrayUsingComparator:^(id a, id b) {
			return [[(NSDictionary *)a objectForKey:@"name"] compare:[(NSDictionary *)b objectForKey:@"name"]];
		}];
		NSMutableDictionary *dict = [NSMutableDictionary dictionary];
		for (NSDictionary *pair in a) {
			NSMutableString *key = [[[pair objectForKey:@"name"] mutableCopy] autorelease];
			NSMutableString *value = [[[pair objectForKey:@"value"] mutableCopy] autorelease];
			[dict setObject:value forKey:key];
		}
		return dict;
	}

	return nil;
}
@end

@implementation ViPreferencePaneAdvanced

- (id)init
{
	self = [super initWithNibName:@"AdvancedPrefs"
				 name:@"Advanced"
				 icon:[NSImage imageNamed:NSImageNameAdvanced]];
	if (self != nil) {
		[NSValueTransformer setValueTransformer:[[[environmentVariableTransformer alloc] init] autorelease]
						forName:@"environmentVariableTransformer"];
	}

	return self;
}

- (IBAction)addVariable:(id)sender
{
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
		[[@"name" mutableCopy] autorelease], @"name",
		[[@"value" mutableCopy] autorelease], @"value",
		nil];

	[arrayController addObject:dict];
	[arrayController setSelectedObjects:[NSArray arrayWithObject:dict]];
	[tableView editColumn:0 row:[arrayController selectionIndex] withEvent:nil select:YES];
}

@end
