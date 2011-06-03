  *********************
  * par.doc           *
  * for Par 1.52 i18n *
  * Copyright 2001 by *
  * Adam M. Costello  *
  *********************


    Par 1.52 is a package containing:

       + This doc file.
       + A man page based on this doc file.
       + The ANSI C source for the filter "par".


Contents

    Contents
    File List
    Rights and Responsibilities
    Compilation
    Synopsis
    Description
   *Quick Start
    Terminology
    Options
    Environment
    Details
    Diagnostics
    Examples
    Limitations
    Apologies
    Bugs


File List

    The Par 1.52 package is always distributed with at least the
    following files:

        buffer.c
        buffer.h
        charset.c
        charset.h
        errmsg.c
        errmsg.h
        par.1
        par.c
        par.doc
        protoMakefile
        reformat.c
        reformat.h
        releasenotes

    Each file is a text file which identifies itself on the second line,
    and identifies the version of Par to which it belongs on the third
    line, so you can always tell which file is which, even if the files
    have been renamed.

    The file "par.1" is a man page for the filter par (not to be
    confused with the package Par, which contains the source code for
    par).  "par.1" is based on this doc file, and conveys much (not
    all) of the same information, but "par.doc" is the definitive
    documentation for both par and Par.


Rights and Responsibilities

    The files listed in the Files List section above are each Copyright
    2001 by Adam M. Costello (henceforth "I", "me").

    I grant everyone ("you") permission to do whatever you like with
    these files, provided that if you modify them you take reasonable
    steps to avoid confusing or misleading people about who wrote the
    modified files (both you and I) or what version they are.  All
    official versions of Par will have version numbers consisting of
    only digits and periods.

    I encourage you to send me copies of your modifications in case I
    wish to incorporate them into future versions of Par.  See the Bugs
    section for my address.

    Though I have tried to make sure that Par is free of bugs, I make no
    guarantees about its soundness.  Therefore, I am not responsible for
    any damage resulting from the use of these files.


Compilation

    To compile par, you need an ANSI C compiler.  Follow the
    instructions in the comments in protoMakefile.

    If your compiler generates any warnings that you think are
    legitimate, please tell me about them (see the Bugs section).

    Note that all variables in par are either constant or automatic
    (or both), which means that par can be made reentrant (if your
    compiler supports it).  Given the right operating system, it should
    be possible for several par processes to share the same code space
    and the same data space (but not the same stack, of course) in
    memory.


Synopsis
    par [help] [version] [B<op><set>] [P<op><set>] [Q<op><set>]
        [h[<hang>]] [p[<prefix>]] [r[<repeat>]] [s[<suffix>]] [T[<Tab>]]
        [w[<width>]] [b[<body>]] [c[<cap>]] [d[<div>]] [E[<Err>]]
        [e[<expel>]] [f[<fit>]] [g[<guess>]] [i[<invis>]] [j[<just>]]
        [l[<last>]] [q[<quote>]] [R[<Report>]] [t[<touch>]]

    Things enclosed in [square brackets] are optional.  Things enclosed
    in <angle brackets> are parameters.


Description

    par is a filter which copies its input to its output, changing all
    white characters (except newlines) to spaces, and reformatting
    each paragraph.  Paragraphs are separated by protected, blank, and
    bodiless lines (see the Terminology section for definitions), and
    optionally delimited by indentation (see the d option in the Options
    section).

    Each output paragraph is generated from the corresponding input
    paragraph as follows:

     1) An optional prefix and/or suffix is removed from each input
        line.
     2) The remainder is divided into words (separated by spaces).
     3) The words are joined into lines to make an eye-pleasing
        paragraph.
     4) The prefixes and suffixes are reattached.

     If there are suffixes, spaces are inserted before them so that they
     all end in the same column.


Quick Start

    par is necessarily complex.  For those who wish to use it
    immediately and understand it later, assign to the PARINIT
    environment variable the following value:

        rTbgqR B=.,?_A_a Q=_s>|

    The spaces, question mark, greater-than sign, and vertical bar will
    probably have to be escaped or quoted to prevent your shell from
    interpreting them.

    The documentation, though precise, is unfortunately not well-written
    for the end-user.  Your best bet is probably to read quickly the
    Description, Terminology, Options, and Environment sections, then
    read carefully the Examples section, referring back to the Options
    and Terminology sections as needed.

    For the "power user", a full understanding of par will require
    multiple readings of the Terminology, Options, Details, and Examples
    sections.


Terminology

    Miscellaneous terms:

        charset syntax
            A way of representing a set of characters as a string.
            The set includes exactly those characters which appear in
            the string, except that the underscore (_) is an escape
            character.  Whenever it appears, it must begin one of the
            following escape sequences:

                   __ = an underscore
                   _s = a space
                   _b = a backslash (\)
                   _q = a single quote (')
                   _Q = a double quote (")
                   _A = all upper case letters
                   _a = all lower case letters
                   _0 = all decimal digits
                 _xhh = the character represented by the two hexadecimal
                        digits hh (which may be upper or lower case)

            The NUL character must not appear in the string but it may
            be included in the set with the _x00 sequence.

        error
            A condition which causes par to abort.  See the Diagnostics
            section.

        IP  Input paragraph.

        OP  Output paragraph.

        parameter
            A symbol which may take on unsigned integral values.  There
            are several parameters whose values affect the behavior of
            par.  Parameters can be assigned values using command line
            options.


    Types of characters:

        alphanumeric character
            An upper case letter, lower case letter, or decimal digit.

        body character
            A member of the set of characters defined by the PARBODY
            environment variable (see the Environment section) and/or
            the B option (see the Options section).

        protective character
            A member of the set of characters defined by the PARPROTECT
            environment variable and/or the P option.

        quote character
            A member of the set of characters defined by the PARQUOTE
            environment variable and/or the Q option.

        terminal character
            A period, question mark, exclamation point, or colon.

        white character
            A space, formfeed, newline, carriage return, tab, or
            vertical tab.

    Functions:

        comprelen
            Given a non-empty sequence <S> of lines, let <c> be their
            longest common prefix.  If the parameter <body> is 0, place
            a divider just after the leading non-body characters in <c>
            (at the beginning if there are none).  If <body> is 1, place
            the divider just after the last non-space non-body character
            in <c> (at the beginning if there is none), then advance
            the divider over any immediately following spaces.  The
            comprelen of <S> is the number of characters preceeding the
            divider.

        comsuflen
            Given a non-empty sequence <S> of lines, let <p> be the
            comprelen of <S>.  Let <T> be the set of lines which results
            from stripping the first <p> characters from each line in
            <S>.  Let <c> be the longest common suffix of the lines
            in <T>.  If <body> is 0, place a divider just before the
            trailing non-body characters in <c> (at the end if there are
            none), then advance the divider over all but the last of any
            immediately following spaces.  If <body> is 1, place the
            divider just before the first non-space non-body character,
            then back up the divider over one immediately preceeding
            space if there is one.  The comsuflen of <S> is the number
            of characters following the divider.

        fallback prelen (suflen)
            The fallback prelen (suflen) of an IP is: the comprelen
            (comsuflen) of the IP, if the IP contains at least two
            lines; otherwise, the comprelen (comsuflen) of the block
            containing the IP, if the block contains at least two
            lines; otherwise, the length of the longer of the prefixes
            (suffixes) of the bodiless lines just above and below the
            block, if the segment containing the block has any bodiless
            lines; otherwise, 0.  (See below for the definitions of
            block, segment, and bodiless line.)

        augmented fallback prelen
            Let <fp> be the fallback prelen of an IP.  If the IP
            contains more than one line, or if <quote> is 0, then
            the augmented fallback prelen of the IP is simply <fp>.
            Otherwise, it is <fp> plus the number of quote characters
            immediately following the first <fp> characters of the line.

        quoteprefix
            The quoteprefix of a line is the longest string of quote
            characters appearing at the beginning of the line, after
            this string has been stripped of any trailing spaces.

    Types of lines:

        blank line
            An empty line, or a line whose first character is not
            protective and which contains only spaces.

        protected line
            An input line whose first character is protective.

        bodiless line
            A line which is order <k> bodiless for some <k>.

        order <k> bodiless line
            There is no such thing as an order 0 bodiless line.  Suppose
            <S> is a a contiguous subsequence of a segment (see below)
            containing at least two lines, containing no order <k>-1
            bodiless lines, bounded above and below by order <k>-1
            bodiless lines and/or the beginning/end of the segment.
            Let <p> and <s> be the comprelen and comsuflen of <S>.
            Any member of <S> which, if stripped of its first <p> and
            last <s> characters, would be blank (or, if the parameter
            <repeat> is non-zero, would consist of the same character
            repeated at least <repeat> times), is order <k> bodiless.
            The first <p> characters of the bodiless line comprise its
            prefix; the last <s> characters comprise its suffix.  The
            character which repeats in the middle is called its repeat
            character.  If the middle is empty, the space is taken to be
            its repeat character.

        vacant line
            A bodiless line whose repeat character is the space.

        superfluous line
            Only blank and vacant lines may be superfluous.  If
            contiguous vacant lines lie at the beginning or end of
            a segment, they are all superfluous.  But if they lie
            between two non-vacant lines within a segment, then all are
            superfluous except one--the one which contains the fewest
            non-spaces.  In case of a tie, the first of the tied lines
            is chosen.  Similarly, if contiguous blank lines lie outside
            of any segments at the beginning or end of the input, they
            are all superfluous.  But if they lie between two segments
            and/or protected lines, then all are superfluous except the
            first.

    Groups of lines:

        segment
            A contiguous sequence of input lines containing no protected
            or blank lines, bounded above and below by protected lines,
            blank lines, and/or the beginning/end of the input.

        block
            A contiguous subsequence of a segment containing no bodiless
            lines, bounded above and below by bodiless lines and/or the
            beginning/end of the segment.

    Types of words:

        capitalized word
            If the parameter <cap> is 0, a capitalized word is one which
            contains at least one alphanumeric character, whose first
            alphanumeric character is not a lower case letter.  If <cap>
            is 1, every word is considered a capitalized word.  (See the
            c option in the Options section.)

        curious word
            A word which contains a terminal character <c> such that
            there are no alphanumeric characters in the word after <c>,
            but there is at least one alphanumeric character in the word
            before <c>.


Options

    Any command line argument may begin with one minus sign (-) which
    is ignored.  Generally, more than one option may appear in a single
    command line argument, but there are exceptions:  The help, version,
    B, P, and Q options must have whole arguments all to themselves.

    help        Causes all remaining arguments to be ignored.  No input
                is read.  A usage message is printed on the output
                briefly describing the options used by par.

    version     Causes all remaining arguments to be ignored.  No input
                is read. "par 1.52" is printed on the output.  Of
                course, this will change in future releases of Par.

    B<op><set>  <op> is a single character, either an equal sign (=),
                a plus sign (+), or a minus sign (-), and <set> is a
                string using charset syntax.  If <op> is an equal sign,
                the set of body characters is set to the character set
                defined by <set>.  If <op> is a plus/minus sign, the
                characters in the set defined by <set> are added/removed
                to/from the existing set of body characters defined by
                the PARBODY environment variable and any previous B
                options.  It is okay to add characters that are already
                in the set or to remove characters that are not in the
                set.

    P<op><set>  Just like the B option, except that it applies to the
                set of protective characters.

    Q<op><set>  Just like the B option, except that it applies to the
                set of quote characters.

    All remaining options are used to set values of parameters.  Values
    set by command line options hold for all paragraphs.  Unset
    parameters are given default values.  Any parameters whose default
    values depend on the IP (namely <prefix> and <suffix>), if left
    unset, are recomputed separately for each paragraph.

    The approximate role of each parameter is described here.  See the
    Details section for the rest of the story.

    The first six parameters, <hang>, <prefix>, <repeat>, <suffix>,
    <Tab>, and <width>, may be set to any unsigned decimal integer less
    than 10000.

    h[<hang>]   Mainly affects the default values of <prefix> and
                <suffix>.  Defaults to 0.  If the h option is given
                without a number, the value 1 is inferred.  (See also
                the p and s options.)

    p[<prefix>] The first <prefix> characters of each line of the OP
                are copied from the first <prefix> characters of the
                corresponding line of the IP.  If there are more than
                <hang>+1 lines in the IP, the default value is the
                comprelen of all the lines in the IP except the first
                <hang> of them.  Otherwise, the default value is the
                augmented fallback prelen of the IP.  If the p option is
                given without a number, <prefix> is unset, even if it
                had been set earlier.  (See also the h and q options.)

    r[<repeat>] If <repeat> is non-zero, bodiless lines have the number
                of instances of their repeat characters increased or
                decreased until the length of the line is <width>.
                The exact value of <repeat> affects the definition of
                bodiless line.  Defaults to 0.  If the r option is given
                without a number, the value 3 is inferred.  (See also
                the w option.)

    s[<suffix>] The last <suffix> characters of each line of the OP
                are copied from the last <suffix> characters of the
                corresponding line of the IP.  If there are more than
                <hang>+1 lines in the IP, the default value is the
                comsuflen of all the lines in the IP except the first
                <hang> of them.  Otherwise, the default value is the
                fallback suflen of the IP.  If the s option is given
                without a number, <suffix> is unset, even if it had been
                set earlier.  (See also the h option.)

    T[<Tab>]    Tab characters in the input are expanded to spaces,
                assuming tab stops every <Tab> columns.  Must not be
                0.  Defaults to 1.  If the T option is given without a
                number, the value 8 is inferred.

    w[<width>]  No line in the OP may contain more than <width>
                characters, not including the trailing newlines.
                Defaults to 72.  If the w option is given without a
                number, the value 79 is inferred.

    The remaining thirteen parameters, <body>, <cap>, <div>, <Err>,
    <expel>, <fit>, <guess>, <invis>, <just>, <last>, <quote>, <Report>,
    and <touch>, may be set to either 0 or 1.  If the number is absent
    in the option, the value 1 is inferred.

    b[<body>]   If <body> is 1, prefixes may not contain any trailing
                body characters, and suffixes may not contain any
                leading body characters.  (Actually, the situation
                is complicated by space characters.  See comprelen
                and comsuflen in the Terminology section.)  If <body>
                is 0, prefixes and suffixes may not contain any body
                characters at all.  Defaults to 0.

    c[<cap>]    If <cap> is 1, all words are considered capitalized.
                This currently affects only the application of the g
                option.  Defaults to 0.

    d[<div>]    If <div> is 0, each block becomes an IP.  If <div> is 1,
                each block is subdivided into IPs as follows:  Let <p>
                be the comprelen of the block.  Let a line's status be
                1 if its (<p>+1)st character is a space, 0 otherwise.
                Every line in the block whose status is the same as the
                status of the first line will begin a new paragraph.
                Defaults to 0.

    E[<Err>]    If <Err> is 1, messages to the user (caused by the help
                and version options, or by errors) are sent to the error
                stream instead of the output stream.  Defaults to 0.

    e[<expel>]  If <expel> is 1, superfluous lines withheld from the
                output.  Defaults to 0.

    f[<fit>]    If <fit> is 1 and <just> is 0, par tries to make the
                lines in the OP as nearly the same length as possible,
                even if it means making the OP narrower.  Defaults to 0.
                (See also the j option.)

    g[<guess>]  If <guess> is 1, then when par is choosing line breaks,
                whenever it encounters a curious word followed by a
                capitalized word, it takes one of two special actions.
                If the two words are separated by a single space in
                the input, they will be merged into one word with an
                embedded non-breaking space.  If the two words are
                separated by more than one space, or by a line break,
                par will insure that they are separated by two spaces,
                or by a line break, in the output.  Defaults to 0.

    i[<invis>]  If <invis> is 1, then vacant lines inserted because
                <quote> is 1 are invisible; that is, they are not
                output.  If <quote> is 0, <invis> has no effect.
                Defaults to 0.  (See also the q option.)

    j[<just>]   If <just> is 1, par justifies the OP, inserting spaces
                between words so that all lines in the OP have length
                <width> (except the last, if <last> is 0).  Defaults to
                0.  (See also the w, l, and f options.)

    l[<last>]   If <last> is 1, par tries to make the last line of the
                OP about the same length as the others.  Defaults to 0.

    q[<quote>]  If <quote> is 1, then before each segment is scanned
                for bodiless lines, par supplies vacant lines between
                different quotation nesting levels as follows:  For each
                pair of adjacent lines in the segment (scanned from the
                top down) which have different quoteprefixes, one of
                two actions is taken.  If <invis> is 0, and either line
                consists entirely of quote characters and spaces (or is
                empty), that line is truncated to the longest common
                prefix of the two lines (both are truncated if both
                qualify).  Otherwise, a line consisting of the longest
                common prefix of the two lines is inserted between them.
                <quote> also affects the default value of <prefix>.
                Defaults to 0.  (See also the p and i options.)

    R[<Report>] If <Report> is 1, it is considered an error for an input
                word to contain more than <L> = (<width> - <prefix> -
                <suffix>) characters.  Otherwise, such words are chopped
                after each <L>th character into shorter words.  Defaults
                to 0.

    t[<touch>]  Has no effect if <suffix> is 0 or <just> is 1.
                Otherwise, if <touch> is 0, all lines in the OP have
                length <width>.  If <touch> is 1, the length of the
                lines is decreased until the suffixes touch the body of
                the OP.  Defaults to the logical OR of <fit> and <last>.
                (See also the s, j, w, f, and l options.)

    If an argument begins with a number, that number is assumed
    to belong to a p option if it is 8 or less, and to a w option
    otherwise.

    If the value of any parameter is set more than once, the last value
    is used.  When unset parameters are assigned default values, <hang>
    and <quote> are assigned before <prefix>, and <fit> and <last> are
    assigned before <touch> (because of the dependencies).

    It is an error if <width> <= <prefix> + <suffix>.


Environment

    PARBODY     Determines the initial set of body characters (which are
                used for determining comprelens and comsuflens), using
                charset syntax.  If PARBODY is not set, the set of body
                characters is initially empty.

    PARINIT     If set, par will read command line arguments from PARINIT
                before it reads them from the command line.  Within
                the value of PARINIT, arguments are separated by white
                characters.

    PARPROTECT  Determines the set of protective characters, using charset
                syntax.  If PARPROTECT is not set, the set of protective
                characters is initially empty.

    PARQUOTE    Determines the set of quote characters, using charset
                syntax.  If PARQUOTE is not set, the set of quote characters
                initially contains only the greater-than sign (>) and the
                space.

    If a NUL character appears in the value of an environment variable, it
    and the rest of the string will not be seen by par.

    Note that the PARINIT variable, together with the B, P, and Q
    options, renders the other environment variables unnecessary.  They
    are included for backward compatibility.

Details

    Lines are terminated by newline characters, but the newlines are not
    considered to be included in the lines.  If the last character of
    the input is a non-newline, a newline will be inferred immediately
    after it (but if the input is empty, no newline will be inferred;
    the number of input lines will be 0).  Thus, the input can always be
    viewed as a sequence of lines.

    Protected lines are copied unchanged from the input to the output.
    All other input lines, as they are read, have any NUL characters
    removed, and every white character (except newlines) turned into a
    space.  Actually, each tab character is turned into <Tab> - (<n> %
    <Tab>) spaces, where <n> is the number of characters preceeding the
    tab character on the line (evaluated after earlier tab characters
    have been expanded).

    Blank lines in the input are transformed into empty lines in the
    output.

    If <repeat> is 0, all bodiless lines are vacant, and they are all
    simply stripped of trailing spaces before being output.  If <repeat>
    is not 0, only vacant lines whose suffixes have length 0 are treated
    that way; other bodiless lines have the number of instances of their
    repeat characters increased or decreased until the length of the
    line is <width>.

    If <expel> is 1, superfluous lines are not output.  If <quote> and
    <invis> are both 1, there may be invisible lines; they are not
    output.

    The input is divided into segments, which are divided into blocks,
    which are divided into IPs.  The exact process depends on the values
    of <quote> and <div> (see q and d in the Options section).  The
    remainder of this section describes the process which is applied
    independently to each IP to construct the corresponding OP.

    After the values of the parameters are determined (see the Options
    section), the first <prefix> characters and the last <suffix>
    characters of each input line are removed and remembered.  It is
    an error for any line to contain fewer than <prefix> + <suffix>
    characters.

    The remaining text is treated as a sequence of characters, not
    lines.  The text is broken into words, which are separated by
    spaces.  That is, a word is a maximal sub-sequence of non-spaces.
    If <guess> is 1, some words might be merged (see g in the Options
    section).  The first word includes any spaces that preceed it on the
    same line.

    Let <L> = <width> - <prefix> - <suffix>.

    If <Report> is 0, some words may get chopped up at this point (see R
    in the Options section).

    The words are reassembled, preserving their order, into lines.  If
    <just> is 0, adjacent words within a line are separated by a single
    space (or sometimes two if <guess> is 1), and line breaks are chosen
    so that the paragraph satisfies the following properties:

         1) No line contains more than <L> characters.

         2) If <fit> is 1, the difference between the lengths of the
            shortest and longest lines is as small as possible.

         3) The shortest line is as long as possible, subject to
            properties 1 and 2.

         4) Let <target> be <L> if <fit> is 0, or the length of the
            longest line if <fit> is 1.  The sum of the squares of the
            differences between <target> and the lengths of the lines is
            as small as possible, subject to properties 1, 2, and 3.

        If <last> is 0, the last line does not count as a line for the
        purposes of properties 2, 3, and 4 above.

        If all the words fit on a single line, the properties as worded
        above don't make much sense.  In that case, no line breaks are
        inserted.

    If <just> is 1, adjacent words within a line are separated by one
    space (or sometimes two if <guess> is 1) plus zero or more extra
    spaces.  The value of <fit> is disregarded, and line breaks are
    chosen so that the paragraph satisfies the following properties:

         1) Every line contains exactly <L> characters.

         2) The largest inter-word gap is as small as possible, subject
            to property 1.  (An inter-word gap consists only of the
            extra spaces, not the regular spaces.)

         3) The sum of the squares of the lengths of the inter-word gaps
            is as small as possible, subject to properties 1 and 2.

        If <last> is 0, the last line does not count as a line for the
        purposes of property 1, and it does not require or contain any
        extra spaces.

        Extra spaces are distributed as uniformly as possible among the
        inter-word gaps in each line.

        In a justified paragraph, every line must contain at least two
        words, but that's not always possible to accomplish.  If the
        paragraph cannot be justified, it is considered an error.

    If the number of lines in the resulting paragraph is less than
    <hang>, empty lines are added at the end to bring the number of
    lines up to <hang>.

    If <just> is 0 and <touch> is 1, <L> is changed to be the length of
    the longest line.

    If <suffix> is not 0, each line is padded at the end with spaces to
    bring its length up to <L>.

    To each line is prepended <prefix> characters.  Let <n> be the
    number of lines in the IP, let <afp> be the augmented fallback
    prelen of the IP, and let <fs> be the fallback suflen of the IP.
    The characters which are prepended to the <i>th line are chosen as
    follows:

     1) If <i> <= <n>, the characters are copied from the ones that were
        removed from the beginning of the <n>th input line.

     2) If <i> > <n> > <hang>, the characters are copied from the ones
        that were removed from the beginning of the last input line.

     3) If <i> > <n> and <n> <= <hang>, the first min(<afp>,<prefix>)
        of the characters are copied from the ones that were removed
        from the beginning of the last input line, and the rest are all
        spaces.

    Then to each line is appended <suffix> characters.  The characters
    which are appended to the <i>th line are chosen as follows:

     1) If <i> <= <n>, the characters are copied from the ones that were
        removed from the end of the nth input line.

     2) If <i> > <n> > <hang>, the characters are copied from the ones
        that were removed from the end of the last input line.

     3) If <i> > <n> and <n> <= <hang>, the first min(<fs>,<suffix>)
        of the characters are copied from the ones that were removed
        from the beginning of the last input line, and the rest are all
        spaces.

    Finally, the lines are printed to the output as the OP.


Diagnostics

    If there are no errors, par returns EXIT_SUCCESS (see <stdlib.h>).

    If there is an error, an error message will be printed to the
    output, and par will return EXIT_FAILURE.  If the error is local
    to a single paragraph, the preceeding paragraphs will have been
    output before the error was detected.  Line numbers in error
    messages are local to the IP in which the error occurred.  All
    error messages begin with "par error:" on a line by itself.  Error
    messages concerning command line or environment variable syntax are
    accompanied by the same usage message that the help option produces.

    Of course, trying to print an error message would be futile if an
    error resulted from an output function, so par doesn't bother doing
    any error checking on output functions.


Examples

    The superiority of par's dynamic programming algorithm over a greedy
    algorithm (such as the one used by fmt) can be seen in the following
    example:

    Original paragraph (note that each line begins with 8 spaces):

        We the people of the United States,
        in order to form a more perfect union,
        establish justice,
        insure domestic tranquility,
        provide for the common defense,
        promote the general welfare,
        and secure the blessing of liberty
        to ourselves and our posterity,
        do ordain and establish the Constitution
        of the United States of America.

    After a greedy algorithm with width = 39:

        We the people of the United
        States, in order to form a more
        perfect union, establish
        justice, insure domestic
        tranquility, provide for the
        common defense, promote the
        general welfare, and secure the
        blessing of liberty to
        ourselves and our posterity, do
        ordain and establish the
        Constitution of the United
        States of America.

    After "par 39":

        We the people of the United    
        States, in order to form a     
        more perfect union, establish  
        justice, insure domestic       
        tranquility, provide for the   
        common defense, promote the    
        general welfare, and secure    
        the blessing of liberty to     
        ourselves and our posterity,   
        do ordain and establish the    
        Constitution of the United     
        States of America.             

    The line breaks chosen by par are clearly more eye-pleasing.

    par is most useful in conjunction with the text-filtering features
    of an editor, such as the ! commands of vi.  You may wish to add the
    following lines to your .exrc file:

        " use Bourne shell for speed:
        set shell=/bin/sh
        "
        " reformat paragraph with no arguments:
        map ** {!}par^M}
        "
        " reformat paragraph with arguments:
        map *^V  {!}par 

    Note that the leading spaces must be removed, and that what is shown
    as ^M and ^V really need to be ctrl-M and ctrl-V.  Also note that
    the last map command contains two spaces following the ctrl-V, plus
    one at the end of the line.

    To reformat a simple paragraph delimited by blank lines in vi, you
    can put the cursor anywhere in it and type "**" (star star).  If
    you need to supply arguments to par, you can type "* " (star space)
    instead, then type the arguments.

    The rest of this section is a series of before-and-after pictures
    showing some typical uses of par.  In all cases, no environment
    variables are set.

    Before:

        /*   We the people of the United States, */
        /* in order to form a more perfect union, */
        /* establish justice, */
        /* insure domestic tranquility, */
        /* provide for the common defense, */
        /* promote the general welfare, */
        /* and secure the blessing of liberty */
        /* to ourselves and our posterity, */
        /* do ordain and establish the Constitution */
        /* of the United States of America. */

    After "par 59":

        /*   We the people of the United States, in      */
        /* order to form a more perfect union, establish */
        /* justice, insure domestic tranquility, provide */
        /* for the common defense, promote the general   */
        /* welfare, and secure the blessing of liberty   */
        /* to ourselves and our posterity, do ordain     */
        /* and establish the Constitution of the United  */
        /* States of America.                            */

    Or after "par 59f":

        /*   We the people of the United States,  */
        /* in order to form a more perfect union, */
        /* establish justice, insure domestic     */
        /* tranquility, provide for the common    */
        /* defense, promote the general welfare,  */
        /* and secure the blessing of liberty to  */
        /* ourselves and our posterity, do ordain */
        /* and establish the Constitution of the  */
        /* United States of America.              */

    Or after "par 59l":

        /*   We the people of the United States, in      */
        /* order to form a more perfect union, establish */
        /* justice, insure domestic tranquility,         */
        /* provide for the common defense, promote       */
        /* the general welfare, and secure the           */
        /* blessing of liberty to ourselves and our      */
        /* posterity, do ordain and establish the        */
        /* Constitution of the United States of America. */

    Or after "par 59lf":

        /*   We the people of the United States,  */
        /* in order to form a more perfect union, */
        /* establish justice, insure domestic     */
        /* tranquility, provide for the common    */
        /* defense, promote the general welfare,  */
        /* and secure the blessing of liberty     */
        /* to ourselves and our posterity, do     */
        /* ordain and establish the Constitution  */
        /* of the United States of America.       */

    Or after "par 59lft0":

        /*   We the people of the United States,         */
        /* in order to form a more perfect union,        */
        /* establish justice, insure domestic            */
        /* tranquility, provide for the common           */
        /* defense, promote the general welfare,         */
        /* and secure the blessing of liberty            */
        /* to ourselves and our posterity, do            */
        /* ordain and establish the Constitution         */
        /* of the United States of America.              */

    Or after "par 59j":

        /*   We  the people  of  the  United States,  in */
        /* order to form a more perfect union, establish */
        /* justice, insure domestic tranquility, provide */
        /* for the  common defense, promote  the general */
        /* welfare, and  secure the blessing  of liberty */
        /* to ourselves and our posterity, do ordain and */
        /* establish  the  Constitution  of  the  United */
        /* States of America.                            */

    Or after "par 59jl":

        /*   We  the   people  of  the   United  States, */
        /* in   order    to   form   a    more   perfect */
        /* union,  establish  justice,  insure  domestic */
        /* tranquility, provide for  the common defense, */
        /* promote  the  general   welfare,  and  secure */
        /* the  blessing  of  liberty to  ourselves  and */
        /* our  posterity, do  ordain and  establish the */
        /* Constitution of the United States of America. */

    Before:

        Preamble      We the people of the United States,
        to the US     in order to form
        Constitution  a more perfect union,
                      establish justice,
                      insure domestic tranquility,
                      provide for the common defense,
                      promote the general welfare,
                      and secure the blessing of liberty
                      to ourselves and our posterity,
                      do ordain and establish
                      the Constitution
                      of the United States of America.

    After "par 52h3":

        Preamble      We the people of the United
        to the US     States, in order to form a
        Constitution  more perfect union, establish
                      justice, insure domestic
                      tranquility, provide for the
                      common defense, promote the
                      general welfare, and secure
                      the blessing of liberty to
                      ourselves and our posterity,
                      do ordain and establish the
                      Constitution of the United
                      States of America.

    Before:

         1  We the people of the United States,
         2  in order to form a more perfect union,
         3  establish justice,
         4  insure domestic tranquility,
         5  provide for the common defense,
         6  promote the general welfare,
         7  and secure the blessing of liberty
         8  to ourselves and our posterity,
         9  do ordain and establish the Constitution
        10  of the United States of America.

    After "par 59p12l":

         1  We the people of the United States, in order to
         2  form a more perfect union, establish justice,
         3  insure domestic tranquility, provide for the
         4  common defense, promote the general welfare,
         5  and secure the blessing of liberty to ourselves
         6  and our posterity, do ordain and establish the
         7  Constitution of the United States of America.

    Before:

        > > We the people
        > > of the United States,
        > > in order to form a more perfect union,
        > > establish justice,
        > > ensure domestic tranquility,
        > > provide for the common defense,
        >
        > Promote the general welfare,
        > and secure the blessing of liberty
        > to ourselves and our posterity,
        > do ordain and establish
        > the Constitution of the United States of America.

    After "par 52":

        > > We the people of the United States, in
        > > order to form a more perfect union,
        > > establish justice, ensure domestic
        > > tranquility, provide for the common
        > > defense,
        >
        > Promote the general welfare, and secure
        > the blessing of liberty to ourselves and
        > our posterity, do ordain and establish
        > the Constitution of the United States of
        > America.

    Before:

        >   We the people
        > of the United States,
        > in order to form a more perfect union,
        > establish justice,
        > ensure domestic tranquility,
        > provide for the common defense,
        >   Promote the general welfare,
        > and secure the blessing of liberty
        > to ourselves and our posterity,
        > do ordain and establish
        > the Constitution of the United States of America.

    After "par 52d":

        >   We the people of the United States,
        > in order to form a more perfect union,
        > establish justice, ensure domestic
        > tranquility, provide for the common
        > defense,
        >   Promote the general welfare, and secure
        > the blessing of liberty to ourselves and
        > our posterity, do ordain and establish
        > the Constitution of the United States of
        > America.

    Before:

        # 1. We the people of the United States.
        # 2. In order to form a more perfect union.
        # 3. Establish justice, ensure domestic
        #    tranquility.
        # 4. Provide for the common defense
        # 5. Promote the general welfare.
        # 6. And secure the blessing of liberty
        #    to ourselves and our posterity.
        # 7. Do ordain and establish the Constitution.
        # 8. Of the United States of America.

    After "par 37p13dh":

        # 1. We the people of the
        #    United States.
        # 2. In order to form a more
        #    perfect union.
        # 3. Establish justice,
        #    ensure domestic
        #    tranquility.
        # 4. Provide for the common
        #    defense
        # 5. Promote the general
        #    welfare.
        # 6. And secure the blessing
        #    of liberty to ourselves
        #    and our posterity.
        # 7. Do ordain and establish
        #    the Constitution.
        # 8. Of the United States of
        #    America.

    Before:

        /*****************************************/
        /*   We the people of the United States, */
        /* in order to form a more perfect union, */
        /* establish justice, insure domestic    */
        /* tranquility,                          */
        /*                                       */
        /*                                       */
        /*   [ provide for the common defense, ] */
        /*   [ promote the general welfare,    ] */
        /*   [ and secure the blessing of liberty ] */
        /*   [ to ourselves and our posterity, ] */
        /*   [                                 ] */
        /*                                       */
        /* do ordain and establish the Constitution */
        /* of the United States of America.       */
        /******************************************/

    After "par 42r":

        /********************************/
        /*   We the people of the       */
        /* United States, in order to   */
        /* form a more perfect union,   */
        /* establish justice, insure    */
        /* domestic tranquility,        */
        /*                              */
        /*                              */
        /*   [ provide for the common ] */
        /*   [ defense, promote the   ] */
        /*   [ general welfare, and   ] */
        /*   [ secure the blessing of ] */
        /*   [ liberty to ourselves   ] */
        /*   [ and our posterity,     ] */
        /*   [                        ] */
        /*                              */
        /* do ordain and establish the  */
        /* Constitution of the United   */
        /* States of America.           */
        /********************************/

    Or after "par 42re":

        /********************************/
        /*   We the people of the       */
        /* United States, in order to   */
        /* form a more perfect union,   */
        /* establish justice, insure    */
        /* domestic tranquility,        */
        /*                              */
        /*   [ provide for the common ] */
        /*   [ defense, promote the   ] */
        /*   [ general welfare, and   ] */
        /*   [ secure the blessing of ] */
        /*   [ liberty to ourselves   ] */
        /*   [ and our posterity,     ] */
        /*                              */
        /* do ordain and establish the  */
        /* Constitution of the United   */
        /* States of America.           */
        /********************************/

    Before:

        Joe Public writes:
        > Jane Doe writes:
        > >
        > >
        > > I can't find the source for uncompress.
        > Oh no, not again!!!
        >
        >
        > Isn't there a FAQ for this?
        >
        >
        That wasn't very helpful, Joe. Jane,
        just make a link from uncompress to compress.

    After "par 40q":

        Joe Public writes:

        > Jane Doe writes:
        >
        >
        > > I can't find the source for
        > > uncompress.
        >
        > Oh no, not again!!!
        >
        >
        > Isn't there a FAQ for this?
        >

        That wasn't very helpful, Joe.
        Jane, just make a link from
        uncompress to compress.

    Or after "par 40qe":

        Joe Public writes:

        > Jane Doe writes:
        >
        > > I can't find the source for
        > > uncompress.
        >
        > Oh no, not again!!!
        >
        > Isn't there a FAQ for this?

        That wasn't very helpful, Joe.
        Jane, just make a link from
        uncompress to compress.

    Or after "par 40qi":

        Joe Public writes:
        > Jane Doe writes:
        > >
        > >
        > > I can't find the source for
        > > uncompress.
        > Oh no, not again!!!
        >
        >
        > Isn't there a FAQ for this?
        >
        >
        That wasn't very helpful, Joe.
        Jane, just make a link from
        uncompress to compress.

    Or after "par 40qie":

        Joe Public writes:
        > Jane Doe writes:
        > > I can't find the source for
        > > uncompress.
        > Oh no, not again!!!
        >
        > Isn't there a FAQ for this?
        That wasn't very helpful, Joe.
        Jane, just make a link from
        uncompress to compress.

    Before:

        I sure hope there's still room
        in Dr. Jones' section of archaeology.
        I've heard he's the bestest.  [sic]

    After "par 50g":

        I sure hope there's still room in
        Dr. Jones' section of archaeology.  I've
        heard he's the bestest. [sic]

    Or after "par 50gc":

        I sure hope there's still room in
        Dr. Jones' section of archaeology.  I've
        heard he's the bestest.  [sic]

    Before:

        John writes:
        : Mary writes:
        : + Anastasia writes:
        : + > Hi all!
        : + Hi Ana!
        : Hi Ana & Mary!
        Please unsubscribe me from alt.hello.

    After "par Q+:+ q":

        John writes:

        : Mary writes:
        :
        : + Anastasia writes:
        : +
        : + > Hi all!
        : +
        : + Hi Ana!
        :
        : Hi Ana & Mary!

        Please unsubscribe me from alt.hello.

    Before:

        amc> The b option was added primarily to deal with
        amc> this new style of quotation
        amc> which became popular after Par 1.41 was released.
        amc>
        amc> Par still pays attention to body characters.
        amc> Par should not mistake "Par" for part of the prefix.
        amc> Par should not mistake "." for a suffix.

    After "par B=._A_a 50bg":

        amc> The b option was added primarily to
        amc> deal with this new style of quotation
        amc> which became popular after Par 1.41
        amc> was released.
        amc>
        amc> Par still pays attention to body
        amc> characters.  Par should not mistake
        amc> "Par" for part of the prefix.  Par
        amc> should not mistake "." for a suffix.


Limitations

    The <guess> feature guesses wrong in cases like the following:

        I calc'd the approx.
        Fermi level to 3 sig. digits.

    With <guess> = 1, par will incorrectly assume that "approx." ends a
    sentence.  If the input were:

        I calc'd the approx. Fermi
        level to 3 sig. digits.

    then par would refuse to put a line break between "approx." and
    "Fermi" in the output, mainly to avoid creating the first situation
    (in case the paragraph were to be fed back through par again).
    This non-breaking space policy does come in handy for cases like
    "Mr. Johnson" and "Jan. 1", though.

    The <guess> feature only goes one way.  par can preserve wide
    sentence breaks in a paragraph, or remove them, but it can't insert
    them if they aren't already in the input.

    If you use tabs, you may not like the way par handles (or doesn't
    handle) them.  It expands them into spaces.  I didn't let par output
    tabs because tabs don't make sense.  Not everyone's terminal has
    the same tab settings, so text files containing tabs are sometimes
    mangled.  In fact, almost every text file containing tabs gets
    mangled when something is inserted at the beginning of each line
    (when quoting e-mail or commenting out a section of a shell script,
    for example), making them a pain to edit.  In my opinion, the world
    would be a nicer place if everyone stopped using tabs, so I'm doing
    my part by not letting par output them.  (Thanks to Eric Stuebe for
    showing me the light about tabs.)

    There is currently no way for the length of the output prefix to
    differ from the length of the input prefix.  Ditto for the suffix.
    I may consider adding this capability in a future release, but right
    now I'm not sure how I'd want it to work.


Apologies

    Par began in July 1993 as a small program designed to do one narrow
    task: reformat a single paragraph that might have a border on either
    side.  It was pretty clean back then.  Over the next three months,
    it very rapidly expanded to handle multiple paragraphs, offer more
    options, and take better guesses, at the cost of becoming extremely
    complex, and very unclean.  It is nowhere near the optimal design
    for the larger task it now tries to address.  Its only redeeming
    features are that it is extremely useful (I find it indispensable),
    extremely portable, and very stable (between the release of version
    1.41 on 1993-Oct-31 and the release of version 1.52 on 2001-Apr-29,
    no incorrect behavior was reported).

    Back in 1993 I had very little experience at writing documentation
    for users, so the documentation for Par became rather nightmarish.
    There is no separation between how-it-works (which is painfully
    complex) and how-to-use-it (which is fairly simple, if you can ever
    figure it out).

    Someday I ought to reexamine the problem, and redesign a new, clean
    solution from scratch.  I don't know when I might get enough free
    time to start on such a project.  Text files may be obsolete by
    then.


Bugs

    If I knew of any bugs, I wouldn't release the package.  Of course,
    there may be bugs that I haven't yet discovered.

    If you find any bugs (in the program or in the documentation), or if
    you have any suggestions, please send e-mail to:

        amc@cs.berkeley.edu

    When reporting a bug, please include the exact input and command
    line options used, and the version number of par, so that I can
    reproduce it.

    The latest release of Par is available on the Web at:

        http://www.cs.berkeley.edu/~amc/Par/

    These addresses will change.  I'll try to leave forward pointers.
