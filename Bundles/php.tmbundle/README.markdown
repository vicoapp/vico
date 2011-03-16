PHP Bundle for TextMate
========================

Version 3.0.1 [2010-03-03]
--------------------------

Contributors: Josh Varner <josh.varner@gmail.com>

* Fixes in the language grammar for class instantiations using variable class names


Version 3.0.0 [2010-03-02]
--------------------------

Contributors: Josh Varner <josh.varner@gmail.com>

* Updated function lists and completion lists to be in line with PHP 5.3.1
* Added script to make `functions.plist` completions file from `functions.txt`
* Added support in language grammar for:
	* Namespaces
	* Interfaces extending other interfaces
	* Multi-line `class`/`extends`/`inherits` areas (before `{` or `;`)
	* Anonymous function declarations
	* Closure calls and `__invoke` calls
	* New magic methods (`__invoke`, `__callStatic`, and so on)
	* Nowdoc support (essentially Heredoc but without interpolation)
* Reformatted `README` in Markdown
* Updated test-cases.php with examples for these new language


Version 2.0beta6 [2005-03-04] <mats@imediatec.co.uk>
----------------------------------------------------

Contributors: Justin French, Sune Foldager, Allan Odgaard, Matteo Spinelli, Kumar McMillan, Mats Persson

### PHP.plist ###

* amended "comments.block.phpdocs.php" to highlight until end of line
* amended "keywords.operators.comparison.php" to prevent highlighting of <?php ?> tags

Also added a reworked HTML (PHP) and added CSS (PHP) and JavaScript (PHP) syntaxes. These syntax files may still have some issues, visual bugs or missing words/tags/attributes, etc. If you find any fault, please let me know. Thanks!

### HTML (PHP).plist ###

A reworking/rebuilding of the existing HTML-PHP syntax for more fine-grained control of tags, attributes and values, as well as some additions from the main HTML syntax file.

* changed text formatting for better readability of syntax structure
* changed syntax colouring to a darker more easy to read scheme (temporary display where all syntax groups have a unique colour)
* added "macros.server-side-includes.html" for Server Side Includes syntax.
* added "meta.docinfo.xml.html" for `<?xml..>` highlighting
* removed "keywords.markup.tags.html" and "keywords.markup.tag.options.html" replaced with improved elements and attributes syntax groups (see next two points)
* added "keywords.markup.elements.html" with named html elements so that only proper HTML tags are highlighted
* added "keywords.markup.attributes.html" with named attributes so that only proper attributes are highlighted
* changed "embedded.php" to "embedded.php.html"
* added "embedded.css.html" for CSS syntax inside HTML files (see below for more info)
* added "embedded.js.html" for JavaScript syntax inside HTML files (see below for more info)

### CSS (PHP).plist ###

Added a CSS syntax for PHP which is also a complete reworking/rebuilding of the existing CSS syntax for more fine-grained control of selectors, properties and values.

* text formatted for better readability of syntax structure
* temporary syntax colouring in line with other files in this package for easier to read scheme (all syntax groups have a unique colour)
* added/reworked "keywords.selectors.css" syntax group enabling unique syntax colouring for each sub-pattern
	* "keywords.selectors.html-elements.css" with named `<tags>`
	* "keywords.selectors.classes.css" for User Defined .Classes
	* "keywords.selectors.id.css" for User Defined #IDs
	* "keywords.selectors.pseudo-class.css" for :hover, :visited etc.
* added "keywords.at-rules.css" for @import or @media syntaxes. 
* added "keywords.properties.css" for named properties values;
* added/reworked "keywords.properties.values.css" with sub syntax groups
	* "keywords.properties.values.keywords.css" for CSS value keywords, like top, left, inherit etc.
	* "keywords.properties.values.fonts.css" for common Fonts, or "quoted fonts"
	* "keywords.properties.values.digits.css" for displayed numbers. = 10px
	* "keywords.properties.values.units.css" for px/em/cm/pt/% etc,
	* "keywords.properties.values.colors.css" for #FFFFFF colours
	* "keywords.properties.values.functions.css" for url(),rgb() etc. with sub patterns for strings, rgb colour and % values.

### JavaScript (PHP).plist ###

Added a JS syntax for PHP which is also a complete reworking/rebuilding of the existing JavaScript syntax for more fine-grained control of Objects, Methods and properties.

* text formatted for better readability of syntax structure
* temporary syntax colouring in line with other files in this package for easier to read scheme (all syntax groups have a unique colour)
* added "comments.html.js" for supported `<!--` tags inside `<script>` tags in HTML.
* changed "keywords.js" to "keywords.reserved.js" and added all known reserved keywords
* added "keywords.objects.js" syntax group with named JS Objects (currently set to be case-insensitive, but can be changed to case sensitive)
* added "keywords.methods.js" syntax group with named JS methods (case-sensitive)
* added "keywords.properties.js" syntax group with named JS properties (case-sensitive)
* added "keywords.event-handlers.js" syntax group with named JS Event-handlers (case-sensitive)
* added "keywords.operators.js" syntax group with complete range of operators
* added "constants.js" for JavaScript defined constants
* disabled "strings.regex.js" as it cuts out syntax colouring. Needs more work.

### Other ###

Also added a number of generic snippets.


Version 2.0beta5 [2005-02-28] <mats@imediatec.co.uk>
----------------------------------------------------

* changed text formatting for better readability of syntax structure
* changed syntax colouring to a darker more easy to read scheme (still experimental)
* changed Comments-> "PHPDoc tags" to  "comments.block.phpdocs.php" for better TM stylesheet support
* changed "keywords.control.php" syntax group to only deal with Control Structures.
* added "keywords.control.includerequire.php" syntax group for separate highlighting of include/require functions
* added "keywords.exceptions.php" syntax group to deal with Exception handling in PHP5
* added "keywords.constructs.php" syntax group to deal with classes for PHP4/5
* incorporated the Scope Resolution Operator `::` and `->` into the "keywords.constructs.php" syntax group
* added "keywords.constructs.members.php" syntax group for class member status declaration
* changed all "keywords.<php-built-in-functions>.php" to "keywords.functions.<php-built-in-functions>.php" for better TM stylesheet support
* incorporated the `[ => ]` into the "keywords.functions.array.php" syntax group
* added/reworked the Operators syntax group
	* "keywords.operators.arithmetic.php" syntax group
	* "keywords.operators.comparison.php" syntax group
	* "keywords.operators.error-control.php" syntax group
	* "keywords.operators.increment-decrement.php" syntax group
	* "keywords.operators.logical.php" syntax group
	* "keywords.operators.strings.php" syntax group
	* "keywords.operators.type.php" syntax group
	* removed "keywords.operators.arrows.php" syntax group as these were incorporated in other groups -> keywords.constructs & keywords.functions.array
* changed Variables-> "Superglobal Variable" syntax group to "keywords.variables.globals.php"
* amended list of variables in "keywords.variables.globals.php" to contain only the (validation required) globals
* added "keywords.variables.globals.safer.php" syntax group for safer (=non-validation required) global variables.
* changed Misc. -> "keywords.control.php" to "constants.php" and added a few good usability shortcuts (need to be define()'d in code )
* moved "constants.numeric.php" syntax group to be part of Constants syntax group
* added "constants.core-predefined.php" syntax group
* added "constants.std-predefined.php syntax group


Version 2.0beta4 [2005-02-25] <kumar.mcmillan@gmail.com>
--------------------------------------------------------

Contributors: Justin French, Sune Foldager, Allan Odgaard, Matteo Spinelli, Kumar McMillan

* Added PHP Documentor snippets (snippet "phpdoc_u" prints usage)


Version 2.0beta3 [2005-02-24]
-----------------------------

* Added PHP5 language constructs and PHPDoc tags to inline comments


Version 2.0beta2 [2005-02-23]
-----------------------------

Under Allan suggestion I stripped out some functions from the list.

### Stripped functions ###

* Advanced PHP debugger functions
* Aspell functions
* PHP bytecode Compiler
* CCVS API Functions
* COM and .Net (any complains about this?) 
* Cybercash Payment Functions (is someone really using them?)
* DBM Functions
* DOM Functions (most of them are class functions, don't know how to handle them exactly with code highlighting)
* DOM XML Functions (same as above)
* Hyperwave Functions
* Hyperwave API Functions
* ICAP Functions
* Ingres II Functions (removed as considered experimental)
* mailparse Functions
* MCVE Payment Functions
* Memcache Functions
* mnoGoSearch Functions           
* Mohawk Software Session Handler Functions (I heard bugs about it)
* muscat Functions (here kitty-kitty-kitty!)
* Ncurses Terminal Screen Control Functions
* YP/NIS Functions
* OpenAL Audio Bindings
* PDO Functions
* Verisign Payflow Pro Functions
* XSL functions
* YAZ Functions
	
Please let me know if you think I removed an important set of functions or you think I kept useless ones.
	
I heard a new code colouring method is under development, so I am not working anymore on color scheme until the new TM version will be available


Version 2.0beta1 [2005-02-21]
-----------------------------

Contributors: Matteo Spinelli

* added all 3500+ PHP's functions, deprecated onces are also available but commented out
* all functions are grouped by topic/type and displayed alphabetically
* new color scheme 

Version 1.0
-----------

Contributors: Justin French, Sune Foldager, Allan Odgaard

* commented out the auto-indent feature, because it helps some, and makes
  life a real pain for others, depending on coding style
* PHP's 3500+ native functions aren't here yet -- just reserved words and
  basic constants from the docs, plus the control structures and language
  constructs
