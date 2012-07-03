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
	int last;  /* 1 if this scope must be the last in the list of scopes */
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

