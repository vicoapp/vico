#!/usr/bin/env ruby

#
# File: rubywrap.rb
# Wraps comments in ruby files.
#
# == License
#
# Copyright (c) 2006 Christopher Alfeld
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
#
# == Author
#
# Christopher Alfeld (calfeld@math.utah.edu)
#
# Web: http://www.math.wisc.edu/~alfeld/code/rubywrap/
#
# Please feel free to e-mail bugs, questions, comments, etc.
#
# == Description
#
# RubyWrap is a word wrapper utility designed for ruby scripts.  It should,
# however work for any programming language which uses an initial prefix for
# comments (see --prefix).  RubyWrap correctly handles indented comments,
# indented text within comments, header comments, and many forms of lists.  It
# will also pass through code without change and detabify.
#
# See Example.
#
# == Example
#
# The following text will all wrap correctly.
#
#  # This a header...
#  # ... it will not absorb this line.
#  #
#  #     This block of text will be left alone by default as it represents 
#  #     a verbatim block of RDoc text.  If the -n option is given then
#  #     RDoc-Style is off then it will be correctly wrapped, maintaining it's
#  #     indentation level.  In any case it will not abosrb...
#  #  ... this line because this line has a different indentation level.
#  #
#       # This comment will retain it's indentation and correctly wrap when
#       # it goes over over the page width.
#
#  # label  This is a list.  It contains a label and some text.  If the text
#  #        is indented past the label and the final space lines up then it
#  #        is considered to be a single block and properly wrapped.  Note
#  #        that this requires at least two lines to get right.
#
#  # * This is an rdoc list element.  It properly wraps even as a single line
#  #   and does not require a second line to wrap correctly.
#
#  # * Here are two rdoc list elements.  Even though they are adjacent...
#  # * ... they will not wrap.
#
#
# == Headers
#
# RubyWrap uses a very simple algorithm for identifying headers: it looks for
# short lines.  Any line below a certain threshold is not-wrapped. By default
# this threshold is 50, it can be changed with -s.
#
# == Non Rdoc Style
#
# When RDoc style is turned off (-n) RubyWrap identifies list items by looking
# for a label and then a second line indented past the label.  This means that
# single line list items do not wrap, the second line is required.
#
# Blocks of text indented after the # are wrapped maintaining their
# indentation level.
#
# == RDoc Style (Default)
#
# In RDOc style RubyWrap looks for lines that appear to be RDoc list items.
# These lines are then properly wrapped with later lines indented properly and
# closely set list items do not wrap together.
#
# Text indented after the # is considered to be verbatim and left alone.
#
# RDoc tries to find a natural margin for comments.  RubyWrap currently does
# not do this.  If you use more than a single space after your # then you
# should redefine the prefix with -p.
#
# == Comment Prefix
#
# The comment prefix can be changed with -p.  By default the comment prefix is
# "# ".  Note the trailing space.  You will generally want a trailing space
# for any prefix.  If you prefer to indent your comments more than a single
# space past the # then change the prefix appropriately.
#
# == Limitations
#
# * Doesn't handle multilevel RDoc lists correctly.  This is a balance between
#   recognizing verbatim blocks and list items.  A nice solution would be to
#   treat it is a list item if it appeared to be a part of a list but that
#   would require context beyond the current block.
# * Doesn't find the natural margin like RDoc does.  This can easily be
#   overcome by -p but it would be a nice feature.  Probably not too hard.
#
# == Using with other languages
#
# With appropriate use of -r and -p RubyWrap should work for any language that
# distinguishes comments by some prefix.  Languages that use "# " should work
# well out of the box.
#
# == Usage
#
# rubywrap.rb [<options>]
# Options:
#   --prefix, -p <prefix>       Use <prefix> as the comment prefix.
#   --shortthreshold -s <n>     Lines of length <= n are single line blocks.
#   --cols, -c <n>              How many columns to wrap to (default: 78)
#   --tabsize, -t <n>           How many spaces a tab is (default: 2)
#   --no-rdoc-style, -n         Do not use RDoc conventions.
#   --retabify, -r              Retabify output.
#   --help, -h                  Display this help.
#   --doc, -d                   Display full documentation.
# Reads commented code from stdin and outputs wrapped commented code to
# stdout.
#

require 'rdoc/usage'
require 'getoptlong'

opts = GetoptLong.new(
  ["--prefix",         "-p",    GetoptLong::REQUIRED_ARGUMENT],
  ["--shortthreshold", "-s",    GetoptLong::REQUIRED_ARGUMENT],
  ["--cols",           "-c",    GetoptLong::REQUIRED_ARGUMENT],
  ["--tabsize",        "-t",    GetoptLong::NO_ARGUMENT],
  ["--no-rdoc-style",  "-n",    GetoptLong::NO_ARGUMENT],
  ["--retabify",       "-r",    GetoptLong::NO_ARGUMENT],
  ["--help",           "-h",    GetoptLong::NO_ARGUMENT],
  ["--doc",            "-d",    GetoptLong::NO_ARGUMENT]
)

$prefix = "# "
$cols = 78
$shorttheshold = 50
$tabsize = 2
$rdocstyle = true
$retabify = false
opts.each do |opt,arg|
  case opt
  when "--prefix"
    $prefix = arg
  when "--shortthreshold"
    $shortthreshold = arg.to_i
  when "--cols"
    $cols = arg.to_i
  when "--tabsize"
    $tabsize = arg.to_i
  when "--no-rdoc-style"
    $rdocstyle = false
  when "--retabify"
    $retabify = true
  when "--help"
    RDoc::usage("Usage")
  when "--doc"
    RDoc::usage
  end
end
if ARGV.length != 0
  RDoc::usage
end

# Add detabify, entabify to String class.
class String
  @@re_entabify = Regexp.new(" "*$tabsize)
  def detabify
    gsub(/\t/," "*$tabsize)
  end
  def entabify
    gsub(@@re_entabify,"\t")
  end
  def detabify!
    gsub!(/\t/," "*$tabsize)
  end
  def entabify!
    gsub!(@@re_entabify,"\t")
  end
end

#
# IOLookAhead
#
# == Description
# Simple class which allows reading lines and peeking at the next line.
#
class IOLookAhead 
  # Create an IOLookAhead (iola) from an IO object.
  def initialize(io)
    @io = io
    @buffer = nil
  end

  # Returns the next line without advancing. Returns nil on eof.
  def peek
    @buffer ||= @io.gets
    @buffer
  end
  
  # Returns the next line and advances. Returns nil on eof.
  def pop
    ret = peek
    @buffer = nil
    ret
  end
end

# Block
#
# == Description
# A block is a block of text that should be wrapped.  It has several
# attributes:
#
# _type_::              :comment, :verbatim, or :code, :code is written 
#                       directly, :comment is wrapped, :verbatim has a 
#                       properly indent prefix prepended but that's it.
# _pre_indent_::        how many spaces to put before $prefix
# _post_indent_::       how many spaecs to put after $prefix and before text
# _first_post_indent_:: how many spaces to put after $prefix for the first 
#                       line
#
class Block
  attr_accessor :type,:text,:pre_indent,:post_indent,:first_post_indent
  
  # matches any comment, note depdendence on $prefix
  @@re_comment = Regexp.new("^(\\s*)#{$prefix}(\\s*)")
  # matches an rdoc list item.
  @@re_rdoc_list_item = /^(\s*(?:\*\s|\d\.\s|\[.+\]\s|\S+::\s))/
  
  # don't call this - use Block.from_iola instead.
  def initialize
    @type = :unknown
    @text = ""
    @pre_indent = 0
    @post_indent = 0
    @first_post_indent = 0
  end
  
  # Creates a block from a IOLookAhead object.
  def self.from_iola(iola)
    block = Block.new
    # The first two lines determine all parameters and we treat them special.
    firstline = iola.pop
    return nil if ! firstline
    if firstline.detabify =~ @@re_comment
      firstline.detabify!
      pre = $1
      post = $2
      text = firstline[pre.length+post.length+$prefix.length..-1].chomp
      block << text
      block.pre_indent = pre.length
      block.first_post_indent = post.length
      block.post_indent = block.first_post_indent
      if $rdocstyle && post.length > 0
        block.type = :verbatim
        return block
      end
      block.type = :comment
      if $rdocstyle && text =~ @@re_rdoc_list_item
        rdoc_list_prefix = $1
        block.post_indent = rdoc_list_prefix.length
      else
        rdoc_list_prefix = nil
      end
      secondline = iola.peek
      return block if ! secondline
      if (! $rdocstyle || post.length == 0) &&
          firstline.length > $shorttheshold && 
          secondline.detabify =~ @@re_comment 
        secondline.detabify!
        # We still may not be part of the block.  If our pre_indent is
        # different then we're a new block.  For post_indent we use the
        # following simple algorithm: we are part of the same block if we have
        # the same post_indent or a great post_indent and the character above
        # our last post_indent space is a space and there is a non-space
        # character at some point before that.  If RDoc style is on and we
        # look like a list item then we aren't part of the block.
        pre = $1
        post = $2
        text = secondline[pre.length+post.length+$prefix.length..-1].chomp
        if pre.length == block.pre_indent &&
            text.length > 0 &&
            ((post.length == block.first_post_indent || 
              (rdoc_list_prefix && post.length == block.post_indent)) ||
              (post.length > block.first_post_indent &&
                (firstline[0..post.length] =~ /\S\s+$/))) &&
           (! $rdocstyle || text !~ @@re_rdoc_list_item)
          block.post_indent = post.length
          block << text
          iola.pop
          inblock = true
          while inblock
            inblock = false
            nextline = iola.peek#            p "!! #{nextline}"
            if nextline && nextline =~ @@re_comment && 
              nextline.length > pre.length+post.length+$prefix.length
              text = nextline[pre.length+post.length+$prefix.length..-1].chomp
              pre = $1
              post = $2
              if (pre.length == block.pre_indent) && 
                  (post.length == block.post_indent) &&
                  (! $rdocstyle || text !~ @@re_rdoc_list_item)
                iola.pop
                block <<
                  nextline[pre.length+post.length+$prefix.length..-1].chomp
                inblock = true
              end
            end
          end
        end
      end
    else
      block.type = :code
      block << firstline
    end
    block
  end
  
  # Writes the block to _io_.
  def write(io)
    if type == :code
      print text
    elsif type == :verbatim
      output = " "*pre_indent + $prefix + " "*first_post_indent + text + "\n"
      output.entabify! if $retabify
      print output
    elsif type == :comment
      cur_post_indent = first_post_indent
      # special case of a line that is just $prefix
      if text.length == 0
        print " "*pre_indent + $prefix + " "*cur_post_indent + "\n"
      end
      while text.length > 0
        width = $cols - pre_indent - $prefix.length - cur_post_indent
        if first_word.length > width
          STDERR.print "Warning: #{first_word} is too long to fit in column."
          output = " "*pre_indent + $prefix + " "*cur_post_indent + 
            first_word + "\n"
          output.entabify! if $retabify
          print output
          trim(first_word.length)
          @text.lstrip!
        else
          out = words_to(width)
          output = " "*pre_indent + $prefix + " "*cur_post_indent + out + "\n"
          output.entabify! if $retabify
          print output
          trim(out.length)
          @text.lstrip!
        end
        cur_post_indent = post_indent
      end
    else
      STDERR.print "Confused, never determined block type."
    end
  end

  # Adds text.  Adds a space if neither the end of the current text or the
  # beginning of _text_ is a space.
  def <<(text)
    if @text.length > 0 && @text[-1..-1] != " " && text[0..0] != " "
      @text += " "
    end
    @text += text
  end
  
  # remove the first n characters from the block
  def trim(n)
    @text = @text[n..-1] || ""
  end
  
  # Returns the first word of the text.
  def first_word
    text =~ /^.*?\S.*?/
    $&
  end
  
  # Returns the words up to the given length
  def words_to(n)
    re = Regexp.new("^(.{0,#{n}})(?:\s|$)")
    text =~ re
    $1 || text[0...n]
  end
end

iola = IOLookAhead.new(STDIN)
while block = Block.from_iola(iola)
  block.write(STDOUT)
end
