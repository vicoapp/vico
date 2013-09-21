;; @file       doc.nu
;; @discussion Documentation extraction utility for Nu.
;;
;; @copyright  Copyright (c) 2007 Tim Burks, Radtastical Inc.
;;
;;   Licensed under the Apache License, Version 2.0 (the "License");
;;   you may not use this file except in compliance with the License.
;;   You may obtain a copy of the License at
;;
;;       http://www.apache.org/licenses/LICENSE-2.0
;;
;;   Unless required by applicable law or agreed to in writing, software
;;   distributed under the License is distributed on an "AS IS" BASIS,
;;   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;;   See the License for the specific language governing permissions and
;;   limitations under the License.

(global SPACE 32)
(global TAB 9)

(class NSString
 ;; Create a copy of a string with leading whitespace removed.
 (- (id) strip is
    (set i 0)
    (while (and (< i (self length))
                (or (eq (self characterAtIndex:i) SPACE)
                    (eq (self characterAtIndex:i) TAB)))
           (set i (+ i 1)))
    (self substringFromIndex:i))
 ;; Test to see whether a string begins with a specified substring.
 (- (id) beginsWithString:(id) string is
    (set range (self rangeOfString:string))
    (and range (eq (range first) 0)))
 ;; Shorthand method to write files using UTF8 encodings.
 (- (id) writeToFile:(id) fileName is
    (puts "writing #{fileName}")
    (self writeToFile:fileName atomically:NO encoding:NSUTF8StringEncoding error:(set perror ((NuReference alloc) init)))))

(class NSDate
 ;; Generate a string representation of the same form as this one:
 ;;
 ;; "Thursday, 30 Aug 2007"
 (- (id) descriptionForDocumentation is
    (self descriptionWithCalendarFormat:"%A, %d %b %Y" timeZone:nil locale:nil)))

(class NSRegularExpressionCheckingResult
 ;; Compare matches by their location.  This allows arrays of matches to be sorted.
 (- (NSComparisonResult) compare: (id) other is
    (set self-start  ((self  range) first))
    (set other-start ((other range) first))
    (self-start compare: other-start)))

;; Matches one part of a selector.
(set selector-pattern /(\w+:)\s*\(([\w<>]+\s*\*?)\)\s*(\w+)\s*/)

;; Match selectors of arity 0.
(set signature-pattern0
     /(\-|\+)\s*\(([\w<>]+\s*\*?)\)\s*(\w+)/)

;; Match selectors of arity 1 or more.
(set signature-pattern1
     /(\-|\+)\s*\(([\w<>]+\s*\*?)\)\s*(((\w+:)\s*\(([\w<>]+\s*\*?)\)\s*(\w+)\s*)+)/)

;; Match all selectors.
(set signature-pattern
     /(\-|\+)\s*\(([\w<>]+\s*\*?)\)\s*(\w+)((:\s*\(([\w<>]+\s*\*?)\)\s*(\w+)\s*)(\w+:\s*\(([\w<>]+\s*\*?)\)\s*(\w+)\s*)*)?/)

;; Match Objective-C class implementation declarations.
(set implementation-pattern
     /@implementation\s+(\w*)/)

;; Match Objective-C class interface declarations.
(set interface-pattern
     /@interface\s+(\w*)\s*(:\s*(\w*))?/)

;; Match Objective-C protocol declarations.
(set protocol-pattern
     /@protocol\s+(\w*)/)

;; Match Objective-C documentation comments.
(set objc-comment-pattern
     /\/\*!((.|\n)+?)\*\//)

;; Match Nu comments.
(set nu-comment-pattern
     /((;|\#)+)\s*(.*)/)

;; @abstract NuDoc class for building file descriptions.
;; @discussion NuDoc creates one instance of this class for each source file that it reads.
(class NuDocFileInfo is NSObject
 
 ;; Get the file description for a named file.
 (+ (id) infoForFileNamed:(id)name is
    (unless (set fileInfo ($files objectForKey:name))
            (set fileInfo ((NuDocFileInfo alloc) initWithName:name))
            ($files setObject:fileInfo forKey:name))
    fileInfo)
 
 ;; Initialize a description for a named file.
 (- (id) initWithName:(id) name is
    (super init)
    (set @name name)
    (set @niceName (NSMutableString stringWithString:name))
    (@niceName replaceOccurrencesOfString:"." withString:"_" options:0 range:(list 0 (@niceName length)))
    (@niceName replaceOccurrencesOfString:"/" withString:"_" options:0 range:(list 0 (@niceName length)))
    (set @discussion (NSMutableString string))
    (set @methods (NSMutableArray array))
    (set @classes (NSMutableArray array))
    self)
 
 ;; Generate a link to the html description of the file.
 (- (id) linkWithPrefix:(id) prefix is
    (&a href:(+ prefix (self niceName) ".html") @name))
 
 ;; Set the raw comments associated with a file.
 (- (void) setComments:(id) comments is
    (set @comments comments)
    (self parseFileComments))
 
 ;; Extract information from one line of file comments.
 (- (void) parseFileCommentLine:(id) line is
    (cond ((or (line beginsWithString:"@class")
               (line beginsWithString:"@category")
               (line beginsWithString:"@method")
               (line beginsWithString:"@function")) (set @finished YES))
          ((line beginsWithString:"!/") nil)
          ((line beginsWithString:"@header")
           (set @file (line substringFromIndex:(+ 1 ("@header" length)))))
          ((line beginsWithString:"@file")
           (set @file (line substringFromIndex:(+ 1 ("@file" length)))))
          ((line beginsWithString:"@copyright")
           (set @copyright (line substringFromIndex:(+ 1 ("@copyright" length)))))
          ((line beginsWithString:"@abstract")
           (set @abstract (line substringFromIndex:(+ 1 ("@abstract" length)))))
          ((line beginsWithString:"@info")
           (set @info (line substringFromIndex:(+ 1 ("@info" length)))))
          ((and (not @finished) (line beginsWithString:"@discussion"))
           (set @discussion (NSMutableString string))
           (@discussion appendString:(line substringFromIndex:(+ 1 ("@discussion" length)))))
          ((and (not @finished) (eq line "") (!= @discussion ""))
           (@discussion appendString:"<br/><br/>"))
          ((not @finished)
           (@discussion appendString:(NSString carriageReturn))
           (@discussion appendString:line))
          (else nil)))
 
 ;; Extract documentation from file comments.
 (- (void) parseFileComments is
    (set @discussion (NSMutableString string))
    (if @comments
        (if (set match (objc-comment-pattern findInString:@comments))
            (then
                 (set text (match groupAtIndex:1))
                 (set lines (text lines))
                 (lines each:
                        (do (original-line)
                            (set line (original-line strip))
                            (self parseFileCommentLine:line))))
            (else
                 (set lines (@comments lines))
                 (lines each:
                        (do (original-line)
                            (if (set match (nu-comment-pattern findInString:original-line))
                                (then
                                     (set line (match groupAtIndex:3))
                                     (self parseFileCommentLine:line)))))))))
 
 ;; Add a method description to a file's array of methods.
 (- (void) addMethod: (id) method is (@methods addObject:method))
 
 ;; Add a class description to a file's array of classes.
 (- (void) addClass: (id) class is (@classes addObject:class)))

;; Extract information from one line of class and method comments.
(macro parseClassAndMethodCommentLine ()
       `(progn
              (cond ((line beginsWithString:"@class")
                     (set @class (line substringFromIndex:(+ 1 ("@class" length)))))
                    ((line beginsWithString:"@category") ;; category is an alias for class
                     (set @class (line substringFromIndex:(+ 1 ("@category" length)))))
                    ((line beginsWithString:"@abstract")
                     (set @abstract (line substringFromIndex:(+ 1 ("@abstract" length)))))
                    ((line beginsWithString:"@method")
                     (set @method (line substringFromIndex:(+ 1 ("@method" length)))))
                    ((line beginsWithString:"@discussion")
                     (set @discussion (NSMutableString string))
                     (@discussion appendString:(line substringFromIndex:(+ 1 ("@discussion" length)))))
                    ((and (eq line "") (!= @discussion ""))
                     (@discussion appendString:"<br/><br/>"))
                    (else
                         (@discussion appendString:(NSString carriageReturn))
                         (@discussion appendString:line)))))

;; Extract documentation information from class and method comments.
(macro parseClassAndMethodComments ()
       `(progn
              (set @discussion (NSMutableString string))
              (if @comments
                  (if (set match (objc-comment-pattern findInString:@comments))
                      (then
                           ;(puts "parsing objc comment text for #{(if @name (then @name)(else @methodName))}")
                           (set text (match groupAtIndex:1))
                           (set lines (text lines))
                           (lines each:
                                  (do (original-line)
                                      (set line (original-line strip))
                                      (parseClassAndMethodCommentLine))))
                      (else
                           ;(puts "parsing nu comment text for #{(if @name (then @name)(else @methodName))}")
                           (set lines (@comments lines))
                           (lines each:
                                  (do (original-line)
                                      (if (set match (nu-comment-pattern findInString:original-line))
                                          (then
                                               (set line (match groupAtIndex:3))
                                               (parseClassAndMethodCommentLine))))))))))

;; @abstract NuDoc class for building class descriptions.
;; @discussion NuDoc creates one instance of this class for each class that it encounters when reading source files.
(class NuDocClassInfo is NSObject
 
 ;; Initialize a description for a named class.
 (- (id) initWithName:(id) name is
    (super init)
    (set @name name)
    (set @superClassName nil)
    (set @methods (NSMutableArray array))
    (set @files (NSMutableDictionary dictionary))
    self)
 
 ;; Generate a link to the html description of the class.
 (- (id) linkWithPrefix:(id) prefix is
    (&a href:(+ prefix (self name) ".html") @name))
 
 ;; Generate a link to the html description of the class' superclass.
 (- (id) linkToSuperClassWithPrefix:(id) prefix is
    (if (set superClassInfo ($classes objectForKey:@superClassName))
        (then (superClassInfo linkWithPrefix:prefix))
        (else @superClassName)))
 
 ;; Get an array of descriptions of a class' class methods.
 (- (id) classMethods is
    (@methods select:(do (method) (eq (method methodType) "+"))))
 
 ;; Get an array of descriptions of a class' instance methods.
 (- (id) instanceMethods is
    (@methods select:(do (method) (eq (method methodType) "-"))))
 
 ;; Set the raw comments associated with a class.
 (- (void) setComments:(id) comments is
    (set @comments comments)
    (parseClassAndMethodComments))
 
 ;; A sorted list of the names of files containing declarations of a class and its methods.
 (- (id) fileNames is ((@files allKeys) sort))
 
 ;; A list of the descriptions of files containing declarations of a class and its methods.
 (- (id) files is (@files allValues))
 
 ;; Add a file description to the class' list.
 (- (void) addFile:(id) file is
    (@files setObject:file forKey:(file name))))

(set method-table-template
     '(&table (if (and @selectors (@selectors count))
                  (then (@selectors mapWithIndex:
                                    (do (selector i)
                                        (if (eq i 0)
                                            (then (&tr (&td @methodType)
                                                       (&td @returnType)
                                                       (&td align:"right" (@selectors objectAtIndex:0))
                                                       (&td (@types objectAtIndex:0) " " (@names objectAtIndex:0))))
                                            (else (&tr (&td)
                                                       (&td colspan:"2" align:"right" selector)
                                                       (&td (@types objectAtIndex:i) " " (@names objectAtIndex:i))))))))
                  (else (&tr (&td @methodType)
                             (&td @returnType)
                             (&td @shortMethodName))))))


;; @abstract NuDoc class for building method descriptions.
;; @discussion NuDoc creates one instance of this class for each method implementation that it encounters when reading source files.
(class NuDocMethodInfo is NSObject
 
 ;; Initialize a method description from a Nu declaration.
 (- (id) initWithDeclaration:(id) declaration file:(id) file class:(id) classInfo is
    (super init)
    (set @file file)
    (set @classInfo classInfo)
    (set @methodType
         (case (declaration first)
               ('cmethod "+")
               ('imethod "-")
               ('+ "+")
               ('- "-")
               (else "?")))
    (set @comments (declaration comments))
    (parseClassAndMethodComments)
    (set @returnType (declaration second))
    (set @selectors nil)
    (cond ((eq 'is (declaration fourth))
           (set @methodName "#{((declaration second) stringValue)} #{((declaration third) stringValue)}")
           (set @shortMethodName "#{((declaration third) stringValue)}")) ; that's all
          (else
               (set cursor ((declaration cdr) cdr))
               (set @methodName ((declaration second) stringValue))
               (set @selectors ((NSMutableArray alloc) init))
               (set @types ((NSMutableArray alloc) init))
               (set @names ((NSMutableArray alloc) init))
               (while (!= (cursor car) 'is)
                      (@selectors addObject: ((cursor first) stringValue))
                      (@types addObject: ((cursor second) stringValue))
                      (@names addObject: ((cursor third) stringValue))
                      (set @methodName "#{@methodName} #{((cursor first) stringValue)} #{((cursor second) stringValue)} #{((cursor third) stringValue)}")
                      (set cursor (((cursor cdr) cdr) cdr)))
               (set @shortMethodName (@selectors componentsJoinedByString:""))
               ))
    self)
 
 ;; Initialize a method description from an Objective-C declaration.
 (- (id) initWithName:(id) name file:(id) file class:(id) classInfo is
    (super init)
    (set @file file)
    (set @classInfo classInfo)
    (set @methodType (name substringToIndex:1))
    (set @methodName (name substringFromIndex:2))
    (set @selectors nil)
    (cond ((set match (signature-pattern1 findInString:name))
           ;; ARITY 1+
           (set @returnType "(#{(match groupAtIndex:2)})")
           (set @selectors ((NSMutableArray alloc) init))
           (set @types ((NSMutableArray alloc) init))
           (set @names ((NSMutableArray alloc) init))
           (set nameToParse (match groupAtIndex:3))
           ((selector-pattern findAllInString:nameToParse) each:
            (do (match2)
                (@selectors addObject:(match2 groupAtIndex:1))
                (@types addObject:"(#{(match2 groupAtIndex:2)})")
                (@names addObject:(match2 groupAtIndex:3))))
           (set @shortMethodName (@selectors componentsJoinedByString:"")))
          
          ((set match (signature-pattern0 findInString:name))
           ;; ARITY 0
           (set @returnType "(#{(match groupAtIndex:2)})")
           (set @shortMethodName (match groupAtIndex:3)))
          (else (puts "error! can't parse selector #{name}")))
    self)
 
 ;; Generate a link to the html description of the method.
 (- (id) linkWithPrefix:(id) prefix is
    (&a href:(+ prefix ((self classInfo) name) ".html#" (self shortMethodName)) @methodType @shortMethodName))
 
 ;; Compare methods by name, allowing method descriptions to be sorted.
 (- (int) compare:(id) other is
    (@shortMethodName compare:(other shortMethodName)))
 
 ;; Generate an html table that prettily-prints the method selector.
 (- (id) tableDescription is
    (eval method-table-template))
 
 ;; Set the raw comments associatied with a method.
 (- (void) setComments:(id) comments is
    (set @comments comments)
    (parseClassAndMethodComments)))

;; extract documentation from nu source files
(function extract-nu (file)
          ;; is this really a Nu source file?
          (if (and (NSString stringWithShellCommand:(+ "head -1 " file " | grep '#!'"))
                   (not (NSString stringWithShellCommand:(+ "head -1 " file " | grep 'nush'"))))
              ;; apparently not.
              (puts "skipping #{file}")
              (return))
          (puts "extracting from #{file}")
          (set fileInfo (NuDocFileInfo infoForFileNamed:file))
          (set code (_parser parse:(NSString stringWithContentsOfFile:file)))
          ;; get file documentation from beginning of file
          (if ((code second) comments)
              (fileInfo setComments:((code second) comments)))
          ;; code is a progn
          ((code cdr) each: (do (statement)
                                (case (statement first)
                                      ('class
                                             (set className ((statement second) stringValue))
                                             
                                             (unless (set classInfo ($classes valueForKey:className))
                                                     (set classInfo ((NuDocClassInfo alloc) initWithName:className))
                                                     ($classes setValue:classInfo forKey:className))
                                             (classInfo addFile:fileInfo)
                                             (classInfo setComments: (statement comments))
                                             (fileInfo addClass:classInfo)
                                             
                                             (cond ((eq (statement third) 'is)
                                                    (set parentClassName (statement fourth))
                                                    (classInfo setSuperClassName: ((statement fourth) stringValue))
                                                    (set rest ((((statement cdr) cdr) cdr) cdr)))
                                                   (else
                                                        (set parentClassName nil)
                                                        (set rest ((statement cdr) cdr))))
                                             
                                             (rest each: (do (statement)
                                                             (if (or (eq (statement first) 'imethod)
                                                                     (eq (statement first) '-))
                                                                 (set methodInfo ((NuDocMethodInfo alloc) initWithDeclaration:statement file:fileInfo class:classInfo))
                                                                 ((classInfo methods) addObject:methodInfo)
                                                                 (fileInfo addMethod:methodInfo))
                                                             (if (or (eq (statement first) 'cmethod)
                                                                     (eq (statement first) '+))
                                                                 (set methodInfo ((NuDocMethodInfo alloc) initWithDeclaration:statement file:fileInfo class:classInfo))
                                                                 ((classInfo methods) addObject:methodInfo)
                                                                 (fileInfo addMethod:methodInfo)))))
                                      ('function ;; future work
                                                 (set functionname (statement second)))
                                      ('macro    ;; future work
                                                 (set macroname (statement second)))
                                      (else nil))))
          nil)

;; extract documentation from Objective-C source files
(function extract-objc (file)
          (puts "extracting from #{file}")
          (set fileInfo (NuDocFileInfo infoForFileNamed:file))
          (set code (NSString stringWithContentsOfFile:file))
          (set matches (NSMutableArray array))
          (matches addObjectsFromArray:(interface-pattern findAllInString:code))
          (matches addObjectsFromArray:(implementation-pattern findAllInString:code))
          (matches addObjectsFromArray:(protocol-pattern findAllInString:code))
          (matches addObjectsFromArray:(signature-pattern findAllInString:code))
          (matches addObjectsFromArray:(objc-comment-pattern findAllInString:code))
          (matches sortUsingSelector:"compare:")
          
          ;; get file documentation from beginning of file
          (if (and matches (matches count) (eq ((matches 0) regex) objc-comment-pattern))
              (fileInfo setComments:(((matches 0) groupAtIndex:0))))
          
          (set $comments "")
          (matches each:
                   (do (match)
                       (case (match regex)
                             (interface-pattern (set className (match groupAtIndex:1))
                                                (unless (set $classInfo ($classes valueForKey:className))
                                                        (set $classInfo ((NuDocClassInfo alloc) initWithName:className))
                                                        ($classes setValue:$classInfo forKey:className))
                                                ($classInfo addFile:fileInfo)
                                                ($classInfo setComments:$comments)
                                                ($classInfo setSuperClassName:(match groupAtIndex:3))
                                                (fileInfo addClass:$classInfo)
                                                (set $comments ""))
                             (signature-pattern (set methodName (match groupAtIndex:0))
                                                (set methodInfo ((NuDocMethodInfo alloc) initWithName:methodName file:fileInfo class:$classInfo))
                                                (($classInfo methods) addObject:methodInfo)
                                                (methodInfo setComments:$comments)
                                                (fileInfo addMethod:methodInfo)
                                                (set $comments ""))
                             (objc-comment-pattern (set $comments "#{(match groupAtIndex:0)}"))
                             (else nil)))))

;;;;;;;;;;;;; Header ;;;;;;;;;;;;;;;;;
(macro site-header ()
       `(progn
              (if (eq $sitename "programming.nu")
                  (then (+
                          (&div style:"float:left; margin-right:10px"
                                (&img src:"/files/recycle-s.png" height:"50"))
                          (&div (&h1 (&a href:"/" "Programming Nu"))
                                (&h3 "Website for the Nu programming language."))))
                  (else ""))))

;;;;;;;;;;;;; Footer Template ;;;;;;;;;;;;;;;;;
(set footer-template
     '(&div class:"footer"
            (&center (&font size:"-2"
                            (&div style:"float:left; margin-left:10px" "Documentation by NuDoc")
                            (&div style:"float:right; margin-right:10px" "Updated " ((NSDate date) descriptionForDocumentation))
                            (if (eq $sitename "programming.nu")
                                (&a href:"http://radtastical.com" "&copy; 2007-2013, Radtastical Inc."))))))

;;;;;;;;;;;;; Index Template ;;;;;;;;;;;;;;;;;
(set index-template
     '(&html (&head (&link media:"all" href:(if (eq $sitename "programming.nu") (then "/stylesheets/nu.css") (else "doc.css")) type:"text/css" rel:"stylesheet"))
             (&body (&div id:"container"
                          (&div id:"header"
                                (site-header))
                          (&div id:"content"
                                (&h1 (&a href:"./index.html" $project " Class Reference"))
                                $introduction
                                (&div style:"float:left"
                                      (&h2 "Classes")
                                      (&ul ((($classes allKeys) sort) map:
                                            (do (className)
                                                (if (($classes objectForKey:className) superClassName)
                                                    (then (&li (&a href:(+ "classes/" className ".html") className)))
                                                    (else ""))))))
                                (&div style:"float:left"
                                      (&h2 "Extensions")
                                      (&ul ((($classes allKeys) sort) map:
                                            (do (className)
                                                (set classInfo2 ($classes objectForKey:className))
                                                (unless (classInfo2 superClassName)
                                                        (then (&li (&a href:(+ "classes/" className ".html") className)))
                                                        (else "")))))))
                          (&div id:"sidebar"
                                (&h2 "Source Files")
                                (&ul ((($files allKeys) sort) map:
                                      (do (fileName)
                                          (set fileInfo2 ($files objectForKey:fileName))
                                          (&li (&a href:(+ "files/" (fileInfo2 niceName) ".html") fileName))))))
                          (&br style:"clear:both")
                          $footer))))

;;;;;;;;;;;;; Stylesheet ;;;;;;;;;;;;;;;;;
(set stylesheet <<-END
body {
	margin: 0;
	padding: 0;
	font: normal 14px "lucida grande", verdana, arial, helvetica, sans-serif;
	line-height: 150%;
}

#container {
	width: 800px;
	margin: 10px auto;
	padding: 0;
}

#header {
    width: 750px;
	margin: 0;
	padding: 0px 25px 0px 25px;
}

#content {
	width: 515px;
	padding: 0px 25px 0px 25px;
	margin: 0;
	float: left;
}

#sidebar {
    padding-top: 20px;
	padding-bottom: 10px;
	width: 215px;
	margin-top:0px;
	margin-left:565px;
	padding-right:20px;
	padding-left:20px;
	line-height: 130%;
	font-size: 90%;
}

code {
	font-size: 12px;
}

a:link, a:visited {
	color: #101010;
	text-decoration: none;
}

a:hover, a:active {
	color: #505050;
	text-decoration: underline;
}

li {
	list-style:none;
	padding-left: 1em;
}

ul {
	padding:0;
	margin:0;
}

table {
	font-weight: bold;
}

.method {
	background:#eee;
	margin:20px 0;	
	padding:5px;
}
END)

;;;;;;;;;;;;; Class Description Template ;;;;;;;;;;;;;;;;;
(set classinfo-template
     '(&html (&head (&link media:"all" href:(if (eq $sitename "programming.nu") (then "/stylesheets/nu.css") (else "../doc.css")) type:"text/css" rel:"stylesheet"))
             (&body (&div id:"container"
                          (&div id:"header" (site-header))
                          (&div id:"content"
                                (&h1 (&a href:"../index.html") $project " Class Reference")
                                (&h2 (classInfo name)
                                     (if (classInfo superClassName) (then "") (else " Extensions")))
                                (if (classInfo valueForIvar:"abstract") (&p (classInfo valueForIvar:"abstract")))
                                (&p (if (classInfo superClassName)
                                        (&b "Superclass: " (classInfo linkToSuperClassWithPrefix:"../classes/") (&br)))
                                    (&b "Declared in: " (((classInfo files) map:(do (file) (file linkWithPrefix:"../files/"))) componentsJoinedByString:", ")))
                                (if (!= "" (classInfo discussion))
                                    (classInfo discussion))
                                (&h3 "Methods")
                                (&font size:"-1"
                                       (&ul
                                           (set classMethods ((classInfo classMethods) sort))
                                           (if (classMethods count)
                                               (classMethods map:
                                                             (do (methodInfo)
                                                                 (&li (&a href:(+ "#" (methodInfo shortMethodName)) (&tt "+ " (methodInfo shortMethodName)))))))
                                           (set instanceMethods ((classInfo instanceMethods) sort))
                                           (if (instanceMethods count)
                                               (instanceMethods map:
                                                                (do (methodInfo)
                                                                    (&li (&a href:(+ "#" (methodInfo shortMethodName)) (&tt "- " (methodInfo shortMethodName)))))))))
                                (set classMethods ((classInfo classMethods) sort))
                                (classMethods map:
                                              (do (methodInfo)
                                                  (&div class:"method"
                                                        (&a name:(methodInfo shortMethodName)
                                                            (methodInfo tableDescription))
                                                        (methodInfo discussion)
                                                        (&p align:"right" style:"margin-bottom:0" "in " ((methodInfo file) linkWithPrefix:"../files/")))))
                                (set instanceMethods ((classInfo instanceMethods) sort))
                                (instanceMethods map:
                                                 (do (methodInfo)
                                                     (&div class:"method"
                                                           (&a name:(methodInfo shortMethodName)
                                                               (methodInfo tableDescription))
                                                           (methodInfo discussion)
                                                           (&p align:"right" style:"margin-bottom:0" "in " ((methodInfo file) linkWithPrefix:"../files/"))))))
                          
                          (&div id:"sidebar"
                                (&h2 "Classes")
                                (&ul ((($classes allKeys) sort) map:
                                      (do (className)
                                          (set classInfo2 ($classes objectForKey:className))
                                          (if (classInfo2 superClassName)
                                              (then (&li (&a href:(+ className "html") className)))
                                              (else "")))))
                                (&h2 "Extensions")
                                (&ul ((($classes allKeys) sort) map:
                                      (do (className)
                                          (set classInfo2 ($classes objectForKey:className))
                                          (unless (classInfo2 superClassName)
                                                  (then (&li (&a href:(+ className "html") className)))
                                                  (else ""))))))
                          (&br style:"clear:both"
                               $footer)))))

;;;;;;;;;;;;; File Description Template ;;;;;;;;;;;;;;;;;
(set fileinfo-template
     '(&html (&head (&link media:"all" href:(if (eq $sitename "programming.nu") (then "/stylesheets/nu.css") (else "../doc.css")) type:"text/css" rel:"stylesheet"))
             (&body (&div id:"container"
                          (&div id:"header" (site-header))
                          (&div id:"content"
                                (&h1 (&a href:"../index.html" $project " Class Reference"))
                                (&h2 (fileInfo name))
                                (if (!= "" (fileInfo discussion)) (then (fileInfo discussion)) (else ""))
                                (&h2 "Class Declarations")
                                (if ((fileInfo classes) count)
                                    (then ((fileInfo classes) map:
                                           (do (classInfo)
                                               (&div
                                                    (&h3 (classInfo linkWithPrefix:"../classes/"))
                                                    (&ul ((fileInfo methods) map:
                                                          (do (methodInfo)
                                                              (if (eq classInfo (methodInfo classInfo))
                                                                  (then (&li (methodInfo linkWithPrefix:"../classes/")))
                                                                  (else "")))))))))
                                    (else (&p "none."))))
                          (&div id:"sidebar"
                                (&h2 "Source Files")
                                (&ul ((($files allKeys) sort) map:
                                      (do (fileName)
                                          (set fileInfo2 ($files objectForKey:fileName))
                                          (&li (&a href:(+ "../files/" (fileInfo2 niceName) ".html") fileName))))))
                          (&br style:"clear:both")
                          $footer))))

;;
;; Main program starts here
;;
(macro nudoc ()
       `(progn
              (set $classes (dict))
              (set $files (dict))
              (puts "Reading Source Files")
              
              (set nu-files (filelist "^nu/.*\.nu$"))
              (nu-files each:(do (file) (extract-nu file)))
              
              (set tool-files (filelist "^tools/[^/\.]+$"))
              (tool-files each:(do (file) (extract-nu file)))
              
              (set objc-files (filelist "^objc/.*\.[h]$"))
              (objc-files each:(do (file) (extract-objc file)))
              
              (puts "Generating Documentation")
              
              (set $project (((((NSString stringWithShellCommand:"pwd") lines) 0) componentsSeparatedByString:"/") lastObject))
              
              (set $introduction (&p "Here are descriptions of the classes and methods used to implement "
                                     $project
                                     ". These descriptions were automatically extracted from the "
                                     $project " source code using nudoc."))
              
              (set $footer (eval footer-template))
              
              (system "mkdir -p doc")
              (system "mkdir -p doc/classes")
              (system "mkdir -p doc/files")
              
              (stylesheet writeToFile:"doc/doc.css")
              ((eval index-template) writeToFile:"doc/index.html")
              
              (($classes allValues) each:
               (do (classInfo)
                   ((eval classinfo-template) writeToFile:"doc/classes/#{(classInfo name)}.html")))
              
              (($files allValues) each:
               (do (fileInfo)
                   ((eval fileinfo-template) writeToFile:"doc/files/#{(fileInfo niceName)}.html")))))
