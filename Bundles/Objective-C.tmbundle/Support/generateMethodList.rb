#!/usr/bin/env ruby
# run with find /System/Library/Frameworks/*.framework -name \*.h -print0 | ruby generateMethodList.rb
translate = {"Message" => "Me",
"AddressBook" => "AB",
"SecurityFoundation" => "SF",
"QTKit" => "QT",
"IOBluetooth" => "Blue",
"WebKit" => "WK",
"SenTestingKit" => "Test",
"InstallerPlugins" => "Ins",
"CoreData" => "CD",
"Carbon" => "Ca",
"Automator" => "Au",
"SyncServices" => "Sync",
"AppKit" => "AK",
"InterfaceBuilder" => "IB",
"InstantMessage" => "IM",
"DiscRecording" => "DR",
"AppleScriptKit" => "ASK",
"SecurityInterface" => "SI",
"OSAKit" => "OSA",
"QuartzCore" => "CI",
"Foundation" => "F",
"AudioUnit" => "AU",
"ScreenSaver" => "Sav",
"Quartz" => "Q",
"PreferencePanes" => "Pref",
"ExceptionHandling" => "Exc",
"DiscRecordingUI" => "DRui",
"CoreAudioKit" => "CAK",
"XgridFoundation" => "Grid",
"IOBluetoothUI" => "BUI"}
require 'optparse'
require 'escape'

  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: example.rb [options]"

    opts.on("-c", "--classOutput FILENAME", "Run verbosely") do |v|
      options[:class] = v
    end
    opts.on("-m", "--methodOutput FILENAME", "Run verbosely") do |v|
      options[:method] = v
    end
    opts.on("-w", "--withCocoaAncestry FILENAME", "Run verbosely") do |v|
      options[:super] = v
    end
  end.parse!

def method_parse(k)
  l = k.scan /(\-|\+)\s*\((([^\(\)]|\([^\)]*\))*)\)|\((([^\(\)]|\([^\)]*\))*)\)\s*[a-zA-Z][a-zA-Z0-9]*|(([a-zA-Z][a-zA-Z0-9]*)?:)/
  types = l.select {|item| item[1] || item[3] }.collect{|item| (item[1] || item[3]).gsub(/(\w)\*/,'\1 *') }

  methodList = l.reject {|item| item[5].nil? }.collect{|item| item[5] }
  if methodList.size > 0
    methodName = methodList.join
  elsif mn = k.match(/\)\s*([a-zA-Z][a-zA-Z0-9]*)/)
    methodName = mn[1]
  else
    methodName = k.match(/([a-zA-Z][a-zA-Z0-9]*)/)[1]
  end  
  [methodName, types]
  
end
xlist = ["action:\tAK\tCl\tNSActionCell\tim\tvoid\tid",
 "alertDidEnd:returnCode:contextInfo:\tAK\tCl\tNSAlert\tim\tvoid\tNSAlert *\tint\tvoid *",
 "sheetDidEnd:returnCode:contextInfo:\tAK\tCl\tNSApplication\tim\tvoid\tNSWindow *\tint\tvoid *",
 "myCustomDrawMethod:\tAK\tCl\tNSCustomImageRep\tim\tvoid\tid",
 "document:didSave:contextInfo:\tAK\tCl\tNSDocument\tim\tvoid\tNSDocument *\tBOOL\tvoid *",
 "document:shouldClose:contextInfo:\tAK\tCl\tNSDocument\tim\tvoid\tNSDocument *\tBOOL\tvoid *",
 "didPresentErrorWithRecovery:contextInfo:\tAK\tCl\tNSDocument\tim\tvoid\tBOOL\tvoid *",
 "document:didPrint:contextInfo:\tAK\tCl\tNSDocument\tim\tvoid\tNSDocument *\tBOOL\tvoid *",
 "document:didRunPageLayoutAndUserAccepted:contextInfo:\tAK\tCl\tNSDocument\tim\tvoid\tNSDocument *\tBOOL\tvoid *",
 "document:didRunPrintOperation:contextInfo:\tAK\tCl\tNSDocument\tim\tvoid\tNSDocument *\tBOOL\tvoid *",
 "document:didSave:contextInfo:\tAK\tCl\tNSDocument\tim\tvoid\tNSDocument *\tBOOL\tvoid *",
 "document:didSave:contextInfo:\tAK\tCl\tNSDocument\tim\tvoid\tNSDocument *\tBOOL\tvoid *",
 "document:didSave:contextInfo:\tAK\tCl\tNSDocument\tim\tvoid\tNSDocument *\tBOOL\tvoid *",
 "document:didSave:contextInfo:\tAK\tCl\tNSDocument\tim\tvoid\tNSDocument *\tBOOL\tvoid *",
 "document:shouldClose:contextInfo:\tAK\tCl\tNSDocument\tim\tvoid\tNSDocument *\tBOOL\tvoid *",
 "documentController:didCloseAll:contextInfo:\tAK\tCl\tNSDocumentController\tim\tvoid\tNSDocumentController *\tBOOL\tvoid *",
 "didPresentErrorWithRecovery:contextInfo:\tAK\tCl\tNSDocumentController\tim\tvoid\tBOOL\tvoid *",
 "documentController:didReviewAll:contextInfo:\tAK\tCl\tNSDocumentController\tim\tvoid\tNSDocumentController *\tBOOL\tvoid *",
 "action:\tAK\tCl\tNSFontManager\tim\tvoid\tid",
 "action:\tAK\tCl\tNSMatrix\tim\tvoid\tid",
 "sortAction:\tAK\tCl\tNSMatrix\tim\tNSComparisonResult\tid",
 "editor:didCommit:contextInfo:\tAK\tCl\tNSObject\tim\tvoid\tid\tBOOL\tvoid *",
 "openPanelDidEnd:returnCode:contextInfo:\tAK\tCl\tNSOpenPanel\tim\tvoid\tNSSavePanel *\tint\tvoid *",
 "openPanelDidEnd:returnCode:contextInfo:\tAK\tCl\tNSOpenPanel\tim\tvoid\tNSSavePanel *\tint\tvoid *",
 "pageLayoutDidEnd:returnCode:contextInfo:\tAK\tCl\tNSPageLayout\tim\tvoid\tNSPageLayout *\tint\tvoid *",
 "printOperationDidRun:success:contextInfo:\tAK\tCl\tNSPrintOperation\tim\tvoid\tNSPrintOperation *\tBOOL\tvoid *",
 "printPanelDidEnd:returnCode:contextInfo:\tAK\tCl\tNSPrintPanel\tim\tvoid\tNSPrintPanel *\tint\tvoid *",
 "didPresentErrorWithRecovery:contextInfo:\tAK\tCl\tNSResponder\tim\tvoid\tBOOL\tvoid *",
 "savePanelDidEnd:returnCode:contextInfo:\tAK\tCl\tNSSavePanel\tim\tvoid\tNSSavePanel *\tint\tvoid *",
 "action:\tAK\tCl\tNSStatusItem\tim\tvoid\tid",
 "action:\tAK\tCl\tNSStatusItem\tim\tvoid\tid",
 "action:\tAK\tCl\tNSTableView\tim\tvoid\tid",
 "action:\tAK\tCl\tNSToolbarItem\tim\tvoid\tid",
 "action:\tAK\tCl\tNSBrowser\tim\tvoid\tid",
 "action:\tAK\tCl\tNSBrowser\tim\tvoid\tid",
 "action:\tAK\tCl\tNSColorPanel\tim\tvoid\tid",
 "editor:didCommit:contextInfo:\tAK\tCl\tNSController\tim\tvoid\tid\tBOOL\tvoid *",
 "action:\tAK\tCl\tNSMenu\tim\tvoid\tid",
 "action:\tAK\tCl\tNSMenu\tim\tvoid\tid",
 "action:\tAK\tCl\tNSMenu\tim\tvoid\tid",
 "action:\tAK\tCl\tNSMenuItem\tim\tvoid\tid",
 "action:\tAK\tCl\tNSMenuItem\tim\tvoid\tid",
 "action:\tAK\tCl\tNSPopUpButton\tim\tvoid\tid",
 "action:\tAK\tCl\tNSPopUpButtonCell\tim\tvoid\tid"]
#headers = %x{find /System/Library/Frameworks/*.framework -name \*.h}.split("\n")
headers = STDIN.read.split("\0")
#headers = ["test.h"]
rgxp = /^((@interface)|(@end)|((\-|\+)\s*\()|((\-|\+)[^;]*\;)|(@protocol[^\n;]*\n))/
list = []
hash = {}
classList = []
headers.each do |name|
  if mat = name.match(/(\w*)\.framework/)
    framework = mat[1]
  else
    framework = "Priv"
  end
  filename = name.match(/(\w*)\.h/)[1]
  unless framework == "JavaVM" || framework == "vecLib"
    #puts name
  open(name) do |file|
    str = file.read
    while m = str.match(rgxp)
      str = m[0] + m.post_match
      if m[2]
        k = str.match /@interface(?:\s|\n)+(\w+)(?:\s*:\s*(\w+))?[^\n]*/
        if k
        methodType = "dm" if k[0].match /\(\s*\w*[Dd]elegate\w*\s*\)/
          className = k[1]
          if translate[framework]
            frameworkName = translate[framework]
          else
            frameworkName = "NA"
          end
          if k[2] && k[2]!="" #&&  options[:super]
            hash[className] = {:super => k[2]}
          end
          classList << "#{className}"
          classType = "Cl"
          inClass = true
          
          str = k.post_match
        else
          str = m.post_match
        end
      elsif m[3]
        inClass = false
        str = m.post_match
      elsif m[4]
        k = str.match /[^;{]+?(;|\{)/
        if inClass && k
          methodName, types = method_parse(k[0])
          na = className
          na += ";#{filename}" unless className == filename
          methodType = {"+" => "cm", "-" => "im"}[m[5]] unless methodType == "dm"
          if translate[framework]
             frameworkName = translate[framework]
           else
             frameworkName = "NA"
           end
          list << "#{methodName}\t#{frameworkName}\t#{classType}\t#{na}\t#{methodType}\t#{types.join("\t")}"
          str = k.post_match
        else
          str = m.post_match
        end

      elsif m[6]
        if inClass
          methodName, t = method_parse(m[6])
          types = ["id"]
          types += t if t.size > 0
          na = className
          na += ";#{filename}" unless className == filename
          methodType = {"+" => "cm", "-" => "im"}[m[7]] unless methodType == "dm"
          if translate[framework]
             frameworkName = translate[framework]
          else
             frameworkName = "NA"
          end
            
          list << "#{methodName}\t#{frameworkName}\t#{classType}\t#{na}\t#{methodType}\t#{types.join("\t")}"
        end
        str = m.post_match
      elsif m[8]
        k = str.match /@protocol\s+(\w+)[^\n]*/
        if k
          className = k[1]
          classType = "Pr"
          inClass = true
          str = k.post_match
        end
      else
        str = m.post_match
      end
    end
  end
end
end
puts hash.inspect

if options.empty?
  print list.join("\n")
else
  if !hash.empty?
    classList = [] # clear classList
    require 'set'
    if options[:super]
      cocoaSet = %x{gunzip -c #{e_sh options[:super]} |cut -f1}.split("\n").to_set
      hash.keys.each do |name|
        if cocoaSet.include? hash[name][:super]
          hash[name][:cocoa] = true
        else
          hash[name][:cocoa] = false
        end
      end
    else
      hash["NSObject"] = {:super => nil}
      hash["NSProxy"] = {:super => nil}      
    end
    hash.keys.each do |name|
     
      tName = name
      tString = "#{name}\t#{name}:"
      i = 0
      until hash[tName].nil? || ((hash[tName][:cocoa] && options[:super])) || i > 10
        tName = hash[tName][:super]
        tString += "#{tName}:"
        i += 1
      end
      tString += hash[tName][:super] if hash[tName] && hash[tName][:cocoa]
      classList << tString
    end
  end
    File.open(options[:class],"w")do |f| f.write(classList.uniq.join("\n")) end unless options[:class].nil?
  File.open(options[:method],"w")do |f| f.write(list.join("\n")) end unless options[:method].nil?
end
 #s.split("\n").select{|a| a.match(/sel_of_type/)}.collect{|b| b.match(/"\(([^"]+)/)[0]}
p options
extra = '
cn = "" # use the xml exception files from BridgeSupport
list = []
l.each do |elem|
  cn = elem.match(/class name=("|\')(.+?)\1/)[2]
  ms = elem.split("\n").select{|a| a.match(/sel_of_type/)}.collect{|b| b.match(/sel_of_type="([^"]+)/)}
  if ms && !ms.empty?
    ms.each do |k|
      puts k[1]
      #.inspect
      methodName, types = method_parse("-" + k[1])
      list << "#{methodName}\tAK\tCl\t#{cn}\tim\t#{types.join("\t")}"
    end
  end
end
'

