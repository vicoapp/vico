#include <stdlib.h>

#import "NSString-scopeSelector.h"
#import "NSArray-patterns.h"
#include "logging.h"
#include "scope_selector_parser.h"

#define MAXSEL	 64

inline struct scope_expr *
mk_expr(struct scope_state *state, struct scope_list *sl)
{
	struct scope_expr *expr = &state->exprs[state->nexprs++];
	expr->scope_list = sl;
	expr->op = SCOPE;
	return expr;
}

inline struct scope_expr *
mk_expr_op(struct scope_state *state, int op, struct scope_expr *arg1, struct scope_expr *arg2)
{
	struct scope_expr *expr = &state->exprs[state->nexprs++];
	expr->op = op;
	expr->arg1 = arg1;
	expr->arg2 = arg2;
	return expr;
}

/* returns 10^x */
static u_int64_t
tenpow(NSUInteger x)
{
	u_int64_t r = 1ULL;
	while (x--)
		r *= 10ULL;
	return r;
}

@implementation NSString (scopeSelector)

- (u_int64_t)matchScopeSelector:(struct scope_list *)selectors
                     withScopes:(NSArray *)ref_scopes
{
	NSUInteger	 depth, depth_offset, nscopes = 0;
	NSInteger	 i, k, n;
	u_int64_t	 rank = 0ULL;
	NSString	*ref;

	nscopes = [ref_scopes count];
	if (nscopes == 0)
		return 0ULL;
	depth_offset = nscopes;

	NSInteger ref_begin_idx = nscopes - 1;

	struct scope *sel;
	TAILQ_FOREACH_REVERSE(sel, selectors, scope_list, next) {
		/* Match each selector against all remaining, unmatched scopes. */

		BOOL match = NO;
		NSInteger ref_idx = ref_begin_idx;
		for (depth = depth_offset; ref_idx >= 0; ref_idx--, depth--) {
			ref = [ref_scopes objectAtIndex:ref_idx];

			/* Match selector #i against scope #j. */

#ifndef NO_DEBUG
			NSString *selscope = [NSString stringWithCharacters:sel->buf length:sel->length];
			NSString *refscope = ref;
			DEBUG(@"matching selector [%@] against scope [%@]", selscope, refscope);
#endif

			NSUInteger reflength = [ref length];
			match = YES;
			for (i = k = 0; k < reflength && i < sel->length; i++, k++) {
				if ([ref characterAtIndex:k] != sel->buf[i]) {
					match = NO;
					break;
				}
			}

			if (match && k + 1 < reflength) {
				/* Don't count partial scope matches. */
				/* "source.css" shouldn't match "source.c" */
				if ([ref characterAtIndex:k] != '.') {
					DEBUG(@"partial match of [%@] at index k = %lu", refscope, k);
					match = NO;
				}
			}

			if (match && k + 1 < sel->length) {
				/* Don't count partial scope matches. */
				/* "source.c" shouldn't match "source.css" */
				if (sel->buf[k] != '.') {
					DEBUG(@"partial match of [%@] at index k = %lu", selscope, k);
					match = NO;
				}
			}

			if (match) {

				if (sel->last && ref_idx != nscopes - 1) {
					DEBUG(@"scope selector [%@] not last", selscope);
					return 0ULL;
				}

				/* A match is given 10^18 points for each depth down the scope stack. */
				if (TAILQ_NEXT(sel, next) == NULL)
					rank += depth * DEPTH_RANK;

				// "Another 10^<depth> points is given for each additional part of the scope that is matched"
				n = 0; /* Count number of dots in the selector (that actually matched the scope). */
				for (i = 0; i < sel->length; i++)
					if (sel->buf[i] =='.')
						n++;
				if (n > 0)
					rank += n * tenpow(depth);

				DEBUG(@"selector [%@] matched at depth %lu, with %lu parts", selscope, depth, n+1);

				/* "1 extra point is given for each extra descendant scope" */
				rank += 1;

				/* If we matched scope #j, next selector should start matching against scope #j-1. */
				ref_begin_idx = ref_idx - 1;
				depth_offset = depth - 1;

				/* Continue with the next selector. */
				break;
			} else {
				struct scope *child = TAILQ_NEXT(sel, next);
				if (child && child->child) {
#ifndef NO_DEBUG
					NSString *childscope = [NSString stringWithCharacters:child->buf length:child->length];
					DEBUG(@"selector [%@] not a direct parent of child [%@]", selscope, childscope);
#endif
					return 0ULL;
				}
			}
		}

		/* If the selector didn't match any scope, we fail. */
		if (!match)
			return 0ULL;
	}

	return rank;
}

- (u_int64_t)evalScopeSelector:(struct scope_expr *)expr
                 againstScopes:(NSArray *)ref_scopes
{
	u_int64_t l, r;

	DEBUG(@"matching against expr %p", expr);

	switch (expr->op) {
	case SCOPE:
		return [self matchScopeSelector:expr->scope_list withScopes:ref_scopes];
	case MINUS:
		l = [self evalScopeSelector:expr->arg1 againstScopes:ref_scopes];
		if (l == 0ULL ||
		    [self evalScopeSelector:expr->arg2 againstScopes:ref_scopes] > 0ULL)
			return 0ULL;
		return l;
	case COMMA:
	case OR:
		l = [self evalScopeSelector:expr->arg1 againstScopes:ref_scopes];
		if (l > 0ULL)
			return l;
		return [self evalScopeSelector:expr->arg2 againstScopes:ref_scopes];
	case AND:
		l = [self evalScopeSelector:expr->arg1 againstScopes:ref_scopes];
		if (l == 0ULL)
			return 0ULL;
		r = [self evalScopeSelector:expr->arg2 againstScopes:ref_scopes];
		if (l > r)
			return l;
		return r;
	default:
		INFO(@"%s", "internal error");
		return 0ULL;
	}
}

#ifndef NO_DEBUG
- (NSString *)printScopeList:(struct scope_list *)scope_list
{
	NSMutableString *s;
	struct scope *scope;

	s = [NSMutableString string];
	TAILQ_FOREACH(scope, scope_list, next) {
		if (scope->child)
			[s appendString:@"> "];
		NSString *tmp = [NSString stringWithCharacters:scope->buf length:scope->length];
		[s appendString:tmp];
		if (scope->last) {
			[s appendString:@" $"];
			if (TAILQ_NEXT(scope, next))
				[s appendString:@" (INTERNAL ERROR)$"];
		}

		if (TAILQ_NEXT(scope, next))
			[s appendString:@" "];
	}

	return s;
}

- (NSString *)printScopeExpression:(struct scope_expr *)expr
{
	NSMutableString *s;

	s = [NSMutableString string];
	[s appendString:@"("];

	switch (expr->op) {
	case SCOPE:
		[s appendString:[self printScopeList:expr->scope_list]];
		break;
	case MINUS:
		[s appendString:[self printScopeExpression:expr->arg1]];
		[s appendString:@" - "];
		[s appendString:[self printScopeExpression:expr->arg2]];
		break;
	case COMMA:
		[s appendString:[self printScopeExpression:expr->arg1]];
		[s appendString:@", "];
		[s appendString:[self printScopeExpression:expr->arg2]];
		break;
	case OR:
		[s appendString:[self printScopeExpression:expr->arg1]];
		[s appendString:@" | "];
		[s appendString:[self printScopeExpression:expr->arg2]];
		break;
	case AND:
		[s appendString:[self printScopeExpression:expr->arg1]];
		[s appendString:@" & "];
		[s appendString:[self printScopeExpression:expr->arg2]];
		break;
	default:
		INFO(@"%s", "internal error");
		return nil;
	}

	[s appendString:@")"];

	return s;
}
#endif

- (u_int64_t)matchesScopeList:(NSArray *)ref_scopes
{
	unichar *buf;
	u_int64_t rank = 0ULL;
	NSUInteger i, j, len;
	struct scope_state state;

	len = [self length];
	if (len == 0)
		return 1ULL;

	buf = malloc(sizeof(unichar) * len);
	if (buf == NULL)
		return 0ULL;
	[self getCharacters:buf range:NSMakeRange(0, len)];

	void *parser = scopeSelectorParseAlloc(malloc);
	if (parser == NULL) {
		free(buf);
		return 0ULL;
	}

	state.top_level_expr = NULL;
	state.nscopes = 0;
	state.nlists = 0;
	state.nexprs = 0;

	for (i = 0; i < len;) {
		struct scope *scope;
		unichar ch = buf[i];
		switch (ch) {
		case ' ':
		case '\n':
			i++;
			break;
		case ',':
			scopeSelectorParse(parser, COMMA, NULL, &state);
			i++;
			break;
		case '-':
			scopeSelectorParse(parser, MINUS, NULL, &state);
			i++;
			break;
		case '(':
			scopeSelectorParse(parser, LPAREN, NULL, &state);
			i++;
			break;
		case ')':
			scopeSelectorParse(parser, RPAREN, NULL, &state);
			i++;
			break;
		case '&':
			scopeSelectorParse(parser, AND, NULL, &state);
			i++;
			break;
		case '|':
			scopeSelectorParse(parser, OR, NULL, &state);
			i++;
			break;
		case '>':
			scopeSelectorParse(parser, GT, NULL, &state);
			i++;
			break;
		case '$':
			scopeSelectorParse(parser, DOLLAR, NULL, &state);
			i++;
			break;
		default:
			scope = &state.scopes[state.nscopes++];
			for (j = i + 1; j < len; j++) {
				ch = buf[j];
				if (ch == ' ' || ch == ',' || ch == '(' || ch == ')' || ch == '&' || ch == '|' || ch == '>' || ch == '\n' || ch == '$')
					break;
			}
			scope->buf = buf + i;
			scope->length = (unsigned int)(j - i);
			scope->child = 0;
			scope->last = 0;
			scopeSelectorParse(parser, SCOPE, scope, &state);
			i = j;
			break;
		}
	}

	scopeSelectorParse(parser, 0, NULL, &state);

	DEBUG(@"got top-level expression %p", state.top_level_expr);
	if (state.top_level_expr) {
		DEBUG(@"expression:\n%@", [self printScopeExpression:state.top_level_expr]);
		rank = [self evalScopeSelector:state.top_level_expr againstScopes:ref_scopes];
	}

	scopeSelectorParseFree(parser, free);
	free(buf);

	return rank;
}

- (u_int64_t)matchesScopes:(NSArray *)scopes
{
#if 0
	/* Convert the NSArray to a TAILQ. */
	struct scope ref_scope_array[64];	/* XXX: crash if more than this many scopes! */
	struct scope_list ref_scopes;
	TAILQ_INIT(&ref_scopes);
	int nrefs = 0;
	for (NSString *tmp in scopes) {
		if (nrefs >= 64)
			break;
		struct scope *ref = &ref_scope_array[nrefs++];
		ref->length = (unsigned int)[tmp length];
		ref->buf = malloc(sizeof(unichar) * ref->length);
		[tmp getCharacters:ref->buf range:NSMakeRange(0, ref->length)];
		TAILQ_INSERT_TAIL(&ref_scopes, ref, next);
	}
#endif

	u_int64_t rank = [self matchesScopeList:scopes];

#if 0
	int i;
	for (i = 0; i < nrefs; i++)
		free(ref_scope_array[i].buf);
#endif

	return rank;
}

- (u_int64_t)match:(ViScope *)scope
{
	if ([self length] == 0)
		return 1ULL;
	return [scope match:self];
}

@end
