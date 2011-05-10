#ifndef _scope_selector_parser_h
#define _scope_selector_parser_h

#include <sys/types.h>

#include "sys_queue.h"
#include "scope_selector.h"

struct scope
{
	TAILQ_ENTRY(scope) next;
	u_int16_t *buf;
	unsigned int length;
	int child; /* 1 if this scope must be an immediate child of the previous scope in the list. */
};

TAILQ_HEAD(scope_list, scope);

struct scope_expr
{
	struct scope_list *scope_list;
	struct scope_expr *arg1, *arg2;
	int op;
};

struct scope_state
{
	struct scope		 scopes[64];
	struct scope_list	 lists[64];
	struct scope_expr	 exprs[32];
	struct scope_expr	*top_level_expr;
	int			 nscopes;
	int			 nlists;
	int			 nexprs;
};

struct scope_expr	*mk_expr(struct scope_state *state, struct scope_list *sl);
struct scope_expr	*mk_expr_op(struct scope_state *state, int op, struct scope_expr *arg1,
			    struct scope_expr *arg2);

void	*scopeSelectorParseAlloc(void *(*alloc_func)(size_t));
void	 scopeSelectorParseTrace(FILE *fp, char *prompt);
void	 scopeSelectorParse(void *parser, int symbol, struct scope *token, struct scope_state *state);
void	 scopeSelectorParseFree(void *parser, void (*free_fun)(void *));

#endif

