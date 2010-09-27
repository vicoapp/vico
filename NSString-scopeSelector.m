#import "NSString-scopeSelector.h"
#import "NSArray-patterns.h"
#import "logging.h"

/* returns 10^x */
static u_int64_t
tenpow(unsigned x)
{
	u_int64_t r = 1ULL;
	while (x--)
		r *= 10ULL;
	return r;
}

@implementation NSString (scopeSelector)

- (u_int64_t)matchesScopes:(NSArray *)scopes
{
	unichar		 buf[1024+1], *p, *end;
	unichar		*descendants[128];
	unsigned int	 ndots[128], n;
	NSUInteger	 length;
	NSUInteger	 nscopes, nselectors = 0;
	NSUInteger	 i, j, k;
	u_int64_t	 rank = 0ULL;

	length = [self length];
	if (length == 0)
		return 1ULL;
	if (length > 1024)
		return 0ULL;

	[self getCharacters:buf range:NSMakeRange(0, length)];
	end = buf + length;

	/* Split the selector into descendants, and count them. */
	for (p = buf; p < end;) {
		/* Skip whitespace. */
		while (p < end && *p == ' ') {
			*p = 0;
			p++;
		}
		if (p == end)
			break;
		descendants[nselectors] = p;
		/* Skip to next whitespace and count dots. */
		n = 0;
		while (p < end && *p != ' ') {
			if (*p == '.')
				n++;
			p++;
		}
		ndots[nselectors++] = n;
		if (nselectors >= 128)
			return 0ULL;
	}
	*p = 0;

	if (nselectors == 0)
		return 0;

	nscopes = [scopes count];

	// find the depth of the match of the first descendant
	/* Loop through all scopes we're matching against. */
	for (i = 0; i < nscopes; i++) {
		// if we haven't matched by now, fail
		if (nselectors + i > nscopes)
			return 0;

		/* Loop through all descendants in the scope selector. */
		for (j = 0; j < nselectors; j++)
		{
			NSString *scope = [scopes objectAtIndex:i+j];
			unichar *selector = descendants[j];
			// DEBUG(@"comparing selector [%@] with scope [%@]", selector, scope);
			NSUInteger sl = [scope length];
			for (p = selector, k = 0; k < sl && *p != 0; p++, k++) {
				if ([scope characterAtIndex:k] != *p)
					break;
			}

			if (*p == 0) {
				// "Another 10^<depth> points is given for each additional part of the scope that is matched"
				n = ndots[j];
				if (n > 0)
					rank += n * tenpow(i+1+j);

				/* Did the whole selector match? */
				if (j + 1 == nselectors) {
					/* The total depth rank is: */
					rank += (i + 1 + j) * DEPTH_RANK;

					/* "1 extra point is given for each extra descendant scope" */
					rank += j;
					return rank;
				}
			} else {
				/* This scope selector doesn't match here, start over. */
				rank = 0ULL;
				break;
			}
		}
	}

	return rank;
}

@end
