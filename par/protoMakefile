# *********************
# * protoMakefile     *
# * for Par 1.52      *
# * Copyright 2001 by *
# * Adam M. Costello  *
# *********************


#####
##### Instructions
#####

# If you have no make command (or equivalent), you can easily tell by
# looking at this file what make would do.  It would compile each .c
# file into a .o file, then link all the .o files into the executable
# par.  You can do this manually.  Then you should go look for a version
# of make for your system, since it will come in handy in the future.

# If you do have make, you can either copy this file to Makefile, edit
# the definitions of CC, LINK1, LINK2, RM, JUNK, O, and E, and then run
# make; or, better yet, create a short script which looks something
# like:
#
# #!/bin/sh
# make -f protoMakefile CC="cc -c" LINK1="cc" LINK2="-o" RM="rm" JUNK="" $*
#
# (Alter this to use commands and values appropriate for your compiler
# and shell).  The advantage of the second method is that the script
# will probably work on the next release of Par.

#####
##### Configuration
#####

# Define CC so that the command
#
# $(CC) foo.c
#
# compiles the ANSI C source file "foo.c" into the object file "foo.o".
# You may assume that foo.c uses no floating point math.
#
# If your operating system or your compiler's exit() function
# automatically frees all memory allocated by malloc() when a process
# terminates, then you can choose to trade away space efficiency for
# time efficiency by defining DONTFREE.
#
# Example (for Solaris 2.x with SPARCompiler C):
# CC = cc -c -O -s -Xc -DDONTFREE

CC = cc -c

# Define LINK1 and LINK2 so that the command
#
# $(LINK1) foo1.o foo2.o foo3.o $(LINK2) foo
#
# links the object files "foo1.o", "foo2.o", "foo3.o" into the
# executable file "foo".  You may assume that none of the .o files use
# floating point math.
#
# Example (for Solaris 2.x with SPARCompiler C):
# LINK1 = cc -s
# LINK2 = -o

LINK1 = cc
LINK2 = -o

# Define RM so that the command
#
# $(RM) foo1 foo2 foo3
#
# removes the files "foo1", "foo2", and "foo3", and preferably doesn't
# complain if they don't exist.

RM = rm -f

# Define JUNK to be a list of additional files, other than par and
# $(OBJS), that you want to be removed by "make clean".

JUNK =

# Define O to be the usual suffix for object files.

O = .o

# Define E to be the usual suffix for executable files.

E =

#####
##### Guts (you shouldn't need to touch this part)
#####

OBJS = buffer$O charset$O errmsg$O par$O reformat$O

.c$O:
	$(CC) $<

par$E: $(OBJS)
	$(LINK1) $(OBJS) $(LINK2) par$E

buffer$O: buffer.c buffer.h errmsg.h

charset$O: charset.c charset.h errmsg.h buffer.h

errmsg$O: errmsg.c errmsg.h

par$O: par.c charset.h errmsg.h buffer.h reformat.h

reformat$O: reformat.c reformat.h errmsg.h buffer.h

clean:
	$(RM) par $(OBJS) $(JUNK)
