from types import NoneType
import sys
import os
import subprocess

tm_support_path = os.environ['TM_SUPPORT_PATH'] + '/lib'
if tm_support_path not in sys.path:
    sys.path.insert(0, tm_support_path)

from tm_helpers import to_plist, from_plist

dialog = os.environ["DIALOG"]
nib_path = os.environ['TM_SUPPORT_PATH'] + '/nibs'

try:
    all
except:
    def all(items):
        for item in items:
            if not item:
                return False
        return True

def item(val):
    if isinstance(val, basestring):
        return {"title": val}
    if isinstance(val, tuple):
        return {"title": val[0]}
    elif val is None:
        return {"separator": 1}

def all_are_instance(it, typ):
    return all([isinstance(i, typ) for i in it])

def menu(options):
    """ Accepts a list and causes TextMate to show an inline menu.
    
    If options is a list of strings, will return the selected index.
    
    If options is a list of (key, value) tuples, will display "key" and 
    return "value". Note that we don't use dicts, so that key-value options
    can be ordered. If you want to use a dict, try dict.items().
    
    In either input case, a list item with value `None` causes tm_dialog to
    display a separator for that index.
    """
    hashed_options = False
    if not options:
        return None
    menu = dict(menuItems=[item(thing) for thing in options])
    if all_are_instance(options, (tuple, NoneType)):
        hashed_options = True
    plist = to_plist(menu)
    proc = subprocess.Popen([dialog, '-u'], stdout=subprocess.PIPE, stdin=subprocess.PIPE)
    proc.stdin.write(plist)
    output, _ = proc.communicate()
    result = from_plist(output)
    if not 'selectedIndex' in result:
        return None
    index = int(result['selectedIndex'])
    if hashed_options:
        return options[index][1]
    return options[index]

def get_string(**options):
    """Get a string using dialog
    
    Accepts `title` and `prompt` strings, and returns the string entered by
    the user.
    """
    
    # Set defaults and get options:
    if not options.has_key('title'):
        options['title']='Enter String'
    if not options.has_key('prompt'):
        options['prompt']='String:'
    plist = to_plist(options)
    
    # Run dialog, piping our plist in, and reading the output:
    nib = nib_path + '/RequestString'
    proc = subprocess.Popen([dialog, '-cm', nib], 
        stdout=subprocess.PIPE, stdin=subprocess.PIPE)
    proc.stdin.write(plist)
    output, _ = proc.communicate()
    
    # Extract exit value:
    result = from_plist(output)
    if not 'result' in result:
        return None
    else:
        return result['result'].get('returnArgument')
