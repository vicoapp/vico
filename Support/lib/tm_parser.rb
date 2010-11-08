module TextMate

	def TextMate.url_esc (url)
		url.gsub(/[^a-zA-Z0-9.-\/]/) { |m| sprintf("%%%02X", m[0]) }
	end

	def TextMate.html_esc (text)
		text.gsub(/&/, '&amp;').gsub(/</, '&lt;')
	end

	def TextMate.parse_errors
		print '<pre style="word-wrap: break-word;">'
		STDIN.each_line do |line|
			line = line.chop
			if m = /^(.*?):(?:(\d+):)?\s*(.*?)$/.match(line) then
				file, no, error = m[1..3]
				file = File.expand_path(file, ENV['PWD'])
				if File.exists?(file)
					print "<a href='txmt://open?url=file://#{url_esc file}"
					print "&line=#{no}" unless no.nil?
					print "'>#{html_esc error}</a><br>"
				else
					print html_esc(line) + '<br>'
				end
			else
				print html_esc(line) + '<br>'
			end
		end
		print '</pre>'
	end

end
