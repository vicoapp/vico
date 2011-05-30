#define ViErrorDomain @"se.bzero.ErrorDomain"

enum {
	ViErrorMapInternal,
	ViErrorMapNotFound,
	ViErrorMapAmbiguous,
	ViErrorParserNoDot,
	ViErrorParserInvalidArgument,
	ViErrorParserInvalidRegister,
	ViErrorParserMultipleRegisters,
	ViErrorParserRegisterOrder,
	ViErrorParserNoOperatorMap,
	ViErrorParserInvalidMotion,
	ViErrorParserInternal
};

@interface NSError (additions)
- (BOOL)isFileNotFoundError;
- (BOOL)isOperationCancelledError;
@end

@interface ViError : NSObject
{
}

+ (NSError *)errorWithObject:(id)obj;
+ (NSError *)errorWithObject:(id)obj code:(NSInteger)code;
+ (NSError *)errorWithFormat:(NSString *)fmt, ...;
+ (NSError *)errorWithCode:(NSInteger)code format:(NSString *)fmt, ...;
+ (NSError *)operationCancelled;

@end

