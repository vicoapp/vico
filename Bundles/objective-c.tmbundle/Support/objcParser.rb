#!/usr/bin/env ruby
require "#{ENV['TM_SUPPORT_PATH']}/lib/escape"
require ENV['TM_SUPPORT_PATH'] + "/lib/exit_codes"

class Lexer
  include Enumerable
  def initialize
    @label   = nil
    @pattern = nil
    @handler = nil
    @input   = nil
    
    reset
    
    yield self if block_given?
  end
  
  def input(&reader)
    if @input.is_a? self.class
      @input.input(&reader)
    else
      class << reader
        alias_method :next, :call
      end
      
      @input = reader
    end
  end
  
  def add_token(label, pattern, &handler)
    unless @label.nil?
      @input = clone
    end
    
    @label   = label
    @pattern = /(#{pattern})/
    @handler = handler || lambda { |label, match| [label, match] }
    
    reset
  end
  
  def next(peek = false)
    while @tokens.empty? and not @finished
      new_input = @input.next
      if new_input.nil? or new_input.is_a? String
        @buffer    += new_input unless new_input.nil?
        new_tokens =  @buffer.split(@pattern)
        while new_tokens.size > 2 or (new_input.nil? and not new_tokens.empty?)
          @tokens << new_tokens.shift
          @tokens << @handler[@label, new_tokens.shift] unless new_tokens.empty?
        end
        @buffer   = new_tokens.join
        @finished = true if new_input.nil?
      else
        separator, new_token = @buffer.split(@pattern)
        new_token            = @handler[@label, new_token] unless new_token.nil?
        @tokens.push( *[ separator,
                         new_token,
                         new_input ].select { |t| not t.nil? and t != "" } )
        reset(:buffer)
      end
    end
    peek ? @tokens.first : @tokens.shift
  end
  
  def peek
    self.next(true)
  end
  
  def each
    while token = self.next
      yield token
    end
  end
  
  private
  
  def reset(*attrs)
    @buffer   = String.new if attrs.empty? or attrs.include? :buffer
    @tokens   = Array.new  if attrs.empty? or attrs.include? :tokens
    @finished = false      if attrs.empty? or attrs.include? :finished
  end
end


class ObjcParser
	
	attr_reader :list
  def initialize(args)
    @list = args
  end
  
  def get_position
    return nil,nil if @list.empty?
	has_message = true

    a = @list.pop
    endings = [:close,:post_op,:at_string,:at_selector,:identifier]
openings = [:open,:return,:control]
    if a.tt == :identifier && !@list.empty? && endings.include?(@list[-1].tt)
      insert_point = find_object_start
    else
      @list << a
	has_message = false unless methodList
      insert_point = find_object_start
    end
return insert_point, has_message
  end
  
  def methodList
    	old = Array.new(@list)

    a = selector_loop(@list)
    if !a.nil? && a.tt == :selector
      if file_contains_selector? a.text
        return true
      else
        internal = Array.new(@list)
        b = a.text
        until internal.empty?
          tmp = selector_loop(internal)
          return true if tmp.nil?
          b = tmp.text + b
          if file_contains_selector? b
            @list = internal
            return true
          end
        end
      end
	else
    end
@list = old
return false
  end
  
  def file_contains_selector?(methodName)
    fileNames = ["#{ENV['TM_BUNDLE_SUPPORT']}/cocoa.txt.gz"]
    userMethods = "#{ENV['TM_PROJECT_DIRECTORY']}/.methods.TM_Completions.txt.gz"

    fileNames += [userMethods] if File.exists? userMethods
    candidates = []
    fileNames.each do |fileName|
      zGrepped = %x{zgrep ^#{e_sh methodName }[[:space:]] #{e_sh fileName }}
      candidates += zGrepped.split("\n")
    end

    return !candidates.empty?
  end
  
  def selector_loop(l)
    until l.empty?
      obj = l.pop
      case obj.tt
      when :selector
        return obj
      when :close
        return nil if match_bracket(obj.text,l).nil?
      when :open
        return nil
      end
    end
    return nil
  end
  
  def match_bracket(type,l)
    partner = {"]"=>"[",")"=>"(","}"=>"{"}[type]
    up = 1
    until l.empty?
      obj = l.pop
      case obj.text
      when type
        up +=1
      when partner
        up -=1
      end
      return obj.beg if up == 0
    end
  end
  
  def find_object_start
    openings = [:operator,:selector,:open,:return,:control,:terminator]
    until @list.empty? || openings.include?(@list[-1].tt)
      obj = @list.pop
      case obj.tt
      when :close
        tmp = match_bracket(obj.text, @list)
        b = tmp unless tmp.nil?
      when :star
        b, ate = eat_star(b,obj.beg)
        return b unless ate
      when :nil
        b = nil
      else
        b = obj.beg
      end
    end
    return b
  end

  def eat_star(prev, curr)
    openings = [:operator,:selector,:open,:return,:control,:star,:terminator]
    if @list.empty? || openings.include?(@list[-1].tt)
      return curr, true
    else
      return prev, false
    end
  end
end
