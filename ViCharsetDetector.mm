#import <CoreFoundation/CoreFoundation.h>

#import "ViCharsetDetector.h"
#import "logging.h"
#import "nscore.h"
#import "nsUniversalDetector.h"

class ViDataDetector : public nsUniversalDetector
{
public:
	ViDataDetector(PRUint32 aLanguageFilter);
	virtual ~ViDataDetector();
	const char *detectBytes(const char *bytes, unsigned int length);
	const char *encoding;
protected:
	virtual void Report(const char *aCharset);
};

ViDataDetector::ViDataDetector(PRUint32 aLanguageFilter)
    : nsUniversalDetector(aLanguageFilter), encoding(NULL)
{
}

const char *
ViDataDetector::detectBytes(const char *bytes, unsigned int length)
{
	encoding = NULL;
	this->Reset();
	nsresult ret = this->HandleData(bytes, length);
	if (NS_FAILED(ret)) {
		INFO(@"HandleData returned %u", ret);
		return NULL;
	}

	if (mDetectedCharset)
		return mDetectedCharset;

	this->DataEnd();
	if (mDetectedCharset)
		return mDetectedCharset;

	return encoding;
}

ViDataDetector::~ViDataDetector()
{
}

void
ViDataDetector::Report(const char *aCharset)
{
	INFO(@"reported encoding %s", aCharset);
	encoding = aCharset;
}

@implementation ViCharsetDetector

- (id)init
{
	self = [super init];
	return self;
}

+ (ViCharsetDetector *)defaultDetector
{
	static ViCharsetDetector *defaultDetector = nil;
	if (defaultDetector == nil)
		defaultDetector = [[ViCharsetDetector alloc] init];
	return defaultDetector;
}

- (NSStringEncoding)encodingForData:(NSData *)data
{
	NSStringEncoding encoding = 0;

	INFO(@"detecting encoding in %lu bytes of data", (unsigned long)[data length]);

	ViDataDetector *detector = new ViDataDetector(NS_FILTER_ALL);
	const char *charset = detector->detectBytes((const char *)[data bytes], [data length]);
	INFO(@"Detected charset %s", charset);
	delete detector;

	if (charset) {
		NSString *cset = [NSString stringWithCString:charset encoding:NSASCIIStringEncoding];
		CFStringEncoding enc = CFStringConvertIANACharSetNameToEncoding((CFStringRef)cset);
		INFO(@"charset %s = CFString encoding %x ~> 0x%x", charset, (long)enc,
		    CFStringConvertEncodingToNSStringEncoding(enc));
	
		encoding = CFStringConvertEncodingToNSStringEncoding(enc);
		if (encoding == kCFStringEncodingInvalidId)
			encoding = 0;
	}

	return encoding;
}

@end

