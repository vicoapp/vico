# Creating a key for SFTP

To create a public/private key for SFTP (or ssh in general), you need to open
Terminal.app and run the <kbd>ssh-keygen</kbd> command:

	ssh-keygen -t rsa

It should look something like this;

	martinh@macbookpro:~$ ssh-keygen -t rsa
	Generating public/private rsa key pair.
	Enter file in which to save the key (/Users/martinh/.ssh/id_rsa):
	Enter passphrase (empty for no passphrase):
	Enter same passphrase again:
	Your identification has been saved in /Users/martinh/.ssh/id_rsa.
	Your public key has been saved in /Users/martinh/.ssh/id_rsa.pub.
	The key fingerprint is:
	77:15:d9:55:4f:b9:01:90:2c:48:ae:3b:39:22:52:fa martinh@macbookpro.local
	The key's randomart image is:
	+--[ RSA 2048]----+
	|      ... ..o.ooB|
	|      .. . o  .=o|
	|       .  .   . +|
	|      .      . . |
	|  .  .  S . .    |
	| o    o  . .     |
	|o. . =           |
	|... . o          |
	|  E              |
	+-----------------+
	martinh@macbookpro:~$ 

Make sure you use a good passphrase. If you leave the passphrase empty, anyone
with access to your key file have access to any remote server you authorize with
that key.

To authorize a remote server to log you in with this key, you copy the
*public key* to the <kbd>~/.ssh/authorized_keys</kbd> file on the remote server:

	cat ~/.ssh/id_rsa.pub | ssh hostname 'mkdir -m700 -p .ssh && cat >> .ssh/authorized_keys'

The above command makes sure the remote <kbd>.ssh</kbd> directory exists and has
the correct permissions, and appends your new public key to any existing
authorized keys.

If you have multiple keys, or use non-standard filenames, you may have to tell
ssh what key to use. You can do this by adding a host directive in the ssh
configuration file, <kbd>~/.ssh/config</kbd>:

	Host www.example.com
		IdentityFile ~/.ssh/id_rsa.example.com

  * [ssh_config(5) manual page](http://developer.apple.com/library/mac/#documentation/Darwin/Reference/ManPages/man5/ssh_config.5.html)

