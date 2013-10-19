#!/usr/bin/env ruby

# Name:         goofball (Grep Oracle OBP Firmware)
# Version:      0.4.6
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
require 'selenium-webdriver'
require 'zipruby'
require 'fileutils'
require 'find'
require 'pathname'

class String
  def strip()
    self.chars.inject("") do |str, char|
      if char.ascii_only? and char.ord.between?(32,126)
        str << char
      end
      str
    end
  end
end

$work_dir=Dir.home+"/.goofball"
$verbose=0
$test_mode=0

def search_xcp_firmware_page(search_xcp)
  xcp_url="https://support.oracle.com/epmos/faces/DocContentDisplay?id=1002631.1"
  output_file=$work_dir+"/xcp.html"
  if !File.exists?(output_file)
    (mos_username,mos_password)=get_mos_details()
    browser=Selenium::WebDriver.for :safari
    browser.get xcp_url
    wait=Selenium::WebDriver::Wait.new(:timeout => 5)
    input=wait.until {
      element=browser.find_element(:name, "ssousername")
      element if element.displayed?
    }
    input.clear
    input.send_keys(mos_username)
    input=wait.until {
      element=browser.find_element(:name, "password")
      element if element.displayed?
    }
    input.send_keys(mos_password)
    browser.find_element(:class,"blt-txt").click
    wait.until {
      element=browser.find_element(:name, "f1")
    }
    output_text=browser.page_source
    browser.close
    File.open(output_file, 'w') { |file| file.write(output_text) }
  end
  xcp_release=""
  xcp_version=""
  xcp_post=""
  xcp_models=""
  xcp_info=""
  mseries=""
  ["M3000","M4000","M5000","M8000","M9000"].each do |mseries|
    eval("#{mseries}_txts=[]")
    eval("#{mseries}_urls=[]")
  end
  doc=Nokogiri::HTML(File.open(output_file))
  doc.css("td").each { |td| td.inner_html = td.inner_html.gsub(/\n/,'') }
  doc.css("td").each { |td| td.inner_html = td.inner_html.gsub(/<br>/,' ') }
  doc.css("td").each do |node|
    if node.text
      if node.text.match(/^XCP|^POST/)
        xcp_text=""
        xcp_info=node.text
        xcp_info=xcp_info.split(/\n/)
        xcp_info.each do |line|
          line=line.gsub(/\s+/,' ')
          line=line.gsub(/^\s+/,'')
          line=line.chomp
          line=line.strip
          if line.match(/[A-z]|[0-9]/) 
            if line.match(/^XCP/) and !line.match(/Release/) and !line.match(/XSCF/)
              xcp_release=line
              xcp_release=xcp_release.gsub(/ EOL/,'') 
              xcp_release=xcp_release.gsub(/\s+/,'') 
            else
              if line.match(/^0[0-9]/)
                xcp_version=line
              else
                if line.match(/^POST/) and line.match(/[0-9]/)
                  xcp_post=line
                else
                  if line.match(/ 20[0-9][0-9]/)
                    xcp_models=line
                    xcp_models=xcp_models.gsub(/ \- /,'')
                    xcp_models=xcp_models.gsub(/0M/,'0-M')
                  else
                    if xcp_version.match(/[0-9]/)
                      xcp_text="#{xcp_release} #{xcp_version} #{xcp_post} #{xcp_models}"
                      if xcp_text.match(/[A-z]/)
                        xcp_text=xcp_text.gsub(/\s+/,' ')
                        xcp_text=xcp_text.gsub(/\n/,'')
                        if xcp_text.match(/M3000/) and !xcp_text.match(/M3000\-/)
                          mseries="M3000"
                          eval("#{mseries}_txts.push(xcp_text)")
                          eval("#{mseries}_urls.push(xcp_url)")
                        end
                        if xcp_text.match(/M3000\-M9000/)
                          ["M3000","M4000","M5000","M8000","M9000"].each do |mseries|
                          eval("#{mseries}_txts.push(xcp_text)")
                          eval("#{mseries}_urls.push(xcp_url)")
                          end
                        end
                        if xcp_text.match(/M4000\-M9000/)
                          ["M4000","M5000","M8000","M9000"].each do |mseries|
                          eval("#{mseries}_txts.push(xcp_text)")
                          eval("#{mseries}_urls.push(xcp_url)")
                          end
                        end
                        if xcp_text.match(/M5000\-M9000/)
                          ["M5000","M8000","M9000"].each do |mseries|
                          eval("#{mseries}_txts.push(xcp_text)")
                          eval("#{mseries}_urls.push(xcp_url)")
                          end
                        end
                        if xcp_text.match(/M8000\-M9000/)
                          ["M8000","M9000"].each do |mseries|
                          eval("#{mseries}_txts.push(xcp_text)")
                          eval("#{mseries}_urls.push(xcp_url)")
                          end
                        end
                        xcp_release=""
                        xcp_version=""
                        xcp_post=""
                        xcp_models=""
                        xcp_info=""
                        xcp_text=""
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  firmware_text={}
  firmware_urls={}
  ["M3000","M4000","M5000","M8000","M9000"].each do |mseries|
    firmware_text[mseries]=eval("#{mseries}_txts")
    firmware_urls[mseries]=eval("#{mseries}_urls")
  end
  return firmware_urls,firmware_text
end

def search_disk_firmware_page(search_model,url)
  base_url="https://support.oracle.com/epmos/faces/ui/patch/PatchDetail.jspx?patchId="
  urls=[]
  txts=[]
  model=""
  firmware_urls={}
  firmware_text={}
  doc=open_patchdiag_xref()
  if search_model == "all"
    disk_info=doc.grep(/Disk/)
  else
    disk_info=doc.grep(/#{search_model}/)
  end
  if disk_info.to_s.match(/[A-z]/)
    disk_info.each do |line|
      line=line.split("|")
      patch_no=line[0]+"-"+line[1]
      doc=open_patch_readme(patch_no) 
      doc.each do |readme_line|
        patch_text=line[10].chomp
        patch_url=base_url+patch_no
        readme_line.chomp
        if readme_line.match(/\.fw/)
          readme_line=readme_line.gsub(/^\s+/,'')
          readme_line=readme_line.gsub(/,/,'')
          if readme_line.match(/\s+/)
            firmware_info=readme_line.split(/\s+/)
            if firmware_info[0].match(/fw$/) and firmware_info[0].match(/^[A-Z]/)
              firmware_info=firmware_info[0].split(/\./)
              model=firmware_info[0]
              firmware_rev=firmware_info[1]
              if patch_text.match(/[A-z]/) and model.match(/[A-z]|[0-9]/)
                urls.push(patch_url)
                patch_text=patch_text+" ("+firmware_rev+")"
                txts.push(patch_text)
                firmware_urls[model]=urls
                firmware_text[model]=txts 
                urls=[]
                txts=[]
              end
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
  # Fetch file and process locally
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
  puts "Enter MOS Username:"
  STDOUT.flush
  mos_username=gets.chomp 
  puts "Enter MOS Password:"
  STDOUT.flush
  mos_password=gets.chomp 
  return mos_username,mos_password
end

def get_patch_full_id(patch_no)
  if !patch_no.match(/-/)
    doc=open_patchdiag_xref()
    patch_no=doc.grep(/^#{patch_no}/)
    patch_no=patch_no.join.split("|")
    patch_no=patch_no[0]+"-"+patch_no[1]
  end
  return patch_no
end

def search_patchdiag_ref(search_string)
  doc=open_patchdiag_xref()
  result=doc.grep(/#{search_string}/)
  return result
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

def create_mos_passwd_file(mos_username,mos_password)
  FileUtils.touch(mos_passwd_file)
  File.chmod(0700,mos_passwd_file)
  output_text="http-user="+mos_username+"\n"
  File.open(mos_passwd_file, 'a') { |file| file.write(output_text) }
  output_text="http-passwd="+mos_password+"\n"
  File.open(mos_passwd_file, 'a') { |file| file.write(output_text) }
  output_text="check-certificate=off\n"
  File.open(mos_passwd_file, 'a') { |file| file.write(output_text) }
  File.close(mos_passwd_file)
end

def get_oracle_download(url,output_file)
  if $verbose == 1
    puts "Downloading: #{url}"
    puts "Destination: #{output_file}"
  end
  if !File.exists?(output_file)
    output_dir=File.dirname(output_file)
    if !Dir.exists?(output_dir)
      Dir.mkdir(output_dir)
    end
    if $test_mode == 0
      mos_passwd_file=Dir.home+"/.mospasswd"
      if !File.exists?(mos_passwd_file)
        (mos_username,mos_password)=get_mos_details()
        create_mos_passwd_file(mos_username,mos_password)
      end
      if $verbose == 1
        command="export WGETRC="+mos_passwd_file+"; wget --no-check-certificate "+"\""+url+"\""+" -O "+"\""+output_file+"\"" 
      else
        command="export WGETRC="+mos_passwd_file+"; wget --no-check-certificate "+"\""+url+"\""+" -q -O "+"\""+output_file+"\"" 
      end
      system(command)
    end
  else
    if $verbose == 1
      puts "File: #{output_file} already exists" 
    end
  end
  return
end

def open_patchdiag_xref()
  output_file=$work_dir+"/patchdiag.xref"
  get_patchdiag_xref(output_file)
  doc=IO.readlines(output_file)
  return doc
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
  else
    if $verbose == 1
      puts "File: output_file already exists" 
    end
  end
  return
end

def search_emulex_firmware_page(search_model,url)
  urls=[]
  txts=[]
  model=""
  firmware_urls={}
  firmware_text={}
  if url.match(/http/)
    output_file=$work_dir+"/firmware.html"
    get_oracle_download(url,output_file)
    doc=Nokogiri::HTML(File.open(output_file))
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
      text=""
      new_text=""
      subdoc=Nokogiri::HTML(open(suburl))
      subdoc.css("div.tab-body-inner h1").each do |subnode|
        if subnode.text.match(/Firmware|Universal/) and subnode.text.match(/[0-9]/)
          new_text=subnode.text
          if !text.match(/#{new_text}/) and new_text.match(/[A-z]/)
            if !text.match(/[A-z]/)
              text=new_text
            else
              text=text+" "+new_text
            end
          end
        end
      end
      if !text.match(/[A-z]/)
        subdoc.css("div.tab-body-inner tbody p").each do |subnode|
          if subnode.text.match(/Firmware|Universal/) and subnode.text.match(/[0-9]/)
            new_text=subnode.text
            if !text.match(/#{new_text}/) and new_text.match(/[A-z]/)
              if !text.match(/[A-z]/)
                text=new_text
              else
                text=text+" "+new_text
              end
            end
          end
        end
      end
      if !text.match(/[A-z]/)
        subdoc.css("div.csc-textpic-text li").each do |subnode|
          if subnode.text.match(/Firmware|Universal/) and subnode.text.match(/[0-9]/)
            new_text=subnode.text
            new_text=new_text.split(/\s+/)
            new_text=new_text[0]+" "+new_text[1]+" "+new_text[2]
            new_text=new_text.gsub(/On/,'')
            if !text.match(/#{new_text}/) and new_text.match(/[A-z]/)
              if !text.match(/[A-z]/)
                text=new_text
              else
                text=text+" "+new_text
              end
            end
          end
        end
      end
      text=text.gsub(/\s+/,' ')
      text=text.gsub(/\s+$/,'')
      txts.push(text)
      if !txts[0].match(/Firmware/)
        txts[0]="Frimware Version Unknown"
      end
      if model.match(/ /)
        model=model.split(/ /)
        model.each do |new_model|
          firmware_text[new_model]=txts
          firmware_urls[new_model]=urls
        end
      else
        if model.match(/[0-9]SG|ZSG/)
          model=model.split(/SG/)
          new_model="SG"+model[1]
          firmware_text[new_model]=txts
          firmware_urls[new_model]=urls
          new_model="SG"+model[2]
          firmware_text[new_model]=txts
          firmware_urls[new_model]=urls
        else
          firmware_text[model]=txts
          firmware_urls[model]=urls
        end
      end
      text=""
      txts=[]
      urls=[]
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
  urls=[]
  txts=[]
  firmware_urls={}
  firmware_text={}
  text=""
  model=""
  new_model=""
  fw_text=""
  ch_text=""
  counter=0
  module_text=""  
  rows=doc.css('table tr')
  rows.each do |row|
    info=""
    url=""
    name=row.css('a').map{|td| td[:name]}
    if name[0]
      if name[0].match(/[A-z]|[0-9]/)
        new_model=name[0]
        counter=counter+1
      end
    end
    if !model.match(/[A-z]|[0-9]/)
      model=new_model
    end
    info=row.content.to_s
    info=info.gsub(/\s+ /,' ')
    info=info.gsub(/^\s+ /,'')
    info=info.gsub(/ $/,'')
    info=info.gsub(/ download/,'')
    if info.match(/[0-9,A-z]\(/)
      (head,tail)=info.split("(")
      info=head+" ("+tail
    end
    links=row.css('a').map{|td| td[:href]}
    links.each do |link|
      if link
        if link.match(/http/) and link.match(/[0-9]/)
          url=link
        end
      end
    end
    if new_model.match(/[A-z]|[0-9]/)
      if new_model != model
        firmware_text[model]=txts
        firmware_urls[model]=urls
        txts=[]
        urls=[]
        txts.push(info)
        urls.push(url)
        model=new_model
      else
        if info.match(/[0-9]/) and url.match(/http/) and !info.match(/HW Programmables 1.0.0/)
          if counter > 1
            txts.push(info)
            urls.push(url)
          end
        end
      end
    end
  end
  if search_model != "all"
    if urls.grep(/[A-z]|[0-9]/)
      firmware_urls["#{model}"]=urls
    end
    if txts.grep(/[A-z]|[0-9]/)
      firmware_text["#{model}"]=txts
    end
  end 
  ['NT3-1BA','CP3010','CP3020','CP3060','CP3220','CP3250','CP3260','CP3270'].each do |member|
    firmware_text[member]=firmware_text["CT900"]
    firmware_urls[member]=firmware_urls["CT900"]
  end
  ['8000P','X8400','X8420','X8440','X8450'].each do |member|
    firmware_text[member]=firmware_text["8000"]
    firmware_urls[member]=firmware_urls["8000"]
  end
  ['X4240','X4440'].each do |member|
    firmware_text[member]=firmware_text["X4140"]
    firmware_urls[member]=firmware_urls["X4140"]
  end
  ['X4270','X4275'].each do |member|
    firmware_text[member]=firmware_text["X4170"]
    firmware_urls[member]=firmware_urls["X4170"]
  end
  firmware_text["T5120"]=firmware_text["T5220"]
  firmware_urls["T5120"]=firmware_urls["T5220"]
  firmware_text["T5140"]=firmware_text["T5240"]
  firmware_urls["T5140"]=firmware_urls["T5240"]
  firmware_text["X4200"]=firmware_text["X4100"]
  firmware_urls["X4200"]=firmware_urls["X4100"]
  firmware_text["X4200M2"]=firmware_text["X4100M2"]
  firmware_urls["X4200M2"]=firmware_urls["X4100M2"]
  firmware_text["X4170M3"]=firmware_text["X3-2"]
  firmware_urls["X4170M3"]=firmware_urls["X3-2"]
  firmware_text["X4270M3"]=firmware_text["X3-2L"]
  firmware_urls["X4270M3"]=firmware_urls["X3-2L"]
  firmware_text["X4470M2"]=firmware_text["X2-4"]
  firmware_urls["X4470M2"]=firmware_urls["X2-4"]
  firmware_text["X4800M2"]=firmware_text["X2-8"]
  firmware_urls["X4800M2"]=firmware_urls["X2-8"]
  firmware_text["X4270M3"]=firmware_text["X3-2"]
  firmware_urls["X4270M3"]=firmware_urls["X3-2"]
  firmware_text["X6270M3"]=firmware_text["X3-2B"]
  firmware_urls["X6270M3"]=firmware_urls["X3-2B"]
  firmware_text["NX6270M3"]=firmware_text["NX3-2B"]
  firmware_urls["NX6270M3"]=firmware_urls["NX3-2B"]
  return firmware_urls,firmware_text
end

def print_usage()
  puts "Usage: "+$0+" -[h|V] -[q|m|d|e|M] [MODEL|all] -[p|r] [PATCH] -[i|o] [FILE] -w [WORK_DIR] -t -v"
  puts
  puts "-V:          Display version information"
  puts "-h:          Display usage information"
  puts "-v:          Verbose output"
  puts "-b:          Test mode (don't perform downloads)"
  puts "-m all:      Display firmware information for all machines"
  puts "-z all:      Display firmware zip file contents for all models"
  puts "-t all:      Display TFTP file for all models"
  puts "-M all:      Download firmware patch for all models from MOS (Requires Username and Password)"
  puts "-d all:      Display firmware information for all disks"
  puts "-e all:      Display firmware information for all Emulex HBAs"
  puts "-q all:      Display firmware information for all Qlogic HBAs"
  puts "-X all:      Display firmware information for all M Series"
  puts "-m MODEL:    Display firmware information for a specific model (eg. X2-4)"
  puts "-z MODEL:    Display firmware zip file contents for a specific model (eg. X2-4)"
  puts "-t MODEL:    Display TFTP file for a specfic model (e.g. T5440)"
  puts "-M MODEL:    Download firmware patch for a specific model (eg. X2-4) from MOS (Requires Username and Password)"
  puts "-d MODEL:    Display firmware information for a specific model of disk (eg. MAW3300FC)"
  puts "-e MODEL:    Display firmware information for a specific model of Emulex HBA (eg. SG-XPCIEFCGBE-E8-Z)"
  puts "-q MODEL:    Display firmware information for a specific model of Qlogic HBA (eg. SG-XPCIEFCGBE-Q8-Z)"
  puts "-X MODEL:    Display firmware information for specific M Series model (e.g. M3000)"
  puts "-i FILE:     Open a locally saved HTML file for processing rather then fetching it"
  puts "-p PATCH:    Download a patch from MOS (Requires Username and Password)"
  puts "-r PATCH:    Download README for a patch from MOS (Requires Username and Password)"
  puts "-R PATCH:    Download README for a patch from MOS (Requires Username and Password) and send to STDOUT"
  puts "-P SEARCH:   Search patchdiag.xref"
  puts "-w WORK_DIR: Set work directory (Default is ~/.goofball)"
  puts "-c:          Output in CSV format"
  puts "-x:          Download patchdiag.xref"
  puts "-l:          Only show latest firmware versions (used with -m)"
  puts "-Y:          Update patch archive"
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

def get_oracle_download_url(model,patch_text,patch_url)
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
      if patch_text.match(/8000P Chassis Monitoring Module/)
        rev_text=patch_text.split(" ")[-1].to_s
        rev_text=rev_text.gsub(/\./,'')
      else
        if patch_text.match(/Module/)
          if !patch_text.match(/RAID/)
            rev_text=patch_text.split("Module ")[1].to_s.gsub(/\./,'')
          else
            rev_text=patch_text.split("Module ")[2].to_s.gsub(/\./,'')
          end
        else
          if patch_text.match(/Workstation/)
            rev_text=patch_text.split("Workstation ")[1].to_s.gsub(/\./,'')
          else
            if patch_text.match(/Server/) and !patch_text.match(/SysFW/)
              rev_text=patch_text.split("Server ")[1].to_s.gsub(/\./,'')
            else
              if patch_text.match(/SysFW/)
                rev_text=patch_text.split("SysFW ")[1].to_s
                rev_text=rev_text.split(".")[0]+rev_text.split(".")[1]
              else
                if patch_text.match(/LSI/)
                  rev_text=patch_text.split(" ")[3].gsub(/\./,'')
                end
              end
            end
          end
        end
      end
    end
    patch_no=patch_url.split("=")[1].to_s
    if patch_no.match(/\-/)
      download_file=patch_no+".zip"
      download_url=base_url+download_file
    else
      if !patch_text.match(/SysFW/) and !model.match(/U24|X4800|X2250|X2270M2|X6450|X6250|X6275/)
        if rev_text.length < 3
          rev_text=rev_text+"0"
        end
      end
      download_file="p"+patch_no+"_"+rev_text+"_Generic.zip"
      download_url=base_url+download_file
    end
  end
  return download_url,download_file
end

def download_firmware(model,firmware_urls,firmware_text,latest_only,counter)
  download_file=""
  wrong_file=""
  patch_url=firmware_urls[model][counter]
  patch_text=firmware_text[model][counter]
  (download_url,file_name)=get_oracle_download_url(model,patch_text,patch_url)
  download_file=$work_dir+"/"+model.downcase+"/"+file_name
  if !File.exists?(download_file)
    existing_file=$file_list.select {|existing_file| existing_file =~ /#{file_name}/}
    if existing_file[0]
      existing_file=existing_file[0]
      if $verbose == 1
        puts "Found "+existing_file+"\n"
        puts "Symlinking "+existing_file+" to "+download_file+"\n"
      end
      dir_name=Pathname.new(download_file)
      dir_name=dir_name.dirname
      if !Dir.exists?(dir_name)
        Dir.mkdir(dir_name)
      end
      File.symlink(existing_file,download_file)
    else 
      get_oracle_download(download_url,download_file)
    end
  end
  return
end

def list_zipfile(model,firmware_urls,firmware_text,search_suffix,output_type,output_file,counter)
  download_file=""
  output_text=""
  firmware_data=""
  patch_url=firmware_urls[model][counter]
  patch_text=firmware_text[model][counter]
  if patch_url and patch_text
    (download_url,download_file)=get_oracle_download_url(model,patch_text,patch_url)
    download_file=$work_dir+"/"+model.downcase+"/"+download_file
    get_oracle_download(download_url,download_file)
    if !File.exists?(download_file)
      puts "File: "+download_file+" does not exist"
      return
    end
    puts model+":"
    Zip::Archive.open(download_file) do |archive|
      entry_names=archive.map do |file|
        if search_suffix.match(/[A-z]/)
          if search_suffix.match(/pkg/)
            if file.name.match(/pkg$|bin$|iso$|Ultra[0-9][0-9]$|[0-9][0-9][0-9][0-9]\.tar\.gz|[0-9][0-9][0-9]\.zip/)
              tftp_name=File.basename(file.name)
              if !tftp_name.match(/legal|remote|recovery|^fw|^q8|^firmware/)
                tftp_file=File.dirname(download_file)
                tftp_file=tftp_file+"/"+file.name
                if output_type == "CSV"
                  patch_text=patch_text.to_s.split(" ")
                  puts model.downcase+patch_text[0]+"\n"
                  if patch_text[0].match(/^ILOM/)
                    firmware_data=","+patch_text[1]+","+tftp_name+","+patch_text[2]
                    case
                    when model.downcase.match(/^x4150$/)
                      output_text="x4150"+firmware_data+"\n"+"x4250"+firmware_data+"\n"
                    else
                      output_text=model.downcase+firmware_data+"\n"
                    end
                  end
                  if patch_text[0].match(/^Sun System Firmware/)
                    firmware_data=","+patch_text[7]+","+tftp_name+","+patch_text[-1]
                    output_text=model.downcase+firmware_data+"\n"
                  end
                  if patch_text[0].match(/^SysFW|^XCP/)
                    if model.match(/[T,M][1-9][0-3][0,-][0-9]/)
                      firmware_data=",,"+tftp_name+","+patch_text[-1]
                      output_text=model.downcase+firmware_data+"\n"
                    else
                      firmware_data=","+patch_text[5].gsub(/\)/,'')+","+tftp_name+","+patch_text[1]
                      case
                      when model.downcase.match(/^t5220$/)
                        output_text="t5120"+firmware_data+"\n"+"t5220"+firmware_data+"\n"
                      when model.downcase.match(/^t5240$/)
                        output_text="t5140"+firmware_data+"\n"+"t5240"+firmware_data+"\n"
                      else
                        output_text=model.downcase+firmware_data+"\n"
                      end
                    end
                  end
                  if output_file.match(/[A-z,0-9]/)
                    File.open(output_file, 'a') { |file| file.write(output_text) }
                  else
                    print output_text
                  end
                else
                  output_text="TFTP file: "+tftp_name+"\n"+"Location:  "+tftp_file+"\n"
                  if output_file.match(/[A-z,0-9]/)
                    File.open(output_file, 'a') { |file| file.write(output_text) }
                  else
                    print output_text
                  end
                end
              end
            end
          end
        else
          if output_type == "CSV"
            output_text=model+","+file.name+"\n"
          else
            output_text=file.name+"\n"
          end
          if output_file.match(/[A-z,0-9]/)
            File.open(output_file, 'a') { |file| file.write(output_text) }
           else
             print output_text
           end
        end
      end
    end
  end
  return
end

def handle_download_firmware(search_model,firmware_urls,firmware_text,latest_only)
  counter=0
  if search_model == "all"
    firmware_text.each do |model, text|
      if $verbose == 1
        puts model+":"
      end
      if latest_only == 1
        download_firmware(model,firmware_urls,firmware_text,latest_only,counter)
      else
        counter=0
        firmware_text[model].each do
          download_firmware(model,firmware_urls,firmware_text,latest_only,counter)
          counter=counter+1
        end
      end
    end
  else
    if $verbose == 1
      puts search_model+":"
    end
    if latest_only == 1
      download_firmware(search_model,firmware_urls,firmware_text,latest_only,counter)
    else
      firmware_text[search_model].each do
        download_firmware(search_model,firmware_urls,firmware_text,latest_only,counter)
        counter=counter+1
      end
    end
  end
  return
end

def handle_zipfile(search_model,firmware_urls,firmware_text,search_suffix,output_type,output_file,latest_only)
  counter=0
  if search_model == "all"
    firmware_text.each do |model, text|
      if $verbose == 1
        puts model+":"
      end
      if latest_only == 1
        list_zipfile(model,firmware_urls,firmware_text,search_suffix,output_type,output_file,counter)
      else
        counter=0
        firmware_text[model].each do
          list_zipfile(model,firmware_urls,firmware_text,search_suffix,output_type,output_file,counter)
          counter=counter+1
        end
      end
    end
  else
    if $verbose == 1
      puts search_model+":"
    end
    if latest_only == 1
      list_zipfile(search_model,firmware_urls,firmware_text,search_suffix,output_type,output_file,counter)
    else
      firmware_text[search_model].each do
        list_zipfile(search_model,firmware_urls,firmware_text,search_suffix,output_type,output_file,counter)
        counter=counter+1
      end
    end
  end
  return
end

def print_output(model,firmware_urls,firmware_text,output_type,output_file,latest_only)
  counter=0
  txts=[]
  urls=[]
  if !firmware_text[model]
    puts "Model: #{model} does not exist"
    return
  end
  if latest_only == 1
    text=firmware_text[model][0]
    txts.push(text)
    firmware_text[model]=txts
    link=firmware_urls[model][0]   
    urls.push(link)
    firmware_urls[model]=urls
  end
  if output_type != "CSV"
    output_text=model+":\n"
    if output_file.match(/[A-z,0-9]/)
      File.open(output_file, 'w') { |file| file.write(output_text) }
    else
      print output_text
    end
  end
  firmware_text[model].each do
    patch_url=firmware_urls[model][counter]
    patch_text=firmware_text[model][counter]
    if !patch_url.match(/emulex|1002631/)
      (download_url,download_file)=get_oracle_download_url(model,patch_text,patch_url)
    else
      download_url=""
    end
    if output_type == "CSV"
      output_text=model+","+firmware_text[model][counter]+","+firmware_urls[model][counter]+","+download_url+"\n"
    else
      if download_url.match(/[A-z]/)
        output_text=firmware_text[model][counter]+"\n"+firmware_urls[model][counter]+"\n"+download_url+"\n"
      else
        output_text=firmware_text[model][counter]+"\n"+firmware_urls[model][counter]+"\n"
      end
    end
    if output_file.match(/[A-z,0-9]/)
      File.open(output_file, 'a') { |file| file.write(output_text) }
    else
      print output_text
    end
    counter=counter+1
  end
  return
end

def handle_output(model,firmware_urls,firmware_text,output_type,output_file,latest_only)
  if model == "all"
    firmware_text.each do |model, text|
      print_output(model,firmware_urls,firmware_text,output_type,output_file,latest_only)
    end
  else
    print_output(model,firmware_urls,firmware_text,output_type,output_file,latest_only)
  end
  return
end

def check_repository
  $file_list.each do |file_name|
    if File.exists?(file_name)
      if File.size(file_name) == 0
        if $verbose == 1
          puts "Deleting empty file "+file_name+"\n"
        end
        File.delete(file_name)
      end
    end
  end
end

def check_local_config
  if !Dir.exists?($work_dir)
    Dir.mkdir($work_dir)
  end
  return
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
  return
end

begin
  opt=Getopt::Std.getopts("VZ?bchlvxA:M:P:R:S:X:d:e:i:m:o:p:q:r:t:w:z:")
rescue
  print_version()
  print_usage()
  exit
end

if opt["w"]
  $work_dir=opt["w"]
end

if opt["M"]
  $file_list=[]
  Find.find($work_dir) {|file_name| $file_list.push(file_name) if File.file?(file_name)}
  check_repository()
end

if opt["m"] or opt["M"] or opt["t"]
  url="http://www.oracle.com/technetwork/systems/patches/firmware/release-history-jsp-138416.html"
  if File.exists?(File.basename(url))
    url=File.basename(url)
  end
else
  if opt["d"] or opt ["q"] 
    url="https://getupdates.oracle.com/reports/patchdiag.xref"
    if File.exists?(File.basename(url))
      url=File.basename(url)
    end
  else
    if opt["e"]
      url="http://www.emulex.com/downloads/oracle.html"
      if File.exists?(File.basename(url))
        url=File.basename(url)
      end
    end
  end
end

if opt["l"]
  latest_only=1
end

if opt["v"]
  $verbose=1
end

if opt["b"]
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
  handle_output(model,firmware_urls,firmware_text,output_type,output_file,latest_only)
end

if opt["d"]
  model=opt["d"]
  if model != "all"
    model=model.upcase
  end    
  (firmware_urls,firmware_text)=search_disk_firmware_page(model,url)
  handle_output(model,firmware_urls,firmware_text,output_type,output_file,latest_only)
end

if opt["e"]
  model=opt["e"]
  if model != "all"
    model=model.upcase
  end    
  (firmware_urls,firmware_text)=search_emulex_firmware_page(model,url)  
  handle_output(model,firmware_urls,firmware_text,output_type,output_file,latest_only)
end

if opt["m"]
  model=opt["m"]
  if model != "all"
    model=model.upcase
    model=model.gsub(/K/,'000')
  end    
  (firmware_urls,firmware_text)=search_system_firmware_page(model,url)
  handle_output(model,firmware_urls,firmware_text,output_type,output_file,latest_only)
end

if opt["z"] or opt["t"]
  if opt["z"]
    model=opt["z"]
    search_suffix=""
  end
  if opt["t"] or opt["o"]
    model=opt["t"]
    search_suffix="pkg"
  end
  if model != "all"
    model=model.upcase
    model=model.gsub(/K/,'000')
  end    
  (firmware_urls,firmware_text)=search_system_firmware_page(model,url)
  handle_zipfile(model,firmware_urls,firmware_text,search_suffix,output_type,output_file,latest_only)
end

if opt["Y"]
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
  handle_download_firmware(model,firmware_urls,firmware_text,latest_only)
end

if opt["X"]
  model=opt["X"]
  if model != "all"
    model=opt["X"]
    model=model.upcase
    model=model.gsub(/K/,'000')
  end
  (firmware_urls,firmware_text)=search_xcp_firmware_page(model)
  handle_output(model,firmware_urls,firmware_text,output_type,output_file,latest_only)
end