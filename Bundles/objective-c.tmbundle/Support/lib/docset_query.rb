SUPPORT = ENV['TM_SUPPORT_PATH']

require SUPPORT + '/lib/exit_codes'
require SUPPORT + '/lib/escape'
require SUPPORT + '/lib/osx/plist'
require SUPPORT + '/lib/ui'

DOCSET_CMD = "/Developer/usr/bin/docsetutil search -skip-text -query "

DOCSETS = Dir.glob("/Developer/Documentation/DocSets/*.docset")


Man = Struct.new(:url, :language, :klass)
class Man
	def title
		klass
	end
end

Ref = Struct.new(:docset, :language, :type, :klass, :thing, :path)
class Ref
	TYPE_ABBREVIATIONS = {'cl' => 'Class', 'intf' => 'Protocol', 'cat' => 'Category', 
							'intfm' => 'Method', 'instm' => Method, 'econst' => 'Enum', 
							'tdef' => 'Typedef', 'macro' => 'Macro', 'data' => 'Data', 
							'func' => 'Function'}
							
	def url
		path[0] == ?/ ? path : docset + "/Contents/Resources/Documents/" + path
	end
	
	# A '-' as a title in the popup menu not very useful so use the type field instead.
	def title
		klass == '-' ? TYPE_ABBREVIATIONS[type] || type  : klass
	end
	
	def exists?
		File.exists?(url.split('#').first)
	end
	
	# Test if we are referring to documentation about the same
	# thing, but from different docsets. (used by uniq).
	def eql? (other)
		language == other.language && type == other.type && 
			klass == other.klass && thing == other.thing
	end
	
	# Also needed by uniq
	def hash
		(language + type + klass + thing).hash
	end
end


# Split the query result into its component types and document path.
# language is 'Objective-C', 'C', 'C++'
# type is 'instm' (nstance method), 'clsm' (class method, 'func' , 'econst', 'tag', 'tdef' and so on.
# klass holds the class or '-' if no class is appropriate (for a C function, for example).
# thing is the method, function, constant, etc.
def parts_of_reference (docset, ref_str)
	ref = ref_str.split
	if ref.length != 2
		TextMate.exit_show_tool_tip "Cannot parse reference: #{str}"
	end

	language, type, klass, thing = ref[0].split('/')
	Ref.new(docset, language, type, klass, thing, ref[1])
end
	
def search_docs (query)
	results = []
	DOCSETS.each do |docset|		
		cmd = DOCSET_CMD + query + ' ' + docset
		response = `#{cmd}`
			
		case response			# elaborate for doc purposes
			when ''
				# Not found.
			when /Documentation set path does not exist/
				# Docset not installed or moved somewhere else.
			else
				response.split("\n").each {|r| results << parts_of_reference(docset, r)}
		end	
	end
	
	# Remove any duplicated documentation (from different docsets).
	return results.uniq
end

def show_document (results, query)
	if results.nil? || results.empty?
		return nil
	elsif results.length == 1
		url = results[0].url
	else
		
		# Ask the user which class they are interested in.
		results.sort! {|a, b| a.klass <=> b.klass}
		if results.all? {|ref| ref.language == "Objective-C"}
			class_names = results.map {|ref| {'title' => ref.title, 'url' => ref.url}}
		else
			class_names = results.map {|ref| {'title' => "#{ref.language} #{ref.title}", 'url' => ref.url}}
		end
		class_names.sort! {|a, b| a['title'] <=> b['title']}
		url = get_user_selected_reference(class_names)
	end
	
	if url
		full = url =~ /^http:/ ? url : "file://#{url}"
		TextMate.exit_show_html "<meta http-equiv='Refresh' content='0;URL=#{full}'>"
	else
		TextMate.exit_discard  
	end
end

def man_page (query)
	pages = `man 2>&1 -S2:3 -w #{query}`
	if pages !~ /No manual entry/
		pages.split("\n").map { |e| $1 if e =~ %r{/#{query}\.(.*?)(\.gz)?$} }.sort.uniq.collect do |sect|
			page = `#{e_sh SUPPORT}/bin/html_man.sh #{sect} #{query}`
			puts "#{query}(#{sect})"
			Man.new(page, 'C', "#{query}(#{sect})")
		end
	else
		nil
	end
end

Cxx = Struct.new(:url, :language, :title, :klass)

def cxx_lookup (query)
  # find . -path './algorithm/start' -prune -or -type f -regex '\./.*/.*' -print|perl -pe 's|^./||; s|^algorithm/([a-z0-9_]+)$|$1\tstd::$1\thttp://www.cppreference.com/wiki/stl/$&|; s|^([a-z_]+)/start$|$1\tstd::$1\thttp://www.cppreference.com/wiki/stl/$&|; s|^([a-z_]+)/([a-z0-9_]+)$|$2\tstd::$1::$2\thttp://www.cppreference.com/wiki/stl/$&|'
  File.open("#{ENV['TM_BUNDLE_SUPPORT']}/CppReferenceWiki.tsf").grep(/^#{Regexp.escape query}\t([^\t]+)\t([^\t]+)$/) do
    Cxx.new($2, 'C++', $1, query)
  end
end

def get_user_selected_reference (class_names)
	#plist = {'menuItems' => class_names}.to_plist
	res = TextMate::UI.request_item({:items => class_names})
	#res = OSX::PropertyList::load(%x{"$DIALOG" -up #{e_sh plist} })	
	#res['selectedMenuItem'] ? res['selectedMenuItem']['url'] : nil
end

def search_docs_all(query)
  return nil if query.to_s.empty?

  results = search_docs(query)
  results.reject! { |e| e.url =~ %r{^/usr/share/man/|/ManPages/} }
  results.reject! { |e| e.language =~ /^Java(Script)?$/ }
  results = results.select { |e| e.exists? }

  man = man_page(query)
  results << man if man

  results << cxx_lookup(query)

  return results.flatten
end

def documentation_for_word
	query = ENV['TM_SELECTED_TEXT'] || ENV['TM_CURRENT_WORD']
	query = $& if query.to_s =~ /\w*/

	if query.to_s.empty?
		query = %x{ __CF_USER_TEXT_ENCODING=$UID:0x8000100:0x8000100 /usr/bin/pbpaste -pboard find }
		query = $& if query =~ /\w+/
		query = TextMate::UI.request_string :title => "Documentation Search", :default => query, :prompt => "Search documentation for word"    
		abort if query.nil?
	end

	results = search_docs_all(query)
	if results.nil? || results.empty?
		TextMate.exit_show_tool_tip "Cannot find documentation for: #{query}"
	else
		show_document(results, query)
	end
end

def documentation_for_selector
	lines = STDIN.readlines
	
	# selector = doc[(start_char + 1)...end_char]
	selector = lines.join(" ")[1..-2]
	
	# Whittle out everything but the selectors.
	selector.gsub!(/\n/m, ' ')                  # remove newlines
	selector.gsub!(/".*"\]/, ' ')               # remove any string constants (may hold :)
	selector.gsub!(/@selector\([^\)]+\)/, '')   # remove @selector()s
	selector.gsub!(/\[.*?\]/, ' ')              # remove nested messages
	query = selector.scan(/\w+:/).join

	if query == ''
		# Must have a message with no : in it, i.e. [fred init]
		query = selector[/\w+\s*$/]
	end

	results = search_docs(query)
	
	# Filter out the non Objective-C responses.
	results.delete_if {|r| r.language != 'Objective-C'}
	
	show_document(results, query)
end	

