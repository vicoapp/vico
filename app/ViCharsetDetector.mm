/*
 * Copyright (c) 2008-2012 Martin Hedenfalk <martin@vicoapp.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

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
	encoding = aCharset;
}

@implementation ViCharsetDetector

+ (ViCharsetDetector *)defaultDetector
{
	static ViCharsetDetector *__defaultDetector = nil;
	if (__defaultDetector == nil)
		__defaultDetector = [[ViCharsetDetector alloc] init];
	return __defaultDetector;
}

- (NSStringEncoding)encodingForData:(NSData *)data
{
	NSStringEncoding encoding = 0;

	/* Check for BOMs. */
	const uint8_t *bytes = (const uint8_t *)[data bytes];
	if ([data length] >= 2) {
		if (bytes[0] == 0xFF && bytes[1] == 0xFE)
			return NSUTF16LittleEndianStringEncoding;
		if (bytes[0] == 0xFE && bytes[1] == 0xFF)
			return NSUTF16BigEndianStringEncoding;
	}
	if ([data length] >= 3) {
		if (bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF)
			return NSUTF8StringEncoding;
	}

	ViDataDetector *detector = new ViDataDetector(NS_FILTER_ALL);
	const char *charset = detector->detectBytes((const char *)[data bytes], (unsigned int)[data length]);
	delete detector;

	if (charset) {
		NSString *cset = [NSString stringWithCString:charset encoding:NSASCIIStringEncoding];
		CFStringEncoding enc = CFStringConvertIANACharSetNameToEncoding((CFStringRef)cset);
		encoding = CFStringConvertEncodingToNSStringEncoding(enc);
		if (encoding == kCFStringEncodingInvalidId)
			encoding = 0;
	}

	return encoding;
}

@end

