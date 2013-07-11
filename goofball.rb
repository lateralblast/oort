#!/usr/bin/env ruby

# Name:         goofball (Grep Oracle OBP Firmware)
# Version:      0.1.4
# Release:      1
# License:      Open Source
# Group:        System
# Source:       N/A
# URL:          http://lateralblast.com.au/
# Distribution: UNIX
# Vendor:       Lateral Blast
# Packager:     Richard Spindler <richard@lateralblast.com.au>
# Description:  Ruby script to Grep Oracle firmware site
#               http//www.oracle.com/technetwork/systems/patches/firmware/release-history-jsp-138416.html

require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'getopt/std'

$work_dir=Dir.home+"/.goofball"
$verbose=0
$test_mode=0

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

def search_patchdiag_ref(search_string)
  doc=open_patchdiag_xref()
  result=doc.grep(/#{search_string}/)
  return(result)
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
    puts "Downloading: #{url}"
    puts "Destination: #{output_file}"
  end
  if !File.exists?(output_file)
    (mos_username,mos_password)=get_mos_details()
    if $test_mode == 0
      command="wget --http-user=\"#{mos_username}\" --http-passwd=\"#{mos_password}\" --no-check-certificate \"#{url}\" -q -O #{output_file}" 
      system(command)
    end
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
  fw_text=""
  ch_text=""
  module_text=""  
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
        fw_text=node.content.to_s.gsub(/\s+/,' ')
        if fw_text.match(/[0-9,A-z]\(/)
          (head,tail)=fw_text.split("(")
          fw_text=head+" ("+tail
        end
      else
        if node.content.to_s.match(/download/) 
          ch_text=node.content.to_s
          ch_text=ch_text.split(" download")[0].to_s
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
          if fw_text.match(/[A-z]/) or ch_text.match(/[A-z]/)
            if search_model == "all" or new_model.match(/#{search_model}/)
              if !txts.include?(text)
                text=fw_text+" "+ch_text
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
  puts "Usage: "+$0+"-[h|V] -[q|m|d|e|M] [MODEL|all] -[p|r] [PATCH] -[i|o] [FILE] -w [WORK_DIR] -t -v"
  puts
  puts "-V:          Display version information"
  puts "-h:          Display usage information"
  puts "-v:          Verbose output"
  puts "-t:          Test mode (don't perform downloads)"
  puts "-m all:      Display firmware information for all machines"
  puts "-d all:      Display firmware information for all disks"
  puts "-e all:      Display firmware information for all Emulex HBAs"
  puts "-q all:      Display firmware information for all Qlogic HBAs"
  puts "-m MODEL:    Display firmware information for a specific model (eg. X2-4)"
  puts "-M MODEL:    Download firmware patch for a specific model (eg. X2-4) from MOS (Requires Username and Password)"
  puts "-d MODEL:    Display firmware information for a specific model of disk (eg. MAW3300FC)"
  puts "-e MODEL:    Display firmware information for a specific model of Emulex HBA (eg. SG-XPCIEFCGBE-E8-Z)"
  puts "-q MODEL:    Display firmware information for a specific model of Qlogic HBA (eg. SG-XPCIEFCGBE-Q8-Z)"
  puts "-i FILE:     Open a locally saved HTML file for processing rather then fetching it"
  puts "-p PATCH:    Download a patch from MOS (Requires Username and Password)"
  puts "-r PATCH:    Download README for a patch from MOS (Requires Username and Password)"
  puts "-R PATCH:    Download README for a patch from MOS (Requires Username and Password) and send to STDOUT"
  puts "-P SEARCH:   Search patchdiag.xref"
  puts "-w WORK_DIR: Set work directory (Default is ~/.goofball)"
  puts "-c:          Output in CSV format"
  puts "-x:          Download patchdiag.xref"
  puts "-Z:          Update patch archive"
  puts "-S RELEASE:  Set Solaris release (used with -Z)"
  puts "-A RELEASE:  Set architecture (used with -Z)"
  puts "-o FILE:     Open a file for writing (CSV mode)"  
end

def print_version()
  file_array=IO.readlines $0
  version=file_array.grep(/^# Version/)[0].split(":")[1].gsub(/^\s+/,'').chomp
  packager=file_array.grep(/^# Packager/)[0].split(":")[1].gsub(/^\s+/,'').chomp
  name=file_array.grep(/^# Name/)[0].split(":")[1].gsub(/^\s+/,'').chomp
  puts name+" v. "+version+" "+packager
end

def get_oracle_download_url(patch_text,patch_url)
  base_url="https://getupdates.oracle.com/all_unsigned/"
  download_url=""
  head_url=""
  patch_no=""
  rev_text=""
  download_file=""
  if !patch_url.match(/index/)
    if patch_text.match(/XCP/)
      rev_text=patch_text.split(" ")[1].to_s
    else
      if patch_text.match(/Module/)
        rev_text=patch_text.split("Module ")[1].to_s.gsub(/\./,'')
      end
    end
    patch_no=patch_url.split("=")[1].to_s
    if patch_no.match(/\-/)
      download_file=patch_no+".zip"
      download_url=base_url+download_file
    else
      download_file="p"+patch_no+"_"+rev_text+"_Generic.zip"
      download_url=base_url+download_file
    end
  end
  return download_url,download_file
end

def download_firmware(model,firmware_urls,firmware_text)
  counter=0
  download_file=""
  firmware_text[model].each do
    patch_url=firmware_urls[model][counter]
    patch_text=firmware_text[model][counter]
    (download_url,download_file)=get_oracle_download_url(patch_text,patch_url)
    download_file=$work_dir+"/"+model+"/"+download_file
    get_oracle_download(download_url,download_file)
  end
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
    patch_url=firmware_urls[model][counter]
    patch_text=firmware_text[model][counter]
    (download_url,download_file)=get_oracle_download_url(patch_text,patch_url)
    if output_type == "CSV"
      output_text=model+","+firmware_text[model][counter]+","+firmware_urls[model][counter]+","+download_url+"\n"
    else
      output_text=firmware_text[model][counter]+"\n"+firmware_urls[model][counter]+"\n"+download_url+"\n"
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

def update_patch_archive(search_architecture,search_release)
  zip_file=""
  readme_file=""
  doc=open_patchdiag_xref()
  doc.each do |line|
    line.chomp
    if line.match(/^[0-9]/)
      (number,version,date,recommended,security,obsolete,bad,release,architecture,package,synopsis)=line.split("|")
      patch_no=number+"-"+version
      if !obsolete.match(/O/) and !bad.match(/[A-z]/) and !release.match(/Trusted/)
        if release.match(/Unbundled/)
          release="all"
        end
        if !architecture.match(/[A-z]/)
          architecture="all"
        end
        if release.match(/x86/) or architecture.match(/i386/)
          architecture="x86"
          release=release.split("_")[0]
        end
        if architecture.match(/sparc/)
          architecture="sparc"
        end
        if architecture.match(/#{search_architecture}/) or search_architecture.match(/all/)
          if release.match(/#{search_release}/) or search_release.match(/all/)
            zip_file=$work_dir+"/patches/"+architecture+"/"+release+"/"+patch_no+".zip"
            readme_file=$work_dir+"/readmes/"+architecture+"/"+release+"/README."+patch_no
            get_patch_readme(patch_no,readme_file)
            get_patch_file(patch_no,zip_file)
          end
        end
      else
        if $verbose == 1
          if obsolete.match(/O/)
            puts "Ignoring obsolete patch: "+patch_no
          else
            if bad.match(/[A-z]/)
              puts "Ignoring bad patch: "+patch_no
            else
              if release.match(/Trusted/)
                puts "Ignoring Tusted Solaris patch: "+patch_no
              end
            end
          end
        end
      end
    end
  end
end

begin
  opt=Getopt::Std.getopts("ZV?chtvxA:M:P:R:S:d:e:i:m:o:p:q:r:w:")
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

if opt["t"]
  $verbose=1
  $test_mode=1
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

if opt["x"]
  if opt["o"]
    $verbose=1
    output_file=opt["o"]
  else
    output_file=""
  end
  get_patchdiag_xref(output_file)
end

if opt["r"] or opt["p"] or opt["R"]
  if opt["p"]
    patch_no=opt["p"]
  else
    if opt["r"]
      patch_no=opt["r"]
    else
      patch_no=opt["R"]
    end
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
    if opt["R"]
      doc=open_patch_readme(patch_no)
      puts doc
    else
      get_patch_file(patch_no,output_file)
    end
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

if opt["Z"]
  if !opt["A"]
    search_architecture="all"
  else
    search_architecture=opt["A"]
  end
  if !opt["S"]
    search_release="all"
  else
    search_release=opt["S"]
  end
  update_patch_archive(search_architecture,search_release)
end


if opt["P"]
  search_string=opt["P"]
  search_result=search_patchdiag_ref(search_string)
  puts search_result
end

if opt["M"]
  model=opt["M"]
  if model != "all"
    model=model.upcase
    model=model.gsub(/K/,'000')
  end    
  (firmware_urls,firmware_text)=search_system_firmware_page(model,url)
  download_firmware(model,firmware_urls,firmware_text)
end
