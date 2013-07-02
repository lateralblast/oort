#!/usr/bin/env ruby

#!/usr/bin/env ruby

# Name:         goofball (Grep Oracle OBP Firmware)
# Version:      1.0.0
# Release:      1
# License:      Open Source
# Group:        System
# Source:       N/A
# URL:          http://lateralblast.com.au/
# Distribution: UNIX
# Vendor:       Lateral Blast
# Packager:     Richard Spindler <richard@lateralblast.com.au>
# Description:  Ruby script to Grep Oracle firmware site
#               http://www.oracle.com/technetwork/systems/patches/firmware/release-history-jsp-138416.html

require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'getopt/std'

firmware_urls={}
firmware_text={}
def search_firmware_page(search_model)
	doc=Nokogiri::HTML(open('http://www.oracle.com/technetwork/systems/patches/firmware/release-history-jsp-138416.html'))
	model=""
	urls=[]
	txts=[]
	firmware_urls={}
	firmware_text={}
	new_model=""
	text=""
	doc.css('div.pad5x10 p').each do |node|
		url=""
		if node.to_s.match(/name/)
			if node.css("a")[0]['name'].to_s.match(/[A-z]/)
				new_model=node.css("a")[0]['name']
				if search_model == "all" or node.css("a")[0]['name'].to_s.match(/#{search_model}/)
					if new_model != model
						if model.match(/[A-z]/)
							firmware_urls["#{model}"]=urls
							firmware_text["#{model}"]=txts
							urls=[]
							txts=[]
						end
						model=node.css("a")[0]['name'].to_s
					end
				end
			end
		else
			if node.content.to_s.match(/^[A-z]/) and !node.content.to_s.match(/download/) 
				text=node.content.to_s
				text=text.gsub(/\s+/,' ')
				if text.match(/[0-9,A-z]\(/)
					(head,tail)=text.split("(")
					text=head+" ("+tail
				end
			end
		end
		if node.to_s.match(/http/)
			if node.css("a")[0]['href'].to_s.match(/http/)
				url=node.css("a")[0]['href'].to_s
			end
			if search_model == "all" or new_model.match(/#{search_model}/)
				if url.match(/http/)
					urls.push(url)
					if text.match(/[A-z]/)
						if search_model == "all" or new_model.match(/#{search_model}/)
							if !txts.include?(text)
								txts.push(text)
							end
						end
					end
				end
			end
		end
	end
	if search_model != "all"
		firmware_urls["#{model}"]=urls
		firmware_text["#{model}"]=txts
	end	
	return firmware_urls,firmware_text
end

def print_usage()
	puts "Usage: "+$0+"-[h|V] -m [model]"
	puts
	puts "-V:       Display version information"
	puts "-h:       Display usage information"
	puts "-m all:   Display firmware information for all machines"
	puts "-m MODEL: Display firmware information for a specific model (eg. X2-4)"
end

def print_version()
	file_array=IO.readlines $0
	version=file_array.grep(/^# Version/)[0].split(":")[1].gsub(/^\s+/,'').chomp
	packager=file_array.grep(/^# Packager/)[0].split(":")[1].gsub(/^\s+/,'').chomp
	name=file_array.grep(/^# Name/)[0].split(":")[1].gsub(/^\s+/,'').chomp
	puts name+" v. "+version+" "+packager
end

begin
	opt=Getopt::Std.getopts("V?hm:")
rescue
	print_version()
	print_usage()
	exit
end

if opt["V"]
	print_version()
	exit
end

if opt["h"] or opt["?"]
	print_version()
	print_usage()
	exit
end

if opt["m"] == "all"
	model=opt["m"]
	(firmware_urls,firmware_text)=search_firmware_page(model)
	firmware_text.each do |model, text|
		puts model+":"
		counter=0
		firmware_text[model].each do
			puts firmware_text[model][counter]
			puts firmware_urls[model][counter]
			counter=counter+1
		end
	end
else
	model=opt["m"].upcase
	(firmware_urls,firmware_text)=search_firmware_page(model)
	counter=0
	puts model+":"
	firmware_text[model].each do
		puts firmware_text[model][counter]
		puts firmware_urls[model][counter]
		counter=counter+1
	end
end