require 'erb'

#
# Set up ERB for streaming incremental output rather than atomic, sit-and-wait for completion.
# chris@cjack.com
#
class ERB
	# stream must be the name of a stream variable available during run
	def ERB.run_to_stream(data, stream)
		
#		puts "<pre>" + data.inspect + "</pre>"
		erb = ERB.new(data)

		# Setup the compiler to print to stdout so we can do incremental output streaming
		# rather than downloading everthing first and rendering afterwards
		compiler = ERB::Compiler.new(nil)
		erb.set_eoutvar(compiler)
		
		# initialize compiler vars *after* call to setoutvar. Very important!
		compiler.pre_cmd	= []
		compiler.post_cmd	= []
		compiler.put_cmd	= '#{stream}.print'
		compiler.insert_cmd	= compiler.put_cmd if defined?(compiler.insert_cmd) # insert_cmd appears to be new in Ruby 1.9
		erb.run
	end
end
