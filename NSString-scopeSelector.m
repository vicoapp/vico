#import "NSString-scopeSelector.h"
#import "NSArray-patterns.h"
#import "logging.h"

#define MAXSEL	 64

/* returns 10^x */
static u_int64_t
tenpow(unsigned x)
{
	u_int64_t r = 1ULL;
	while (x--)
		r *= 10ULL;
	return r;
}

static u_int64_t
match_scopes(unichar *buf, NSUInteger length, NSArray *scopes)
{
	unichar		*p, *end;
	unichar		*descendants[MAXSEL];
	unsigned int	 ndots[MAXSEL], n;
	NSUInteger	 nscopes, nselectors = 0, scope_offset;
	NSInteger	 i, j, k;
	u_int64_t	 rank = 0ULL;

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
		if (nselectors >= MAXSEL)
			return 0ULL;
	}
	*p = 0;

	if (nselectors == 0)
		return 0ULL;

	nscopes = [scopes count];

	if (nselectors > nscopes)
		return 0ULL;

	scope_offset = nscopes - 1;

	for (i = nselectors - 1; i >= 0; i--) {
		/* Match each selector against all remaining, unmatched scopes. */

		BOOL match = NO;
		for (j = scope_offset; j >= 0; j--) {

			/* Match selector #i against scope #j. */

			NSString *scope = [scopes objectAtIndex:j];
			unichar *selector = descendants[i];
			NSUInteger sl = [scope length];

#ifndef NO_DEBUG
			int x;
			for (x = 0; selector[x] != 0; x++) ;
			NSString *sel = [NSString stringWithCharacters:selector length:x];
			DEBUG(@"matching selector [%@] against scope [%@]", sel, scope);
#endif

			match = YES;
			for (p = selector, k = 0; k < sl && *p != 0; p++, k++) {
				if ([scope characterAtIndex:k] != *p) {
					match = NO;
					break;
				}
			}

			if (match && k + 1 < sl) {
				/* Don't count partial scope matches. */
				/* "source.css" shouldn't match "source.c" */
				if ([scope characterAtIndex:k] != '.') {
					DEBUG(@"partial match of [%@] at index k = %lu", scope, k);
					match = NO;
				}
			}

			if (match) {
				DEBUG(@"selector [%@] matched at depth %lu, with %lu parts", sel, j+1, ndots[i]+1);
				/* A match is given 10^18 points for each depth down the scope stack. */
				if (i == nselectors - 1)
					rank += (j + 1) * DEPTH_RANK;

				// "Another 10^<depth> points is given for each additional part of the scope that is matched"
				n = ndots[i]; /* Number of dots in the selector (that actually matched the scope). */
				if (n > 0)
					rank += n * tenpow(j + 1);

				/* "1 extra point is given for each extra descendant scope" */
				rank += 1;

				/* If we matched scope #j, next selector should start matching against scope #j-1. */
				scope_offset = j - 1;

				/* Continue with the next selector. */
				break;
			}
		}

		/* If the selector didn't match any scope, we fail. */
		if (!match)
			return 0ULL;
	}

	return rank;
}

static u_int64_t
match_group(unichar *buf, NSUInteger length, NSArray *scopes)
{
	unichar		*e, *begin, *end;
	u_int64_t	 r, incl_rank = 0ULL;

	begin = buf;
	end = begin + length;

	do {
		for (e = begin; e < end; e++)
			if (e + 2 < end && e[0] == ' ' && e[1] == '-')
				break;
		r = match_scopes(begin, e - begin, scopes);
		if (begin == buf) {
			if (r == 0ULL)
				return 0ULL;
			incl_rank = r;
		} else if (r > 0ULL)	/* Positive exclusion. */
			return 0ULL;
		begin = e + 2;

	} while (e < end);

	return incl_rank;
}

@implementation NSString (scopeSelector)

- (u_int64_t)matchesScopes:(NSArray *)scopes
{
	unichar		 buf[1024+1], *begin, *p, *end;
	NSUInteger	 length;
	u_int64_t	 r;

	length = [self length];
	if (length == 0)
		return 1ULL;
	if (length > 1024)
		return 0ULL;

	[self getCharacters:buf range:NSMakeRange(0, length)];
	end = buf + length;

	/* Evaluate each comma-separated group. */
	for (begin = p = buf; p < end; p++) {
		if (*p == ',') {
			*p = '\0';
			if ((r = match_group(begin, p - begin, scopes)) > 0ULL)
				return r;
			begin = p + 1;
		}
	}

	if (begin < p)
		return match_group(begin, p - begin, scopes);
	return 0ULL;
}

@end
