require 'rubygems'
require 'highline'

class TerminalMarkup
	
	def initialize
		@terminal = HighLine.new
	end
	
	def horizontal_line
		"\e(0qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq\e(B"
	end
	
	def ul
		@list_items = Array.new
		yield
		@terminal.say(@terminal.list(@list_items))
	end
	
	def style(*style)
		# eat style declarations
	end
	
	def li(*args)
		if block_given? then
			text = yield
		elsif args.size > 0
			text = args[0]
		end
		@list_items << text
	end
	
	def div( things )
		style = nil
		
		if things.has_key? :class then
			style = case things[:class]
			when 'error'
				HighLine::RED
			when 'warning'
				HighLine::YELLOW
			when 'info', 'command'
				HighLine::BLUE
			else
				''
			end
		end
		
		@terminal.say(style + horizontal_line)
		yield if block_given?
		@terminal.say(HighLine::CLEAR)
	end
	
	def method_missing(sym, *args)
		if block_given? then
			text = yield
		elsif args.size > 0
			text = args[0]
		end
		@terminal.say(text.to_s) if (not text.nil?) and (text.respond_to? :to_s)
	end	
end
