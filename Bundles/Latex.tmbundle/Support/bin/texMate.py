#!/usr/bin/env python -u
# encoding: utf-8

# This is a rewrite of latexErrWarn.py
# Goals:
#   1.  Modularize the processing of a latex run to better capture and parse errors
#   2.  replace latexmk
#   3.  provide a nice pushbutton interface for manually running latex,bibtex,mkindex, and viewing
#   
# Overview:
#    Each tex command has its own class that parses the output from that program.  Each of these classes
#    extends the TexParser class which provides default methods:
#       parseStream
#       error
#       warning
#       info
#   The parseStream method reads each line from the input stream matches against a set of regular
#   expressions defined in the patterns dictionary.  If one of these patterns matches then the 
#   corresponding method is called.  This method is also stored in the dictionary.  Pattern matching
#   callback methods must each take the match object as well as the current line as a parameter.
#
#   To enable debug mode without modifiying this file:
#                 defaults write com.macromates.textmate latexDebug 1
#
#   Progress:
#       7/17/07  -- Brad Miller
#       Implemented  TexParse, BibTexParser, and LaTexParser classes
#       see the TODO's sprinkled in the code below
#       7/24/07  -- Brad Miller
#       Spiffy new configuration window added
#       pushbutton interface at the end of the latex output is added
#       the confusing mass of code that was Typeset & View has been replaced by this one
#
#   Future:
# 
#       think about replacing latexmk.pl with a simpler python version.  If only rubber worked reliably..
#

import sys
import re
from os.path import basename
import os
import tmprefs
from urllib import quote
from struct import *
from texparser import *

DEBUG = False

try:
    from subprocess import *
except:
    if DEBUG:
        print "Using Tiger Compatibility version of Popen class"
    PIPE = 1
    STDOUT=1
    class Popen(object):
        """Popen:  This class provides backward compatibility for Tiger
           Do not assume anything about this works other than access
           to stdout and the wait method."""
        def __init__(self, command, **kwargs):
            super(Popen, self).__init__()
            self.command = command
            stdin, self.stdout = os.popen4(command)
        
        def wait(self):
            stat = self.stdout.close()
            return stat

texMateVersion = ' $Rev: 10791 $ '

# 

TM_BUNDLE_SUPPORT = os.getenv("TM_BUNDLE_SUPPORT").replace(" ", "\\ ")
TM_SUPPORT_PATH = os.getenv("TM_SUPPORT_PATH").replace(" ", "\\ ")

def expandName(fn,program='pdflatex'):
    sys.stdout.flush()
    runObj = Popen('kpsewhich -progname="%s" "%s"' % (program, fn),shell=True,stdout=PIPE)
    res = runObj.stdout.read().strip()
    return res

def run_bibtex(bibfile=None,verbose=False,texfile=None):
    """Determine Targets and run bibtex"""
    # find all the aux files.
    fatal,err,warn = 0,0,0
    auxfiles = []
    if texfile:
        basename = texfile[:texfile.rfind('.')]
    if bibfile == None:
        auxfiles = [f for f in os.listdir('.') if re.search('.aux$',f) > 0]
        auxfiles = [f for f in auxfiles if re.match(r'('+ basename +r'\.aux|bu\d+\.aux)',f)]
    else:
        auxfiles = [bibfile]
    for bib in auxfiles:
        print '<h4>Processing: %s </h4>' % bib
        runObj = Popen('bibtex'+" "+shell_quote(bib),shell=True,stdout=PIPE,stdin=PIPE,stderr=STDOUT,close_fds=True)
        bp = BibTexParser(runObj.stdout,verbose)
        f,e,w = bp.parseStream()
        fatal|=f
        err+=e
        warn+=w
        stat = runObj.wait()
    return stat,fatal,err,warn
        
def run_latex(ltxcmd,texfile,verbose=False):
    """Run the flavor of latex specified by ltxcmd on texfile"""
    global numRuns
    if DEBUG:
        print "<pre>in run_latex: ", ltxcmd+" "+shell_quote(texfile), "</pre>"
    runObj = Popen(ltxcmd+" "+shell_quote(texfile),shell=True,stdout=PIPE,stdin=PIPE,stderr=STDOUT,close_fds=True)
    lp = LaTexParser(runObj.stdout,verbose,texfile)
    f,e,w = lp.parseStream()
    stat = runObj.wait()
    numRuns += 1
    return stat,f,e,w

def run_makeindex(fileName,idxfile=None):
    ## TODO foreach \makeindex[(.*)] run makeindex on $1, plus the master file.
    """Run the makeindex command"""
    try:
        texString = open(fileName).read()
    except:
        print '<p class="error">Error: Could not open %s to check for makeindex</p>' % fileName
        print '<p class="error">This is most likely a problem with TM_LATEX_MASTER</p>'
        sys.exit(1)
    myList = [x[2] for x in re.findall(r'([^%]|^)\\makeindex(\[([\w]+)\])?',texString) if x[2] ]
    
    fileNoSuffix = getFileNameWithoutExtension(fileName)
    idxFile = fileNoSuffix+'.idx'
    myList.append(idxFile)
    fatal, error, warning = 0,0,0
    for idxFile in myList:
        runObj = Popen('makeindex '+idxFile,shell=True,stdout=PIPE,stdin=PIPE,stderr=STDOUT,close_fds=True)        
        ip = TexParser(runObj.stdout,True)
        f,e,w = ip.parseStream()
        fatal |= f
        error += e
        warning += w
        stat = runObj.wait()
    return stat,fatal,error,warning

def findViewerPath(viewer,pdfFile,fileName):
    """Use the find_app command to ensure that the viewer is installed in the system
       For apps that support pdfsync search in pdf set up the command to go to the part of
       the page in the document the user was writing."""
    runObj = Popen(TM_SUPPORT_PATH + '/bin/find_app ' + viewer + '.app',stdout=PIPE,shell=True)
    vp = runObj.stdout.read()
    syncPath = None
    if viewer == 'Skim' and vp:
        syncPath = vp + '/Contents/SharedSupport/displayline ' + os.getenv('TM_LINE_NUMBER') + ' ' + pdfFile + ' ' + shell_quote(os.getenv('TM_FILEPATH'))
    elif viewer == 'TeXniscope' and vp:
        syncPath = vp + '/Contents/Resources/forward-search.sh ' + os.getenv('TM_LINE_NUMBER') + ' ' + shell_quote(os.getenv('TM_FILEPATH')) + ' ' + pdfFile
    elif viewer == 'PDFView' and vp:
        syncPath = '/Contents/MacOS/gotoline.sh ' + os.getenv('TM_LINE_NUMBER') + ' ' + pdfFile
    if DEBUG:
        print "VP = ", vp
        print "syncPath = ", syncPath
    return vp, syncPath

def refreshViewer(viewer,pdfPath):
    """Use Applescript to tell the viewer to reload"""
    print '<p class="info">Telling %s to Refresh %s...</p>'%(viewer,pdfPath)
    if viewer == 'Skim':
        os.system("/usr/bin/osascript -e " + """'tell application "Skim" to revert (documents whose path is %s)' """%pdfPath)
    elif viewer == 'TeXniscope':
        os.system("/usr/bin/osascript -e " + """'tell application "TeXniscope" to tell documents whose path is %s to refresh' """%pdfPath)
    elif viewer == 'TeXShop':
        os.system("/usr/bin/osascript -e " + """'tell application "TeXShop" to tell documents whose path is %s to refreshpdf' """%pdfPath)

# TODO refactor run_viewer and sync_viewer to work together better
def sync_viewer(viewer,fileName,filePath):
    fileNoSuffix = getFileNameWithoutExtension(fileName)
    pdfFile = shell_quote(fileNoSuffix+'.pdf')
    cmdPath,syncPath = findViewerPath(viewer,pdfFile,fileName)
    if syncPath:
        stat = os.system(syncPath)
    else:
        print 'pdfsync is not supported for this viewer'
    return stat
    
def run_viewer(viewer,fileName,filePath,force,usePdfSync=True):
    """If the viewer is textmate, then setup the proper urls and/or redirects to show the
       pdf file in the html output window.
       If the viewer is an external viewer then ensure that it is installed and display the pdf"""
    stat = 0
    fileNoSuffix = getFileNameWithoutExtension(fileName)
    pathNoSuffix = filePath +'/'+ fileNoSuffix
    if viewer != 'TextMate':
        pdfFile = shell_quote(fileNoSuffix+'.pdf')
        pdfPath = shell_quote(pathNoSuffix+'.pdf')
        cmdPath,syncPath = findViewerPath(viewer,pdfFile,fileName)
        if cmdPath:
            viewer = viewer.encode('utf-8') # if this is not done, the next line will thrown an encoding exception when the pdfFile contains non-ASCII. Is this a Python bug?
            stat = os.system(TM_BUNDLE_SUPPORT+"/bin/check_open %s %s"%(viewer,pdfPath))
            if stat != 0:
                viewCmd = '/usr/bin/open -a ' + viewer + '.app ' + pdfPath
                stat = os.system(viewCmd)
            else:
                refreshViewer(viewer,pdfPath)            
        else:
            print '<strong class="error">', viewer, ' does not appear to be installed on your system.</strong>'
        if syncPath and usePdfSync:
            os.system(syncPath)
        elif not syncPath and usePdfSync:
            print 'pdfsync is not supported for this viewer'


    else:
        pdfFile = fileNoSuffix+'.pdf'
        tmHref = '<p><a href="tm-file://'+quote(filePath+'/'+pdfFile)+'">Click Here to View</a></p>'
        if (numErrs < 1 and numWarns < 1) or (numErrs < 1 and numWarns > 0 and not force):
            print '<script type="text/javascript">'
            print 'window.location="tm-file://'+quote(filePath+'/'+pdfFile)+'"'
            print '</script>'
    return stat

def determine_ts_directory(tsDirectives):
    """Determine the proper directory to use for typesetting the current document"""
    master = os.getenv('TM_LATEX_MASTER')
    texfile = os.getenv('TM_FILEPATH')
    startDir = os.path.dirname(texfile)

    if 'root' in tsDirectives:
        masterPath = os.path.dirname(os.path.normpath(tsDirectives['root']))
        return masterPath
    if master:
        masterPath = os.path.dirname(master)
        if masterPath == '' or masterPath[0] != '/':
            masterPath = os.path.normpath(os.path.join(startDir,masterPath))
    else:
        masterPath = startDir
    if DEBUG:
        print '<pre>Typesetting Directory = ', masterPath, '</pre>'
    return masterPath

def findTexPackages(fileName):
    """Find all packages included by the master file.
       or any file included from the master.  We should not have to go
       more than one level deep for preamble stuff.
    """
    try:
        realfn = expandName(fileName)
        texString = open(realfn)
    except:
        print '<p class="error">Error: Could not open %s to check for packages</p>' % realfn
        print '<p class="error">This is most likely a problem with TM_LATEX_MASTER</p>'
        sys.exit(1)

        
    inputre = re.compile(r'((^|\n)[^%]*?)(\\input|\\include)\{([\w /\.\-]+)\}')
    usepkgre = re.compile(r'((^|\n)[^%]*?)\\usepackage(\[[\w, \-]+\])?\{([\w,\-]+)\}')
                         #r'((^|\n)[^%]*?)\\usepackage(\[[\w, \-]+\])?\{([\w,\-]+)\}'
    beginre = re.compile(r'((^|\n)[^%]*?)\\begin\{document\}')
    incFiles = []
    myList = []
    for line in texString:
        begin = re.search(beginre,line)
        inc = re.search(inputre,line)
        usepkg = re.search(usepkgre,line)
        if begin:
            break
        elif inc:
            incFiles.append(inc.group(4))
        elif usepkg:
            myList.append(usepkg.group(4))
    #incFiles = [x[3] for x in re.findall(inputre,texString)]
    #myList = [x[3] for x in re.findall(usepkgre,texString)]
    beginFound = False
    for ifile in incFiles:
        if ifile.find('.tex') < 0:
            ifile += '.tex'
        try:
            realif = expandName(ifile)
            incmatches = []
            for line in file(realif):
                incmatches.append(re.search(usepkgre,line))
                if re.search(beginre,line):
                    beginFound = True
#            incmatches = [re.search(usepkgre,line) for line in file(realif)] 
            myList += [x.group(4) for x in incmatches if x]
        except:
            print '<p class="warning">Warning: Could not open %s to check for packages</p>' % ifile
        if beginFound:
            break
    newList = []
    for pkg in myList:
        if pkg.find(',') >= 0:
            for sp in pkg.split(','):
                newList.append(sp.strip())
        else:
            newList.append(pkg.strip())
    if DEBUG:
        print '<pre>TEX package list = ', newList, '</pre>'
    return newList

def find_TEX_directives():
    """build a dictionary of %!TEX directives
       the main ones we are concerned with are
       root : which specifies a root file to run tex on for this subsidiary
       TS-program : which tells us which latex program to run
       TS-options : options to pass to TS-program
       encoding  :  file encoding
       """
    texfile = os.getenv('TM_FILEPATH')
    startDir = os.path.dirname(texfile)
    done = False    
    tsDirectives = {}
    rootChain = [texfile]
    while not done:
        f = open(texfile)
        foundNewRoot = False
        for i in range(20):
            line = f.readline()
            m =  re.match(r'^%!TEX\s+([\w-]+)\s?=\s?(.*)',line)
            if m:
                if m.group(1) == 'root':
                    foundNewRoot = True
                    if m.group(2)[0] == '/':
                        newtf = m.group(2).rstrip()
                    else:                           # new root is relative or in same directory
                        newtf = os.path.realpath(os.path.join(startDir,m.group(2).rstrip()))
                    if newtf in rootChain:
                        print "<p class='error'> There is a loop in your '%!TEX root =' directives.</p>"
                        print "<p class='error'> chain = ",rootChain, "</p>"
                        print "<p class='error'> exiting.</p>"                        
                        sys.exit(-1)
                    else:
                        texfile = newtf
                        rootChain.append(newtf)
                    startDir = os.path.dirname(texfile)
                    tsDirectives['root'] = texfile
                else:
                    tsDirectives[m.group(1)] = m.group(2).rstrip()
        f.close()
        if foundNewRoot == False:
            done = True
    if DEBUG:
        print '<pre>%!TEX Directives: ', tsDirectives, '</pre>'
    return tsDirectives

def findFileToTypeset(tsDirectives):
    """determine which file to typeset.  Using the following rules:
       + %!TEX root directive
       + using the TM_LATEX_MASTER environment variable
       + Using TM_FILEPATH
       Once the file is decided return the name of the file and the normalized absolute path to the
       file as a tuple.
    """
    if  'root' in tsDirectives:
        f = tsDirectives['root']
    elif os.getenv('TM_LATEX_MASTER'):
        f = os.getenv('TM_LATEX_MASTER')
    else:
        f = os.getenv('TM_FILEPATH')
    master = os.path.basename(f)
    if DEBUG:
        print '<pre>master file = ', master, '</pre>'
    return master,determine_ts_directory(tsDirectives)

def constructEngineOptions(tsDirectives,tmPrefs):
    """Construct a string of command line options to pass to the typesetting engine
    Options can come from:
    +  %!TEX TS-options directive in the file
    + Preferences
    In any case nonstopmode is set as is file-line-error-style.
    """
    opts = "-interaction=nonstopmode -file-line-error-style"
    if synctex:
        opts += " -synctex=1 "
    if 'TS-options' in tsDirectives:
        opts += " " + tsDirectives['TS-options']
    else:
        opts += " " + tmPrefs['latexEngineOptions']
    if DEBUG:
        print '<pre>Engine options = ', opts, '</pre>'
    return opts

def usesOnePackage(testPack, allPackages):
    for p in testPack:
        if p in allPackages:
            return True
    return False

def constructEngineCommand(tsDirectives,tmPrefs,packages):
    """This function decides which engine to run using 
       + %!TEX directives from the tex file
       + Preferences
       + or by detecting certain packages
       The default is pdflatex.  But it may be modified
       to be one of
          latex
          xelatex
          texexec  -- although I'm not sure how compatible context is with any of this
    """
    engine = "pdflatex"

    latexIndicators = ['pstricks' , 'xyling' , 'pst-asr' , 'OTtablx' , 'epsfig' ]
    xelatexIndicators = ['xunicode', 'fontspec']

    if 'TS-program' in tsDirectives:
        engine = tsDirectives['TS-program']
    elif usesOnePackage(latexIndicators,packages):
        engine = 'latex'
    elif usesOnePackage(xelatexIndicators,packages):
        engine = 'xelatex'
    else:
        engine = tmPrefs['latexEngine']
    stat = os.system('type '+engine+' > /dev/null')
    if stat != 0:
        print '<p class="error">Error: %s is not found, you need to install LaTeX or be sure that your PATH is setup properly.</p>' % engine
        sys.exit(1)
    return engine

def getFileNameWithoutExtension(fileName):
    """Return filename upto the . or full filename if no ."""
    suffStart = fileName.rfind(".")
    if suffStart > 0:
        fileNoSuffix = fileName[:suffStart]
    else:
        fileNoSuffix = fileName
    return fileNoSuffix
    
def writeLatexmkRc(engine,eOpts):
    """Create a latexmkrc file that uses the proper engine and arguments"""
    rcFile = open("/tmp/latexmkrc",'w')
    rcFile.write("""$latex = 'latex -interaction=nonstopmode -file-line-error-style %s  ';\n""" % eOpts)
    rcFile.write("""$pdflatex = '%s -interaction=nonstopmode -file-line-error-style %s ';\n""" % (engine, eOpts))
#    rcFile.write("""$bibtex = 'bibtex "%%B"';\n""")
#    rcFile.write("""$dvips = 'dvips %O "%S" -o "%D"';\n""")
#    rcFile.write("""$dvipdf = 'dvipdf %O "%S" "%D"';\n""")
#    rcFile.write("""$clean_full_ext = "maf mtc mtc1 mtc2 mtc3";\n""")
    rcFile.close()
    
###############################################################
#                                                             #
#                 Start of main program...                    #
#                                                             #
###############################################################

if __name__ == '__main__':
    verbose = False
    numRuns = 0
    stat = 0
    texStatus = None
    numErrs = 0
    numWarns = 0
    firstRun = False
    synctex = False
    
#
# Parse command line parameters...
#
    if len(sys.argv) > 2:
        firstRun = True         ## A little hack to make the buttons work nicer.
    if len(sys.argv) > 1:
        texCommand = sys.argv[1]
    else:
        sys.stderr.write("Usage: "+sys.argv[0]+" tex-command firstRun\n")
        sys.exit(255)

#
# Get preferences from TextMate or local directives
#
    tmPrefs = tmprefs.Preferences()

    if int(tmPrefs['latexDebug']) == 1:
        DEBUG = True
        print '<pre>turning on debug</pre>'

    tsDirs = find_TEX_directives()
    os.chdir(determine_ts_directory(tsDirs))
    
#
# Set up some configuration variables
#
    if tmPrefs['latexVerbose'] == 1:
        verbose = True


    useLatexMk = tmPrefs['latexUselatexmk']
    if texCommand == 'latex' and useLatexMk:
        texCommand = 'latexmk'
    
    if texCommand == 'latex' and tmPrefs['latexEngine'] == 'builtin':
        texCommand = 'builtin'

    fileName,filePath = findFileToTypeset(tsDirs)
    fileNoSuffix = getFileNameWithoutExtension(fileName)
    
    ltxPackages = findTexPackages(fileName)
        
    viewer = tmPrefs['latexViewer']
    engine = constructEngineCommand(tsDirs,tmPrefs,ltxPackages)

    syncTexCheck = os.system(engine + " --help |grep -q synctex")
    if syncTexCheck == 0:
        synctex = True
    
    # Make sure that the bundle_support/tex directory is added
    #pcmd = os.popen("kpsewhich -progname %s --expand-var '$TEXINPUTS':%s/tex//" % (engine,bundle_support))
    #texinputs = pcmd.read()
    #using the output of kpsewhich fails to work properly.  The simpler method below works fine
    if os.getenv('TEXINPUTS'):
        texinputs = os.getenv('TEXINPUTS') + ':'
    else:
        texinputs = ".::"
    texinputs += "%s/tex//" % os.getenv('TM_BUNDLE_SUPPORT')
    os.putenv('TEXINPUTS',texinputs)

    if DEBUG:
        print '<pre>'
        print 'texMateVersion = ', texMateVersion
        print 'engine = ', engine
        print 'texCommand = ', texCommand
        print 'viewer = ', viewer
        print 'texinputs = ', texinputs
        print 'fileName = ', fileName
        print 'useLatexMk = ', useLatexMk
        print 'synctex = ', synctex
        print '</pre>'


    if texCommand == "version":
      runObj = Popen(engine + " --version",stdout=PIPE,shell=True)
      print runObj.stdout.read().split("\n")[0]
      sys.exit(0)


#
# print out header information to begin the run
#
    if not firstRun:
        print '<hr>'
    #print '<h2>Running %s on %s</h2>' % (texCommand,fileName)
    print '<div id="commandOutput"><div id="preText">'
    
    if fileName == fileNoSuffix:
        print "<h2 class='warning'>Warning:  Latex file has no extension.  See log for errors/warnings</h2>"
        
    if synctex and 'pdfsync' in ltxPackages:
        print "<p class='warning'>Warning:  %s supports synctex but you have included pdfsync. You can safely remove \usepackage{pdfsync}</p>" % engine


#
# Run the command passed on the command line or modified by preferences
#
    if texCommand == 'latexmk':
        writeLatexmkRc(engine,constructEngineOptions(tsDirs,tmPrefs))
        if engine == 'latex':
            texCommand = TM_BUNDLE_SUPPORT + '/bin/latexmk.pl -pdfps -f -r /tmp/latexmkrc ' 
        else:
            texCommand = TM_BUNDLE_SUPPORT + '/bin/latexmk.pl -pdf -f -r /tmp/latexmkrc '
#        if ' ' in fileName:
#            texCommand += shell_quote(shell_quote(fileName))
#        else:
        texCommand += shell_quote(fileName)
        if DEBUG:
            print 'latexmk command = ', texCommand
        runObj = Popen(texCommand,shell=True,stdout=PIPE,stdin=PIPE,stderr=STDOUT,close_fds=True)
        commandParser = ParseLatexMk(runObj.stdout,verbose,fileName)
        isFatal,numErrs,numWarns = commandParser.parseStream()
        texStatus = runObj.wait()
        os.remove("/tmp/latexmkrc")
        if tmPrefs['latexAutoView'] and numErrs < 1:
            stat = run_viewer(viewer,fileName,filePath,tmPrefs['latexKeepLogWin'],'pdfsync' in ltxPackages or synctex)
        numRuns = commandParser.numRuns
        
    elif texCommand == 'bibtex':
        texStatus, isFatal, numErrs, numWarns = run_bibtex(texfile=fileName)
        
    elif texCommand == 'index':
        texStatus, isFatal, numErrs, numWarns = run_makeindex(fileName)
    
    elif texCommand == 'clean':
        texCommand = 'latexmk.pl -CA '
        runObj = Popen(texCommand,shell=True,stdout=PIPE,stdin=PIPE,stderr=STDOUT,close_fds=True)
        commandParser = ParseLatexMk(runObj.stdout,True,fileName)
        
    elif texCommand == 'builtin':
        # the latex, bibtex, index, latex, latex sequence should cover 80% of the cases that latexmk does
        texCommand =  engine + " " + constructEngineOptions(tsDirs,tmPrefs)
        texStatus,isFatal,numErrs,numWarns = run_latex(texCommand,fileName,verbose)
        texStatus, isFatal, numErrs, numWarns = run_bibtex(texfile=fileName)
        if os.path.exists(fileNoSuffix+'.idx'):
            texStatus, isFatal, numErrs, numWarns = run_makeindex(fileName)
        texStatus,isFatal,numErrs,numWarns = run_latex(texCommand,fileName,verbose)
        texStatus,isFatal,numErrs,numWarns = run_latex(texCommand,fileName,verbose)
        
    elif texCommand =='latex':
        texCommand = engine + " " + constructEngineOptions(tsDirs,tmPrefs)
        texStatus,isFatal,numErrs,numWarns = run_latex(texCommand,fileName,verbose)
        if engine == 'latex':
            psFile = fileNoSuffix+'.ps'
            os.system('dvips ' + fileNoSuffix+'.dvi' + ' -o ' + psFile)
            os.system('ps2pdf ' + psFile)
        if tmPrefs['latexAutoView'] and numErrs < 1:
            stat = run_viewer(viewer,fileName,filePath,tmPrefs['latexKeepLogWin'],'pdfsync' in ltxPackages or synctex)
        
    elif texCommand == 'view':
        stat = run_viewer(viewer,fileName,filePath,tmPrefs['latexKeepLogWin'],'pdfsync' in ltxPackages or synctex)
        
    elif texCommand == 'sync':
        if 'pdfsync' in ltxPackages or synctex:
            stat = sync_viewer(viewer,fileName,filePath)
        else:
            print "pdfsync.sty must be included to use this command"
            print "or use a typesetter that supports synctex (such as TexLive 2008)"
            sys.exit(206)
            
    elif texCommand == 'chktex':
        texCommand += ' '
        texCommand += shell_quote(fileName)
        runObj = Popen(texCommand,shell=True,stdout=PIPE,stdin=PIPE,stderr=STDOUT,close_fds=True)
        commandParser = ChkTeXParser(runObj.stdout,verbose,fileName)
        isFatal,numErrs,numWarns = commandParser.parseStream()
        texStatus = runObj.wait()
    
#    
# Check status of running the viewer
#
    if stat != 0:
        print '<p class="error"><strong>error number %d opening viewer</strong></p>' % stat

#
# Check the status of any runs...
#
    eCode = 0
    if texStatus != 0 or numWarns > 0 or numErrs > 0:
        print "<p class='info'>Found " + str(numErrs) + " errors, and " + str(numWarns) + " warnings in " + str(numRuns) + " runs</p>"
        if texStatus:
            if texStatus > 0:
                print "<p class='info'>%s exited with status %d</p>" % (texCommand,texStatus )
            else:
                print "<p class='error'>%s exited with error code %d</p> " % (texCommand,texStatus)
#
# Decide what to do with the Latex & View log window   
#
    if not tmPrefs['latexKeepLogWin']:
        if numErrs == 0 and viewer != 'TextMate':
            eCode = 200
        else:
            eCode = 0
    else:
        eCode = 0

    print '</div></div>'  # closes <pre> and <div id="commandOutput"> 

#
# Output buttons at the bottom of the window
#
    if firstRun:
        # only need to include the javascript library once
        js = os.getenv('TM_BUNDLE_SUPPORT') + '/bin/texlib.js'
        js = quote(js)
        print """
         <script src="file://%s"    type="text/javascript" charset="utf-8"></script>
         """ % js

        print '<div id="texActions">'
        print '<input type="button" value="Re-Run %s" onclick="runLatex(); return false" />' % engine
        print '<input type="button" value="Run BibTeX" onclick="runBibtex(); return false" />'
        print '<input type="button" value="Run Makeindex" onclick="runMakeIndex(); return false" />'
        print '<input type="button" value="Clean up" onclick="runClean(); return false" />'        
        if viewer == 'TextMate':
            pdfFile = fileNoSuffix+'.pdf'
            print """<input type="button" value="view in TextMate" onclick="window.location='""" + 'tm-file://' + quote(filePath+'/'+pdfFile) +"""'"/>"""
        else:
            print '<input type="button" value="View in %s" onclick="runView(); return false" />' % viewer
        print '<input type="button" value="Preferences…" onclick="runConfig(); return false" />'
        print '<p>'
        print '<input type="checkbox" id="hv_warn" name="fmtWarnings" onclick="makeFmtWarnVisible(); return false" />'
        print '<label for="hv_warn">Show hbox,vbox Warnings </label>'     
        if useLatexMk:
            print '<input type="checkbox" id="ltxmk_warn" name="ltxmkWarnings" onclick="makeLatexmkVisible(); return false" />'
            print '<label for="ltxmk_warn">Show Latexmk.pl Messages </label>'
        print '</p>'
        print '</div>'

    sys.exit(eCode)
