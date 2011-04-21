# Working with remote files

Vico has built-in support for editing files over SFTP. To open a remote directory,
use the <kbd>:cd</kbd> command to change to a <kbd>sftp://</kbd> URL. For
example, <kbd>:cd sftp://www.example.com</kbd> changes to the home directory on
the <kbd>www.example.com</kbd> server. Use the [explorer](explorer.html)
sidebar to open files, or directly with the <kbd>:edit</kbd> command.

A file relative to the home directory on the remote server can be referenced
by the following URL: <kbd>sftp://www.example.com/~/directory/file.txt</kbd>

For SFTP to work, you must use public key authentication. It is recommended
that you protect your private key with a passphrase.

Vico's SFTP support uses the ssh support built-in to Mac OS X, so any
configuration files you already have for ssh will be used.

  * [Creating a key for SFTP](ssh_keygen.html)
  * [ex command line](ex.html)
  * [ssh_config(5) manual page](http://developer.apple.com/library/mac/#documentation/Darwin/Reference/ManPages/man5/ssh_config.5.html)

