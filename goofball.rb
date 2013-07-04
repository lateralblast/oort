#!/usr/bin/env ruby

# Name:         goofball (Grep Oracle OBP Firmware)
# Version:      0.0.3
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

url="http://www.oracle.com/technetwork/systems/patches/firmware/release-history-jsp-138416.html"

def search_firmware_page(search_model,url)
  if url.match(/http/)
    doc=Nokogiri::HTML(open(url))
  else
    doc=Nokogiri::HTML(File.open(url))
  end
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
        text=node.content.to_s.gsub(/\s+/,' ')
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
  puts "-i FILE:  Open a locally saved HTML file for processing rather then fetching it"
  puts "-c:       Output in CSV format"
  puts "-o FILE:  Open a file for writing (CSV mode)"  
end

def print_version()
  file_array=IO.readlines $0
  version=file_array.grep(/^# Version/)[0].split(":")[1].gsub(/^\s+/,'').chomp
  packager=file_array.grep(/^# Packager/)[0].split(":")[1].gsub(/^\s+/,'').chomp
  name=file_array.grep(/^# Name/)[0].split(":")[1].gsub(/^\s+/,'').chomp
  puts name+" v. "+version+" "+packager
end

def print_output(model,firmware_urls,firmware_text,output_type,output_file)
  counter=0
  if output_type != "CSV"
    output_text=model+":\n"
    if output_file.match(/[A-z,0-9]/)
      File.open(output_file, 'a') { |file| file.write(output_text) }
    else
      print output_text
    end
  end
  firmware_text[model].each do
    if output_type == "CSV"
      output_text=model+","+firmware_text[model][counter]+","+firmware_urls[model][counter]+"\n"
    else
      output_text=firmware_text[model][counter]+"\n"+firmware_urls[model][counter]+"\n"
    end
    if output_file.match(/[A-z,0-9]/)
      File.open(output_file, 'a') { |file| file.write(output_text) }
    else
      print output_text
    end
    counter=counter+1
  end
end

def handle_output(model,firmware_urls,firmware_text,output_type,output_file)
  if model == "all"
    firmware_text.each do |model, text|
      print_output(model,firmware_urls,firmware_text,output_type,output_file)
    end
  else
    print_output(model,firmware_urls,firmware_text,output_type,output_file)
  end
end

begin
  opt=Getopt::Std.getopts("V?chi:m:o:")
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

if opt["o"]
  output_file=opt["o"]
else
  output_file=""
end

if opt["i"]
  url=opt["i"] 
  if !File.exist?(url)
    puts "File "+url+" does not exist"
    exit
  end
end

if opt["c"]
  output_type="CSV"
else
  output_type="TXT"
end

if !opt["m"]
  opt["m"]="all"
end

if opt["m"]
  model=opt["m"]
  if model != "all"
    model=model.upcase
  end    
  (firmware_urls,firmware_text)=search_firmware_page(model,url)
  handle_output(model,firmware_urls,firmware_text,output_type,output_file)
end