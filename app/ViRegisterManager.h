@interface ViRegisterManager : NSObject
{
	NSMutableDictionary	*registers;
}

+ (id)sharedManager;

- (NSString *)contentOfRegister:(unichar)regName;
- (void)setContent:(NSString *)content ofRegister:(unichar)regName;
- (NSString *)nameOfRegister:(unichar)regName;

@end
