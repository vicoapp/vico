import os
import newplistlib as plistlib
import string

try:
    from Foundation import *
    haspyobjc = True
except:
    haspyobjc = False


try:
    from subprocess import *
except:
    PIPE = 1
    STDOUT=1
    class Popen(object):
        """Popen:  This class provides backward compatibility for Tiger
           Do not assume anything about this works other than access
           to stdin, stdout and the wait method."""
        def __init__(self, command, **kwargs):
            super(Popen, self).__init__()
            self.command = command
            self.stdin, self.stdout = os.popen4(command)

        def wait(self):
            stat = self.stdout.close()
            return stat

class Preferences(object):
    """docstring for Preferences"""
    def __init__(self):
        super(Preferences, self).__init__()
        self.defaults = {
            'latexAutoView' : 1, 
            'latexEngine' : "pdflatex",
            'latexEngineOptions' : "",
            'latexVerbose' : 0,
            'latexUselatexmk' : 0,
            'latexViewer' : "TextMate",
            'latexKeepLogWin' : 1,
            'latexDebug' : 0,
        }
        self.prefs = self.defaults.copy()
        self.prefs.update(self.readTMPrefs())
        
    def __getitem__(self,key):
        """docstring for __getitem__"""
        return self.prefs.get(key,None)

    def readTMPrefs(self):
        """readTMPrefs reads the textmate preferences file and constructs a python dictionary.
        The keys that are important for latex are as follows:
        latexAutoView = 0
        latexEngine = pdflatex
        latexEngineOptions = "-interaction=nonstopmode -file-line-error-style"
        latexUselatexmk = 0
        latexViewer = Skim
        """
        # ugly as this is it is the only way I have found so far to convert a binary plist file into something
        # decent in Python without requiring the PyObjC module.  I would prefer to use popen but
        # plutil apparently tries to do something to /dev/stdout which causes an error message to be appended
        # to the output.
        #
        plDict = {}
        if haspyobjc:
            plDict = NSDictionary.dictionaryWithContentsOfFile_(os.environ["HOME"]+"/Library/Preferences/com.macromates.textmate.plist")
        else:   # TODO remove all this once everyone is on leopard
            os.system("plutil -convert xml1 \"$HOME/Library/Preferences/com.macromates.textmate.plist\" -o /tmp/tmltxprefs1.plist")
            null_tt = "".join([chr(i) for i in range(256)])
            non_printables = null_tt.translate(null_tt, string.printable)
            plist_str = open('/tmp/tmltxprefs1.plist').read()
            plist_str = plist_str.translate(null_tt,non_printables)
            try:
                plDict = plistlib.readPlistFromString(plist_str)
            except:
                print '<p class="error">There was a problem reading the preferences file, continuing with defaults</p>'
            try:
                os.remove("/tmp/tmltxprefs1.plist")
            except:
                print '<p class="error">Problem removing temporary prefs file</p>'
        return plDict
        
    def toDefString(self):
        """docstring for toDefString"""
        instr = plistlib.writePlistToString(self.defaults)
        runObj = Popen('pl',shell=True,stdout=PIPE,stdin=PIPE,stderr=STDOUT,close_fds=True)
        runObj.stdin.write(instr)
        runObj.stdin.close()
        defstr = runObj.stdout.read()
        return defstr.replace("\n","")

if __name__ == '__main__':
    test = Preferences()
    print test.toDefString()
    print test['latexUselatexmk']
    print test['Foo']
    useLatexMk = test['latexUselatexmk']
    print useLatexMk
    
    
