# Vico

Vico is a programmers text editor with a strong focus on keyboard
control. Vico uses vi key bindings to let you keep your fingers on the
home row and work effectively with your text.

Vico comes with support for the most common languages, such as html,
php, ruby and javascript. And since Vico can use existing TextMate
bundles, it's easy to add more.

Vico also features integrated SFTP for working with remote files, split
views to let you edit files side-by-side and a file explorer for fast
project navigation.

Quickly navigate between files using fuzzy find, or open files directly
from the ex command line with tab completion. Jumping to symbols is easy
with the symbol list, or use ctags to find the definition under the
cursor. Ctags even works remotely over SFTP.


## Building

Vico uses `make` to build. Simply type

	make run

to build and launch. While there is an xcode project, it is not up to
date and will not build properly.


## Contributing

Contributions from the community is encouraged.

1. Fork the `vico` repository on Github.
2. Clone your fork.

		git clone git@github.com:yourusername/vico.git

3. Create a topic branch for your change.

		git checkout -b some-topic-branch

4. Make your changes and commit. Use a clear and descriptive commit
   message. Make the first line a short summary of around 60 characters.
   More detailed explanation is followed after a blank line, wrapped to
   around 72 characters.

5. Push to your fork of the repository and then send a pull-request through Github for code review.

		git push mine some-topic-branch

## License

Vico is Copyright (c) 2008-2012, Martin Hedenfalk <martin@vicoapp.com>
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

1. Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

See each individual file for their respective license.
