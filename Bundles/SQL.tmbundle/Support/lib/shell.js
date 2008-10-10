// Escape a string for passing to the shell
function shell_escape(arg) {
    arg = arg.replace(/(?=[^a-zA-Z0-9_.\/\-\x7F-\xFF])/g, '\\')
    return arg;
}

// Receives an object with parameter names and values and returns an array of escaped strings ready to be passed to shell_run
// Example: shell_join_long_args({database: 'db', table: 'tbl'}) => ['--database=db', '--table=tbl']
function shell_join_long_args(args) {
    commands = [];
    for (arg in args) {
        if (typeof args[arg] != 'function')
            commands.push('--' + arg + "=" + args[arg]);
    }
    return commands;
}

// Run a shell command and return the result. The command will not be escaped
function shell_run_raw(cmd) {
    TextMate.isBusy = true;
    var res = TextMate.system(cmd, null).outputString;
    TextMate.isBusy = false;
    return res;
}

// Run a shell command with escaped arguments. 
// A keyed object or a string can be passed as the argument to be escaped
function shell_run() {
    var args = Array.prototype.slice.apply(arguments), arg;
    var commands = [];
  
    for (key in args) {
        arg = args[key];
        if (typeof(arg) == 'object') {
            for (child_arg in arg) {
                if (typeof arg[child_arg] != 'function')
                    commands.push(shell_escape(arg[child_arg]));
            }
        } else {
            if (typeof arg != 'function')
                commands.push(shell_escape(arg));
        }
    }
  
    return shell_run_raw(commands.join(' '));
}
