#!/usr/bin/env ruby

# Name:         goofball (Grep Oracle OBP Firmware)
# Version:      0.0.5
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

def search_disk_firmware_page(search_model,url)
  base_url="https://support.oracle.com/epmos/faces/ui/patch/PatchDetail.jspx?patchId="
  output_file="patchdiag.xref"
  urls=[]
  txts=[]
  model=""
  firmware_urls={}
  firmware_text={}
  if url.match(/http/)
    # have to use wget as all modules break with akamai redirect
    # have tried all the TLS workarounds
    command="wget "+url+" -O "+output_file
    system(command)
    url=output_file
  end
  doc=IO.readlines(url)
  if search_model == "all"
    disk_info=doc.grep(/firmware$/)
  else
    disk_info=doc.grep(/#{search_model}/)
  end
  if disk_info.to_s.match(/[A-z]/)
    disk_info.each do |line|
      if line.match(/drive |Disk/)
        if line.match(/^[0-9]/)
          line=line.split("|")
          patch_no=line[0]+line[1]
          patch_text=line[10].chomp
          patch_url=base_url+"-"+patch_no
          model=patch_text.split(/\s+/) 
          if !model[-4].match(/6120/)
            if !model[-3].match(/k$/)
              model=model[-3]
              model=model.gsub(/[a-z]/,'')
            else
              model=model[-5]
            end
            if patch_text.match(/[A-z]/) and model
              urls.push(patch_url)
              txts.push(patch_text)
              firmware_text[model]=txts
              firmware_urls[model]=urls
              urls=[]
              txts=[]
            end
          end
        end
      end
    end
  end
  return firmware_urls,firmware_text
end

def search_emulex_firmware_page(search_model,url)
  urls=[]
  txts=[]
  model=""
  firmware_urls={}
  firmware_text={}
  if url.match(/http/)
    doc=Nokogiri::HTML(open(url))
  else
    doc=Nokogiri::HTML(File.open(url))
  end
  urls=[]
  txts=[]
  firmware_urls={}
  firmware_text={}
  doc.css("table td a").each do |node|
    model=""
    model=node.text
    if model.match(/#{search_model}/) or search_model == "all"
      suburl=node[:href]
      suburl="http://www.emulex.com/"+suburl 
      urls.push(suburl)
      firmware_urls[model]=urls
      urls=[]
      text=""
      subdoc=Nokogiri::HTML(open(suburl))
      subdoc.css("div.tab-body-inner h1").each do |subnode|
        if subnode.text.match(/Firmware/)
          text=subnode.text
        end
      end
      if !text.match(/[A-z]/)
        subdoc.css("div.tab-body-inner tbody p").each do |subnode|
          if subnode.text.match(/Firmware/)
            text=subnode.text
          end
        end
      end
      if !text.match(/[A-z]/)
        subdoc.css("div.csc-textpic-text li").each do |subnode|
          if subnode.text.match(/Firmware Version/)
            text=subnode.text
            text=text.split(/\s+/)
            text=text[0]+" "+text[1]+" "+text[2]
            text=text.gsub(/On/,'')
          end
        end
      end
      txts.push(text)
      firmware_text[model]=txts
      text=""
      txts=[]
    end
  end
  return firmware_urls,firmware_text
end

def search_system_firmware_page(search_model,url)
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
              firmware_urls[model]=urls
              firmware_text[model]=txts
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
  puts "-d all:   Display firmware information for all disks"
  puts "-e all:   Display firmware information for all Emulex HBAs"
  puts "-m MODEL: Display firmware information for a specific model (eg. X2-4)"
  puts "-d MODEL: Display firmware information for a specific model of disk (eg. MAW3300FC)"
  puts "-e MODEL: Display firmware information for a specific model of Emulex HBA (eg. SG-XPCIEFCGBE-E8-Z)"
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
  opt=Getopt::Std.getopts("V?chd:e:i:m:o:")
rescue
  print_version()
  print_usage()
  exit
end

if opt ["m"]
  url="http://www.oracle.com/technetwork/systems/patches/firmware/release-history-jsp-138416.html"
else
  if opt["d"]  
    url="https://getupdates.oracle.com/reports/patchdiag.xref"
  else
    if opt["e"]
      url="http://www.emulex.com/downloads/oracle.html"
    end
  end
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

if !opt["m"] and !opt["d"] and !opt["e"]
  print_usage
  exit
end

if opt["d"]
  model=opt["d"]
  if model != "all"
    model=model.upcase
  end    
  (firmware_urls,firmware_text)=search_disk_firmware_page(model,url)
  handle_output(model,firmware_urls,firmware_text,output_type,output_file)
end

if opt["e"]
  model=opt["e"]
  if model != "all"
    model=model.upcase
  end    
  (firmware_urls,firmware_text)=search_emulex_firmware_page(model,url)  
  handle_output(model,firmware_urls,firmware_text,output_type,output_file)
end

if opt["m"]
  model=opt["m"]
  if model != "all"
    model=model.upcase
    model=model.gsub(/K/,'000')
  end    
  (firmware_urls,firmware_text)=search_system_firmware_page(model,url)
  handle_output(model,firmware_urls,firmware_text,output_type,output_file)
end

