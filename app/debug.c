#include <sys/types.h>
#include <sys/queue.h>
#include <sys/socket.h>
#include <sys/time.h>

#include <errno.h>
#include <netdb.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <syslog.h>
#include <time.h>
#include <unistd.h>

#include "ber.h"
#include "vis.h"

int	 debug;
int	 verbose;

void	 hexdump(void *data, size_t len, const char *fmt, ...);
void	 ldap_debug_elements(struct ber_element *root, int context,
	    const char *fmt, ...);

void
hexdump(void *data, size_t len, const char *fmt, ...)
{
	uint8_t *p = data;
	va_list ap;

	va_start(ap, fmt);
	vfprintf(stderr, fmt, ap);
	fprintf(stderr, "\n");
	va_end(ap);

	while (len--) {
		size_t ofs = p - (uint8_t *)data;
		if (ofs % 16 == 0)
			fprintf(stderr, "%s%04lx:", ofs == 0 ? "" : "\n", ofs);
		else if (ofs % 8 == 0)
			fprintf(stderr, " ");
		fprintf(stderr, " %02x", *p++);
	}
	fprintf(stderr, "\n");
}

/*
 * Display a list of ber elements.
 *
 */
void
ldap_debug_elements(struct ber_element *root, int context, const char *fmt, ...)
{
	va_list		 ap;
	static int	 indent = 0;
	long long	 v;
	int		 d;
	char		*buf, *visbuf;
	size_t		 len;
	unsigned long	 constructed;
	struct ber_oid	 o;

	if (fmt != NULL) {
		va_start(ap, fmt);
		fprintf(stderr, fmt, ap);
		fprintf(stderr, "\n");
		va_end(ap);
	}

	/* calculate lengths */
	ber_calc_len(root);

	switch (root->be_encoding) {
	case BER_TYPE_SEQUENCE:
	case BER_TYPE_SET:
		constructed = root->be_encoding;
		break;
	default:
		constructed = 0;
		break;
	}

	fprintf(stderr, "%*slen %lu ", indent, "", root->be_len);
	switch (root->be_class) {
	case BER_CLASS_UNIVERSAL:
		fprintf(stderr, "class: universal(%u) type: ", root->be_class);
		switch (root->be_type) {
		case BER_TYPE_EOC:
			fprintf(stderr, "end-of-content");
			break;
		case BER_TYPE_BOOLEAN:
			fprintf(stderr, "boolean");
			break;
		case BER_TYPE_INTEGER:
			fprintf(stderr, "integer");
			break;
		case BER_TYPE_BITSTRING:
			fprintf(stderr, "bit-string");
			break;
		case BER_TYPE_OCTETSTRING:
			fprintf(stderr, "octet-string");
			break;
		case BER_TYPE_NUMERICSTRING:
			fprintf(stderr, "numeric-string");
			break;
		case BER_TYPE_PRINTABLESTRING:
			fprintf(stderr, "printable-string");
			break;
		case BER_TYPE_IA5STRING:
			fprintf(stderr, "IA5-string");
			break;
		case BER_TYPE_UTF8STRING:
			fprintf(stderr, "utf8-string");
			break;
		case BER_TYPE_NULL:
			fprintf(stderr, "null");
			break;
		case BER_TYPE_OBJECT:
			fprintf(stderr, "object");
			break;
		case BER_TYPE_ENUMERATED:
			fprintf(stderr, "enumerated");
			break;
		case BER_TYPE_SEQUENCE:
			fprintf(stderr, "sequence");
			break;
		case BER_TYPE_SET:
			fprintf(stderr, "set");
			break;
		}
		break;
	case BER_CLASS_APPLICATION:
		fprintf(stderr, "class: application(%u) ", root->be_class);
		break;
	case BER_CLASS_PRIVATE:
		fprintf(stderr, "class: private(%u) type: ", root->be_class);
		fprintf(stderr, "encoding (%lu) type: ", root->be_encoding);
		break;
	case BER_CLASS_CONTEXT:
		fprintf(stderr, "class: context(%u) ", root->be_class);
		break;
	default:
		fprintf(stderr, "class: <INVALID>(%u) type: ", root->be_class);
		break;
	}
	fprintf(stderr, "(%lu) encoding %lu ",
	    root->be_type, root->be_encoding);

	if (constructed)
		root->be_encoding = constructed;

	switch (root->be_encoding) {
	case BER_TYPE_BOOLEAN:
		if (ber_get_boolean(root, &d) == -1) {
			fprintf(stderr, "<INVALID>\n");
			break;
		}
		fprintf(stderr, "%s(%d)\n", d ? "true" : "false", d);
		break;
	case BER_TYPE_INTEGER:
		if (ber_get_integer(root, &v) == -1) {
			fprintf(stderr, "<INVALID>\n");
			break;
		}
		fprintf(stderr, "value %lld\n", v);
		break;
	case BER_TYPE_ENUMERATED:
		if (ber_get_enumerated(root, &v) == -1) {
			fprintf(stderr, "<INVALID>\n");
			break;
		}
		fprintf(stderr, "value %lld\n", v);
		break;
	case BER_TYPE_BITSTRING:
		if (ber_get_bitstring(root, (void *)&buf, &len) == -1) {
			fprintf(stderr, "<INVALID>\n");
			break;
		}
		hexdump(buf, len, "hexdump: ");
		break;
	case BER_TYPE_OBJECT:
		if (ber_get_oid(root, &o) == -1) {
			fprintf(stderr, "<INVALID>\n");
			break;
		}
		for (d = 0; o.bo_id[d] != 0; d++)
			fprintf(stderr, "%d%s", o.bo_id[d], o.bo_id[d+1] ? "." : "");
		fprintf(stderr, "\n");
		break;
	case BER_TYPE_OCTETSTRING:
		if (ber_get_nstring(root, (void *)&buf, &len) == -1) {
			fprintf(stderr, "<INVALID>\n");
			break;
		}
		if ((visbuf = malloc(len * 4 + 1)) != NULL) {
			strvisx(visbuf, buf, len, 0);
			fprintf(stderr, "string \"%s\"\n",  visbuf);
			free(visbuf);
		}
		break;
	case BER_TYPE_NUMERICSTRING:
	case BER_TYPE_PRINTABLESTRING:
	case BER_TYPE_IA5STRING:
	case BER_TYPE_UTCTIME:
		fprintf(stderr, "%s\n", (char *)root->be_val);
		break;
	case BER_TYPE_NULL:	/* no payload */
	case BER_TYPE_EOC:
	case BER_TYPE_SEQUENCE:
	case BER_TYPE_SET:
	default:
		fprintf(stderr, "\n");
		break;
	}

	if (constructed && root->be_sub) {
		indent += 2;
		ldap_debug_elements(root->be_sub, context, NULL);
		indent -= 2;
	}
	if (root->be_next)
		ldap_debug_elements(root->be_next, context, NULL);
}

