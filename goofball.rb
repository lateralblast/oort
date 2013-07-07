#!/usr/bin/env ruby

# Name:         goofball (Grep Oracle OBP Firmware)
# Version:      0.0.8
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

$work_dir=Dir.home+"/.goofball"
$verbose=0

def search_disk_firmware_page(search_model,url)
  base_url="https://support.oracle.com/epmos/faces/ui/patch/PatchDetail.jspx?patchId="
  urls=[]
  txts=[]
  model=""
  firmware_urls={}
  firmware_text={}
  doc=open_patchdiag_xref()
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
              puts firmware_text
              puts firmware_urls
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

def search_qlogic_firmware_page(search_model,url)
  base_url="https://support.oracle.com/epmos/faces/ui/patch/PatchDetail.jspx?patchId="
  qlogic_url="http://driverdownloads.qlogic.com/QLogicDriverDownloads_UI/SearchByProductOracle.aspx?oemid=124&productid=928&OSTYPE=Solaris&category=3"
  firmware_text={}
  firmware_urls={}
  qf8_firmware=""
  if search_model.match(/all|8$/)
    doc=Nokogiri::HTML(open(qlogic_url))
    node=doc.search("[text()*='QF8']").each do |node|
      qf8_firmware=node.previous_element.text
    end
  end
  # Information from Sun System Handbook
  hba_info={}
  hba_info["SG-XPCIEFCGBE-Q8-Z"] = "8Gb/sec PCI Express Dual FC / Dual Gigabit Ethernet Host Adapter ExpressModule, QLogic"
  hba_info["SG-XPCIE2FC-QB4-Z"]  = "4Gb/sec PCI Express Dual Fibre Channel ExpressModule Host Adapter, QLogic"
  hba_info["SG-XPCIE2FCGBE-Q-Z"] = "4Gb/sec PCI Express Dual FC / Dual Gigabit Ethernet ExpressModule Host Adapter, QLogic"
  hba_info["SG-XPCI2FC-QF4-Z"]   = "4Gb PCI-X Dual FC Host Adapter"
  hba_info["SG-XPCIE1FC-QF8-Z"]  = "8Gigabit/Sec PCI Express Single FC Host Adapter"
  hba_info["SG-XPCIE2FC-QF8-Z"]  = "8Gigabit/Sec PCI Express Dual FC Host Adapter"
  hba_info["SG-XPCI1FC-QF4-Z"]   = "4Gb PCI-X Single FC Host Adapter"
  hba_info["SG-XPCIE1FC-QF4-Z"]  = "4Gigabit/Sec PCI Express Single FC Host Adapter"
  hba_info["SG-XPCIE2FC-QF4-Z"]  = "4Gigabit/Sec PCI Express Dual FC Host Adapter"
  urls=[]
  txts=[]
  search_list=[]
  doc=open_patchdiag_xref()
  if search_model.match(/all/)
    hba_info.each do |model|
      model=model[0]
      if model.match(/[A-z]/)
        search_list.push(model)
      end
    end
  else
    search_list[0]="#{search_model}"
  end
  search_list.each do |model|
    patch_no=""
    if model.match(/2$|2-Z$|4$|4-Z$|Q$|Q-Z$|all/)
      if model.match(/XPCI1FC-QF2|all/)
        patch_no="114873"
      end
      if model.match(/XPCI2FC-QF2|XPCI2FC-QF2|XPCI1FC-QL2|all/)
        patch_no="114874"
      end
      if model.match(/QF4|QB4|Q$|Q-Z$/)
        patch_no="123305"
      end
    end
    text=hba_info[model]
    if !model.match(/QF8|Q8/)
      if patch_no.match(/^[0-9]/)
        doc=open_patchdiag_xref()
        patch_info=doc.grep(/^#{patch_no}/)
        patch_info=patch_info[0].split("|")
        patch_no=patch_info[0]+"-"+patch_info[1]
        doc=open_patch_readme(patch_no) 
        fcode_info=doc.grep(/Unbundled Release/)
        fcode_info=fcode_info[0].split(": ")
        fcode_info=fcode_info[1].gsub(%r{</?[^>]+?>}, '').chomp
        patch_url=base_url+patch_no
        text=text+" "+fcode_info
      end
    else
      text=text+" Firmware Version "+qf8_firmware
      patch_url=qlogic_url
    end
    txts.push(text)
    urls.push(patch_url)
    firmware_urls[model]=urls
    firmware_text[model]=txts
    urls=[]
    txts=[]
  end
  return firmware_urls,firmware_text
end

def get_mos_details()
  mos_passwd_file=Dir.home+"/.mospasswd"
  if !File.exists?(mos_passwd_file)
    puts "Enter MOS Username:"
    STDOUT.flush
    mos_username=gets.chomp 
    puts "Enter MOS Password:"
    STDOUT.flush
    mos_password=gets.chomp 
  else
    mos_details=IO.readlines(mos_passwd_file)
    mos_details=mos_details[0].split(":")
    mos_username=mos_details[0]
    mos_password=mos_details[1].chomp
  end
  return mos_username,mos_password
end

def get_patch_full_id(patch_no)
  if !patch_no.match(/-/)
    doc=open_patchdiag_xref()
    patch_no=doc.grep(/^#{patch_no}/)
    patch_no=patch_no.split("|")
    patch_no=patch_no[0]+patch_no[1]
  end
  return(patch_no)
end

def get_patch_file(patch_no,output_file)
  base_url="https://getupdates.oracle.com/all_unsigned/"
  patch_no=get_patch_full_id(patch_no)
  if !output_file.match(/[A-z]/)
    output_file=$work_dir+"/"+patch_no+".zip"
  end
  url=base_url+patch_no+".zip"
  get_oracle_download(url,output_file)
end

def open_patch_readme(patch_no)
  patch_no=get_patch_full_id(patch_no)
  output_file=$work_dir+"/README."+patch_no
  get_patch_readme(patch_no,output_file)
  doc=IO.readlines(output_file)
  return doc 
end

def get_patch_readme(patch_no,output_file)
  base_url="https://getupdates.oracle.com/readme/"
  patch_no=get_patch_full_id(patch_no)
  if !output_file.match(/[A-z]/)
    output_file=$work_dir+"/README."+patch_no
  end
  url=base_url+patch_no
  get_oracle_download(url,output_file)
end

def get_oracle_download(url,output_file)
  if $verbose == 1
    puts "Fetching #{url} to #{output_file}"
  end
  if !File.exists?(output_file)
    (mos_username,mos_password)=get_mos_details()
    command="wget --http-user=\"#{mos_username}\" --http-passwd=\"#{mos_password}\" --no-check-certificate \"#{url}\" -q -O #{output_file}" 
    system(command)
  end
end

def open_patchdiag_xref()
  output_file=$work_dir+"/patchdiag.xref"
  get_patchdiag_xref(output_file)
  doc=IO.readlines(output_file)
  return(doc)
end

def get_patchdiag_xref(output_file)
  url="https://getupdates.oracle.com/reports/patchdiag.xref"
  if !output_file.match(/[A-z]/)
    output_file=$work_dir+"/patchdiag.xref"
  end
  if !File.exists?(output_file)
    # have to use wget as all modules break with akamai redirect
    # have tried all the TLS workarounds
    command="wget "+url+" -O "+output_file
    system(command)
  end
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
  puts "Usage: "+$0+"-[h|V] -[q|m|d|e] [MODEL|all] -i [FILE] -o [FILE] -w [WORK_DIR]"
  puts
  puts "-V:          Display version information"
  puts "-h:          Display usage information"
  puts "-m all:      Display firmware information for all machines"
  puts "-d all:      Display firmware information for all disks"
  puts "-e all:      Display firmware information for all Emulex HBAs"
  puts "-q all:      Display firmware information for all Qlogic HBAs"
  puts "-m MODEL:    Display firmware information for a specific model (eg. X2-4)"
  puts "-d MODEL:    Display firmware information for a specific model of disk (eg. MAW3300FC)"
  puts "-e MODEL:    Display firmware information for a specific model of Emulex HBA (eg. SG-XPCIEFCGBE-E8-Z)"
  puts "-q MODEL:    Display firmware information for a specific model of Qlogic HBA (eg. SG-XPCIEFCGBE-Q8-Z)"
  puts "-i FILE:     Open a locally saved HTML file for processing rather then fetching it"
  puts "-p PATCH:    Get a patch from MOS (Requires Username and Password)"
  puts "-r PATCH:    Get README for a patch from MOS (Requires Username and Password)"
  puts "-w WORK_DIR: Set work directory (Default is ~/.goofball)"
  puts "-c:          Output in CSV format"
  puts "-x:          Get patchdiag.xref"
  puts "-o FILE:     Open a file for writing (CSV mode)"  
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

def check_local_config
  if !Dir.exists?($work_dir)
    Dir.mkdir($work_dir)
  end    
end

begin
  opt=Getopt::Std.getopts("V?chvxd:e:i:m:o:p:q:r:w:")
rescue
  print_version()
  print_usage()
  exit
end

if opt ["m"]
  url="http://www.oracle.com/technetwork/systems/patches/firmware/release-history-jsp-138416.html"
else
  if opt["d"] or opt ["q"] 
    url="https://getupdates.oracle.com/reports/patchdiag.xref"
  else
    if opt["e"]
      url="http://www.emulex.com/downloads/oracle.html"
    end
  end
end

if opt["v"]
  $verbose=1
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

if opt["w"]
  $work_dir=opt["w"]
end
check_local_config()

if !opt["m"] and !opt["d"] and !opt["e"] and !opt["q"] and !opt["r"] and !opt["x"] and !opt["p"]
  print_usage
  exit
end

if opt["x"]
  if opt["o"]
    $verbose=1
    output_file=opt["o"]
  else
    output_file=""
  end
  get_patchdiag_xref(output_file)
end

if opt["r"] or opt["p"]
  if opt["p"]
    patch_no=opt["p"]
  else
    patch_no=opt["r"]
  end
  if !patch_no.match(/[0-9]/)
    puts "Invalid Patch Number"
    exit
  end
  if opt["o"]
    $verbose=1
    output_file=opt["o"]
  else
    output_file=""
  end
  if opt["r"]
    get_patch_readme(patch_no,output_file)
  else
    get_patch_file(patch_no,output_file)
  end
end

if opt["q"]
  model=opt["q"]
  if model != "all"
    model=model.upcase
  end    
  (firmware_urls,firmware_text)=search_qlogic_firmware_page(model,url)
  handle_output(model,firmware_urls,firmware_text,output_type,output_file)
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

