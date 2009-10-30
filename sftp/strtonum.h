#ifndef _strtonum_h_
#define _strtonum_h_

long long
strtonum(const char *numstr, long long minval, long long maxval,
    const char **errstrp);

#endif

