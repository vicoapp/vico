#
# String helpers for build command tokenization.
#
class String

	# strscan was not bundled with Ruby 1.6, so we need to roll our own.
	# This is actually not much more code than the equivalent strscan code,
	# I believe, but it's more intricate than a strscan version would be.
	def next_token
		out_token = ""
		state = :normal
		
		self.slice(@happy_token_offset...self.length).each_byte do |byte|
			
			char = byte.chr
			
			@happy_token_offset += 1
			
			case state
				when :singlequote
					if char == '\''
						state = :normal
					else
						out_token += char
					end
				when :doublequote
					if char == '"'
						state = :normal
					else
						out_token += char
					end
				when :ignore_next
					out_token += char
					state = :normal
				when :normal
					state = case char
						when '\\'
							:ignore_next
						when '\''
							:singlequote
						when '"'
							:doublequote
						when /\s/
							break
						else
							out_token += char
							:normal
					end
			end
		end
		
		out_token
	end
	
	# return a list of tokens.
	# Token delimiters are double-quotes and whitespace, except for whitespace within double-quotes.
	def tokenize
		out_tokens = Array.new
		
		@happy_token_offset = 0
		until @happy_token_offset >= (self.length - 1)
			out_tokens << next_token
		end
		
		out_tokens.reject {|token| token.empty? }
	end
	
	# insert escape sequences where needed
	def quote_filename_for_shell
		outname = ""
		self.each_byte do |byte|	
			char = byte.chr
			case char
				when /[^\w_\-\+=\/\x7F-\xFF]/
					outname += "\\"
			end
			outname += char
		end
		outname
	end
		
end

class Array
	def quote_for_shell_arguments
		self.collect{|path| path.quote_filename_for_shell}.join(" ")
	end
end

module TextMate
	
	# parse TM environment variables
	def TextMate.selected_paths_array
		paths = nil
		paths = ENV['TM_SELECTED_FILES'].dup.tokenize if ENV.has_key?('TM_SELECTED_FILES')

		if ENV.has_key?('TM_FILEPATH') and paths.nil?
			paths = [ENV['TM_FILEPATH']]
#			if paths.nil?
#				paths = [ENV['TM_FILEPATH']]
#			else 
#				paths.push ENV['TM_FILEPATH']
#			end
		end

		if paths.nil?
			paths = [ ]
		end

		paths
	end

	def TextMate.selected_paths_for_shell
		selected_paths_array.quote_for_shell_arguments
	end

end
