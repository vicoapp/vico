#!/usr/bin/env python

import sys
import os
import re
from texMate import expandName, findTexPackages, find_TEX_directives, findFileToTypeset
import cPickle
import time

# PyTeXDoc
# Author:  Brad Miller
# Last Update: 12/27/2006	-- try to make command compatible with multiple tex distros
#              3/4/2007		-- removed colours from stylesheet (and added underlines) to
#								avoid problems with dark themes
# This script is a hacked together set of heuristics to try and bring some
# order out of the various bits and pieces of documentation that are strewn 
# around any given LaTeX distro.
# texdoctk provides a nice list of packages, along with paths to the documents
# that are relative to one or more roots.  The root for these documents varies.
# the catalogue/entries directory contains a set of html files for packages from
# CPAN....  Sometimes the links to the real documentation are inside these html
# files and are correct and sometimes they are not.
# So this script attempts to use find the right path to as many bits of documentation
# that really exist on your system and make it easy for you to get to them.
# The packages are displayed in two groups:
# The first group is the set of packages that you use in your document.
# The second group is the set of packages as organized in the texdoctk.dat file (if you have one)
# Finally, if you call the command when your curosor is on a word in TextMate this script will
# attempt to find the best match for that word as a package and open the documentaiton for that
# package immediately.
#
# because good dvi viewers are quite rare on OS X, I also provide a simple viewDoc.sh script. 
# viewDoc.sh converts a dvi file (using dvipdfm) and opens it in Previewer.

#TODO make the viewing command configurable
#TODO: modify this script to produce opml
#TODO: See if there is a way to simplify all this....

pathDict = {}
descDict = {}
headings = {}

def findBestDoc(myDir):
    """findBestDoc
       Given a directory that should contain documentation find the best format
       of the documentation available.  peferring pdf, then dvi files.
    """
    bestDoc = ""
    for doc in os.listdir(myDir):
        if doc.find('.pdf') > 0:
            bestDoc = doc
        elif bestDoc == "" and doc.find('.dvi') > 0:
            bestDoc = doc
        elif bestDoc == "" and doc.find('.txt') > 0:
            bestDoc = doc
        elif bestDoc == "" and doc.find('.tex') > 0:
            bestDoc = doc
        elif bestDoc == "" and doc.find('.sty') > 0:
            bestDoc = doc
        elif bestDoc == "" and doc.find('README') >= 0:
            bestDoc = doc
    return myDir + '/' + bestDoc


def makeDocList():
    """getDocList
       search all directories under the texmf root for dvi or pdf files that
       might be documentation...
    """
    docDict = {}
    dviPipe = os.popen("find `kpsewhich --expand-path '$TEXMF'  | tr : ' '` -name \*.dvi")
    dviFiles = dviPipe.readlines()
    pdfPipe = os.popen("find `kpsewhich --expand-path '$TEXMF'  | tr : ' '` -name \*.pdf")
    pdfFiles = pdfPipe.readlines()
    for doc in dviFiles:
        key = doc[doc.rfind('/')+1:doc.rfind('.dvi')]
        docDict[key] = doc[:-1]
    for doc in pdfFiles:
        key = doc[doc.rfind('/')+1:doc.rfind('.pdf')]
        docDict[key] = doc[:-1]
    return docDict

## Part 1
## Find all the packages included in this file or its inputs
##
tsDirs = find_TEX_directives()
fileName,filePath = findFileToTypeset(tsDirs)
mList = findTexPackages(fileName)

home = os.environ["HOME"]
docdbpath = home + "/Library/Caches/TextMate"
docdbfile = docdbpath + "/latexdocindex"
ninty_days_ago = time.time() - (90 * 86400)
cachedIndex = False

if os.path.exists(docdbfile) and os.path.getmtime(docdbfile) > ninty_days_ago:
    infile = open(docdbfile,'rb')
    path_desc_list = cPickle.load(infile)
    pathDict = path_desc_list[0]
    descDict = path_desc_list[1]    
    headings = path_desc_list[2] 
    cachedIndex = True
else:
    ## Part 2
    ## Parse the texdoctk database of packages
    ##
    texMFbase = os.environ["TM_LATEX_DOCBASE"]
    docIndex = os.environ["TEXDOCTKDB"]

    docBase = texMFbase + "/" #+ "doc/"
    if docBase[-5:].rfind('doc') < 0:
        docBase = docBase + "doc/"

    catalogDir = os.environ["TM_LATEX_HELP_CATALOG"]

    texdocs = os.environ["TMTEXDOCDIRS"].split(':')
    myDict = {}
    for p in texdocs:
        key = p[p.rfind('/')+1:]
        myDict[key] = p

    docDict = makeDocList()

    try:
        docIndexFile = open(docIndex,'r')
    except:
        docIndexFile = []
    for line in docIndexFile:
        if line[0] == "#":
            continue
        elif line[0] == "@":
            currentHeading = line[1:].strip()
            headings[currentHeading] = []
        else:
            try:
                lineFields = line.split(';')
                key = lineFields[0]
                desc = lineFields[1]
                path = lineFields[2]
            except:
                print "Error parsing line: ", line
            
            headings[currentHeading].append(key)
            if path.rfind('.sty') >= 0:
                path = docBase + "tex/" + path
            else:
                path = docBase + path
                if not os.path.exists(path):  # sometimes texdoctk.dat is misleading...
                    altkey = path[path.rfind("/")+1:path.rfind(".")]
                    if key in docDict:
                        path = docDict[key]
                    elif altkey in docDict:
                        path = docDict[altkey]
                    else:
                        if key in myDict:
                            path = findBestDoc(myDict[key])
                    
            pathDict[key] = path.strip()
            descDict[key] = desc.strip()

    ## Part 3
    ## supplement texdoctk index with the regular texdoc catalog
    ##
    try:
        catList = os.listdir(catalogDir)
    except:
        catList = []
    for fname in catList:
        key = fname[:fname.rfind('.html')]
        if key not in pathDict:
            pathDict[key] = catalogDir + '/' + fname
            descDict[key] = key
            if key in docDict:
                pathDict[key] = docDict[key]
    ##
    ## Continue to supplement with searched for files
    ##
    for p in docDict.keys()+myDict.keys():
        if p not in pathDict:
            if p in docDict:
                pathDict[p] = docDict[p].strip()
                descDict[p] = p
            else:
                if p in myDict:
                    path = findBestDoc(myDict[p])
                    pathDict[p] = path.strip()
                    descDict[p] = p

    try:
        if not os.path.exists(docdbpath):
            os.mkdir(docdbpath)
        outfile = open(docdbfile, 'wb')                
        cPickle.dump([pathDict,descDict,headings],outfile)
    except:
        print "<p>Error: Could not cache documentation index</p>"

## Part 4
## if a word was selected then view the documentation for that word
## using the best available version of the doc as determined above
##
cwPackage = os.environ.get("TM_CURRENT_WORD",None)
if cwPackage in pathDict:
    os.system("viewDoc.sh " + pathDict[cwPackage])
    sys.exit()

## Part 5
## Print out the results in html/javascript
## The java script gives us the nifty expand collapse outline look
##
print """
<style type="text/css"><!--
.save{
   behavior:url(#default#savehistory);}
a.dsphead{
   text-decoration:none;
   font-family: "Lucida Grand", sans-serif
   font-size: 120%;
   font-weight: bold;
   margin-left:0.5em;}
a.dsphead:hover{
   text-decoration:underline;}
.dspcont{
   display:none;
   text-decoration:none;
   font-family: "Bitstream Vera Sans Mono", "Monaco", monospace;
   margin: 0px 20px 0px 20px;} 
.dspcont a{
    text-decoration: none;
} 
.dspcont a:hover{
    text-decoration:underline;
}
div#mypkg{
   text-decoration:none;
   font-family: "Bitstream Vera Sans Mono", "Monaco", monospace;
}
div#mypkg a{
   text-decoration:none;
   font-family: "Bitstream Vera Sans Mono", "Monaco", monospace;
}
div#mypkg a:hover{
   text-decoration:none;
}

//--></style>


<script type="text/javascript"><!--
function dsp(loc){
   if(document.getElementById){
      foc=loc.parentNode.nextSibling.style?
         loc.parentNode.nextSibling:
         loc.parentNode.nextSibling.nextSibling;
      foc.style.display=foc.style.display=='block'?'none':'block';}}  

//-->
</script>
"""    
print "<h1>Your Packages</h1>"
print "<ul>"
for p in mList:
    print '<div id="mypkg">'
    if p in pathDict:
        print """<li><a href="javascript:TextMate.system('viewDoc.sh %s', null);" >%s</a>
             </li> """%(pathDict[p],descDict[p])
    else:
        print """<li>%s</li>"""%(p)
    print '</div>'
print "</ul>"

print "<hr />"
print "<h1>Packages Browser</h1>"
print "<ul>"
for h in headings:
    print '<li><a href="javascript:dsp(this)" class="dsphead" onclick="dsp(this)">%s</a></li>'%(h)
    print '<div class="dspcont">'
    print "<ul>"
    for p in headings[h]:
        if os.path.exists(pathDict[p]):
            print """<li><a href="javascript:TextMate.system('viewDoc.sh %s', null);">%s</a>
                </li> """%(pathDict[p],descDict[p])
        else:
            print """<li>%s</li>"""%(p)
    print "</ul>"
    print '</div>'
print "</ul>"
if cachedIndex:
    print "<p>You are using a saved version of the LaTeX documentation index.  This index is automatically updated every 90 days.  If you want to force an update simply remove the file %s </p>" % docdbfile
