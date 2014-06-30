#!/usr/bin/env ruby

# Name:         oort (Oracle OBP Reporting/Reetrieval Tool)
# Version:      0.8.1
# Release:      1
# License:      CC-BA (Creative Commons By Attrbution)
#               http://creativecommons.org/licenses/by/4.0/legalcode
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
require 'fileutils'
require 'find'
require 'pathname'
require 'selenium-webdriver'
require 'phantomjs'
require 'mechanize'

# Extend string class to strip out control characters

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

# Create some defaults
# - Work directory
# - Verbose comments (-v sets to 1)
# - Test mode (does not download, -b sets this to 1)

$script       = File.basename($0,".rb").chomp
$work_dir     = Dir.home+"/."+$script
$verbose      = 0
$test_mode    = 0
$html_dir     = $work_dir+"/html"
$readme_dir   = $work_dir+"/readme"
$firmware_dir = $work_dir+"/firmware"
options       = "HV?abchlvxA:E:M:N:P:R:S:X:d:e:i:m:n:o:p:q:r:s:t:w:x:z:"

# Search the M Series firmware page for information
# This requires the use of selenium and a web browser as none of the ruby
# modules seem to work with the MOS site

def search_xcp_fw_page(search_xcp)
  base_url    = "https://support.oracle.com/epmos/faces/ui/patch/PatchDetail.jspx?patchId="
  xcp_url     = "https://support.oracle.com/epmos/faces/DocContentDisplay?id=1002631.1"
  output_file = $html_dir+"/xcp.html"
  if !File.exists?(output_file)
    get_mos_url(xcp_url,output_file)
  end
  xcp_rel   = ""
  xcp_post  = ""
  obp_post  = ""
  xcp_date  = ""
  mseries   = ""
  obp_prom  = ""
  xcp_prom  = ""
  patch_url = ""
  xcp_model = ""
  xcp_done  = []
  ["M3000","M4000","M5000","M8000","M9000"].each do |mseries|
    eval("#{mseries}_txts=[]")
    eval("#{mseries}_urls=[]")
  end
  doc = Nokogiri::HTML(File.open(output_file))
  doc.css("td").each { |td| td.inner_html = td.inner_html.gsub(/\n/,'') }
  doc.css("td").each { |td| td.inner_html = td.inner_html.gsub(/<br>/,' ') }
  doc.css("td").each do |node|
    if node.text
      lines = node.text.split(/\n(XCP)/)
      lines.each do |line|
        if !line.match(/XCP\.tar|Release|Matrix|^XCP$/)
          line = line.gsub(/\n/," ").gsub(/\s+/," ").gsub(/^ /,"").gsub(/EOL /,"").gsub(/POST /,"").gsub(/ - /,"-")
          if line.match(/^[0-9][0-9][0-9][0-9]/)
            xcp_info  = line.split(/ /)
            xcp_rel   = "XCP"+xcp_info[0]
            xcp_post  = xcp_info[3]
            obp_post  = xcp_info[4]
            obp_prom  = xcp_info[1]
            xcp_prom  = xcp_info[2]
            xcp_month = xcp_info[6]
            xcp_year  = xcp_info[7]
            xcp_date  = xcp_info[6..7].join(" ")
            if line.match(/Patch/)
              if !xcp_done.to_s.match(/#{xcp_rel}/)
                model_info = line.split(/ #{xcp_year} /)[1]
                model_info = model_info.split(/ Bug /)[0]
                model_info = model_info.split(/M/)
                model_info.each do |patch_info|
                  if patch_info.match(/ Patch /)
                    (mseries,patch_no) = patch_info.split(/ Patch /)
                    mseries   = "M"+mseries
                    patch_no  = patch_no.gsub(/ /,"")
                    patch_url = base_url+patch_no
                    xcp_text  = xcp_rel+" "+obp_prom+" "+xcp_prom+" POST "+xcp_post+" "+obp_post+" "+mseries+" "+xcp_date
                    xcp_text  = xcp_text.gsub(/\s+/," ").gsub(/ $/,"")
                    eval("#{mseries}_txts.push(xcp_text)")
                    eval("#{mseries}_urls.push(patch_url)")
                  end
                end
                xcp_done.push(xcp_rel)
              end
            else
              xcp_model = xcp_info[5]
              if !xcp_done.to_s.match(/#{xcp_rel}/) and line.match(/-/)
                xcp_text  = xcp_rel+" "+obp_prom+" "+xcp_prom+" POST "+xcp_post+" "+obp_post+" "+xcp_model+" "+xcp_date
                xcp_text  = xcp_text.gsub(/\s+/," ").gsub(/ $/,"")
                if xcp_model.match(/M3000/) and !xcp_model.match(/M3000\-/)
                  mseries = "M3000"
                  eval("#{mseries}_txts.push(xcp_text)")
                  eval("#{mseries}_urls.push(xcp_url)")
                end
                if xcp_model.match(/M3000\-M9000/)
                  ["M3000","M4000","M5000","M8000","M9000"].each do |mseries|
                    eval("#{mseries}_txts.push(xcp_text)")
                    eval("#{mseries}_urls.push(xcp_url)")
                  end
                end
                if xcp_model.match(/M4000\-M9000/)
                  ["M4000","M5000","M8000","M9000"].each do |mseries|
                    eval("#{mseries}_txts.push(xcp_text)")
                    eval("#{mseries}_urls.push(xcp_url)")
                  end
                end
                if xcp_model.match(/M5000\-M9000/)
                  ["M5000","M8000","M9000"].each do |mseries|
                    eval("#{mseries}_txts.push(xcp_text)")
                    eval("#{mseries}_urls.push(xcp_url)")
                  end
                end
                if xcp_model.match(/M8000\-M9000/)
                  ["M8000","M9000"].each do |mseries|
                    eval("#{mseries}_txts.push(xcp_text)")
                    eval("#{mseries}_urls.push(xcp_url)")
                  end
                  xcp_done.push(xcp_rel)
                end
              end
            end
          end
        end
      end
    end
  end
  fw_text = {}
  fw_urls = {}
  ["M3000","M4000","M5000","M8000","M9000"].each do |mseries|
    fw_text[mseries] = eval("#{mseries}_txts")
    fw_urls[mseries] = eval("#{mseries}_urls")
  end
  return fw_urls,fw_text
end

# Code to search patchdiag.xref for older V series (and other) firmware information

def search_prom_fw_page(search_model,url)
  base_url   = "https://support.oracle.com/epmos/faces/ui/patch/PatchDetail.jspx?patchId="
  urls       = []
  txts       = []
  model      = ""
  fw_urls    = {}
  fw_text    = {}
  model_list = [ "CT900", "CP3220", "CP3250", "CP3260", "CP3270", "T3-1BA",
                 "V440", "V445", "V440", "V480", "V490", "V880", "V890", "V125",
                 "U45", "U25", "T6320", "T6340", "B2500", "B1500", "T6300",
                 "T5120", "T5220", "T5240", "T1000", "T2000", "V215", "V245",
                 "V210", "V240", "E6900", "E4900", "E2900", "E6800", "E4800",
                 "E4810", "E3800", "V1280", "V100", "X1", "U1", "U2",
                 "U1E", "U30", "U5", "U80", "E220R", "E280R", "E250", "E450",
                 "T1", "E420R", "X1", "B100", "B150" ]
  doc=open_patchdiag_xref()
  if search_model == "all"
    prom_info = doc.grep(/PROM:/)
  else
    prom_info = doc.grep(/#{search_model}/).grep(/PROM:/)
  end
  if prom_info.to_s.match(/[A-z]/)
    prom_info.each do |line|
      if !line.downcase.match(/withdrawn|obsolete|cpld|fem/)
        line       = line.chomp
        line       = line.split("|")
        patch_no   = line[0]+"-"+line[1]
        patch_text = line[10].split(/PROM: /)[1..-1].join
        patch_text = patch_text.gsub(/t1 /,"T1 ")
        patch_text = patch_text.gsub(/6800\/4800\/4810i\/3800/,"E6800 E4800 E4810 E3800 ")
        patch_text = patch_text.gsub(/Sun Blade 100\/150 /,"B100 B150 ")
        patch_text = patch_text.gsub(/Sun Blade 1500 /,"B1500 ")
        patch_text = patch_text.gsub(/Sun Blade 2500 /,"B2500 ")
        patch_text = patch_text.gsub(/Ultra 2 /,"U2 ")
        patch_text = patch_text.gsub(/Enterprise 450 /,"E450 ")
        patch_text = patch_text.gsub(/Enterprise 250 /,"E250 ")
        patch_text = patch_text.gsub(/Ultra 25 /,"U25 ")
        patch_text = patch_text.gsub(/Ultra 45 /,"U45 ")
        patch_text = patch_text.gsub(/Ultra 1E /,"U1E ")
        patch_text = patch_text.gsub(/Ultra 1 /,"U1 ")
        patch_text = patch_text.gsub(/Ultra 30 /,"U30 ")
        patch_text = patch_text.gsub(/Ultra 60 /,"U60 ")
        patch_text = patch_text.gsub(/Ultra 80 /,"U80 ")
        model_info = patch_text
        patch_url  = base_url+patch_no
        if search_model == "all" or patch_text.downcase.match(/#{search_model.downcase}/)
          doc = open_patch_readme(patch_no)
          if doc[1]
            doc.each do |readme_line|
              check_strings = [ "ILOM", "Hostconfig", "Hypervisor", "OpenBoot",
                                "POST", "OBP", "System Firmware", "ScApp",
                                "PROM", "RTOS" ]
              readme_line   = readme_line.chomp
              readme_line   = readme_line.lstrip
              check_strings.each do |check_string|
                if readme_line.match(/#{check_string} /) and readme_line.match(/[0-9]\.[0-9]/)
                  check_info = readme_line.split(/#{check_string} /)[1]
                  if check_info.match(/ /)
                    check_info = check_info.split(/ /)[0]
                  end
                end
                if readme_line.match(/#{check_string}_/) and readme_line.match(/[0-9]\.[0-9]/)
                  check_info = readme_line.split(/#{check_string}_/)[1]
                  if check_info.match(/,/)
                    check_info = check_info.split(/,/)[0]
                  end
                end
                if readme_line.match(/#{check_string}:/) and readme_line.match(/[0-9]\.[0-9]/)
                  check_info = readme_line.split(/#{check_string}:/)[1]
                  if check_info.match(/,/)
                    check_info = check_info.split(/,/)[0]
                  end
                end
                if check_info
                  if !patch_text.match(/#{check_string}/) and check_info.match(/[0-9]\.[0-9]/)
                    patch_text = patch_text+" "+check_string+" "+check_info
                  end
                end
              end
            end
            urls.push(patch_url)
            txts.push(patch_text)
            model_list.each do |model_no|
              if patch_text.match(/#{model_no} /)
                fw_urls[model_no] = urls
                fw_text[model_no] = txts
              end
            end
            urls   = []
            txts   = []
            models = []
          end
        end
      end
    end
  end
  return fw_urls,fw_text
end

# Code to search patchdiag.xref for disk firmware information

def search_disk_fw_page(search_model,url)
  base_url = "https://support.oracle.com/epmos/faces/ui/patch/PatchDetail.jspx?patchId="
  urls     = []
  txts     = []
  model    = ""
  fw_urls  = {}
  fw_text  = {}
  doc=open_patchdiag_xref()
  if search_model == "all"
    disk_info = doc.grep(/Disk/)
  else
    disk_info = doc.grep(/#{search_model}/)
  end
  if disk_info.to_s.match(/[A-z]/)
    disk_info.each do |line|
      line     = line.split("|")
      patch_no = line[0]+"-"+line[1]
      doc      = open_patch_readme(patch_no)
      if doc[1]
        doc.each do |readme_line|
          patch_text  = line[10].chomp
          patch_url   = base_url+patch_no
          readme_line = readme_line.chomp
          if readme_line.match(/\.fw/)
            readme_line = readme_line.gsub(/^\s+/,'')
            readme_line = readme_line.gsub(/,/,'')
            if readme_line.match(/\s+/)
              fw_info = readme_line.split(/\s+/)
              if fw_info[0].match(/fw$/) and fw_info[0].match(/^[A-Z]/)
                fw_info = fw_info[0].split(/\./)
                model   = fw_info[0]
                fw_rev  = fw_info[1]
                if patch_text.match(/[A-z]/) and model.match(/[A-z]|[0-9]/)
                  urls.push(patch_url)
                  patch_text = patch_text+" ("+fw_rev+")"
                  txts.push(patch_text)
                  fw_urls[model] = urls
                  fw_text[model] = txts
                  urls = []
                  txts = []
                end
              end
            end
          end
        end
      end
    end
  end
  return fw_urls,fw_text
end

# This code searches two places for firmware information:
# - Qlogic site (later 8Gb models)
# - patchdiag.xref for older HBAs

def search_qlogic_fw_page(search_model,url)
  base_url   = "https://support.oracle.com/epmos/faces/ui/patch/PatchDetail.jspx?patchId="
  qf8_url    = "http://driverdownloads.qlogic.com/QLogicDriverDownloads_UI/SearchByProductOracle.aspx?oemid=124&productid=928&OSTYPE=Solaris&category=3"
  fw_text    = {}
  fw_urls    = {}
  fw_version = ""
  qf8_file   = "qf8.html"
  # Information from Sun System Handbook
  hba_info   = {}
  hba_info["SG-XPCIEFCGBE-Q8-Z"] = "8Gb/sec PCI Express Dual FC / Dual Gigabit Ethernet Host Adapter ExpressModule, QLogic"
  hba_info["SG-XPCIE2FC-QB4-Z"]  = "4Gb/sec PCI Express Dual Fibre Channel ExpressModule Host Adapter, QLogic"
  hba_info["SG-XPCIE2FCGBE-Q-Z"] = "4Gb/sec PCI Express Dual FC / Dual Gigabit Ethernet ExpressModule Host Adapter, QLogic"
  hba_info["SG-XPCI2FC-QF4-Z"]   = "4Gb PCI-X Dual FC Host Adapter"
  hba_info["SG-XPCIE1FC-QF8-Z"]  = "8Gigabit/Sec PCI Express Single FC Host Adapter"
  hba_info["SG-XPCIE2FC-QF8-Z"]  = "8Gigabit/Sec PCI Express Dual FC Host Adapter"
  hba_info["SG-XPCI1FC-QF4-Z"]   = "4Gb PCI-X Single FC Host Adapter"
  hba_info["SG-XPCIE1FC-QF4-Z"]  = "4Gigabit/Sec PCI Express Single FC Host Adapter"
  hba_info["SG-XPCIE2FC-QF4-Z"]  = "4Gigabit/Sec PCI Express Dual FC Host Adapter"
  urls        = []
  txts        = []
  search_list = []
  doc         = open_patchdiag_xref()
  if search_model.match(/all/)
    hba_info.each do |model|
      model = model[0]
      if model.match(/[A-z]/)
        search_list.push(model)
      end
    end
  else
    search_list[0] = "#{search_model}"
  end
  search_list.each do |model|
    patch_no = ""
    if model.match(/2$|2-Z$|4$|4-Z$|Q$|Q-Z$|all/)
      if model.match(/XPCI1FC-QF2|all/)
        patch_no = "114873"
      end
      if model.match(/XPCI2FC-QF2|XPCI2FC-QF2|XPCI1FC-QL2|all/)
        patch_no = "114874"
      end
      if model.match(/QF4|QB4|Q$|Q-Z$/)
        patch_no = "123305"
      end
    end
    text=hba_info[model]
    if !model.match(/QF8|Q8/)
      if patch_no.match(/^[0-9]/)
        doc        = open_patchdiag_xref()
        patch_info = doc.grep(/^#{patch_no}/)
        patch_info = patch_info[0].split("|")
        patch_no   = patch_info[0]+"-"+patch_info[1]
        doc        = open_patch_readme(patch_no)
        fcode_info = doc.grep(/Unbundled Release/)
        fcode_info = fcode_info[0].split(": ")
        fcode_info = fcode_info[1].gsub(%r{</?[^>]+?>}, '').chomp
        patch_url  = base_url+patch_no
        text       = text+" "+fcode_info
      end
    else
      # Fetch file and process locally
      if search_model.match(/all|8$/)
        get_url(qf8_url,qf8_file)
        doc   = Nokogiri::HTML(File.open(qf8_file))
        #node = doc.search("[text()*='QF8']").each do |node|
        node  = doc.css('table tr').each do |node|
          if node.text.match(/#{model}/)
            fw_version = node.text.split(/This Preload Table/)[0].split(/\s+/)[-1]
          end
        end
      end
      text      = text+" Firmware Version "+fw_version
      patch_url = qf8_url
    end
    txts.push(text)
    urls.push(patch_url)
    fw_urls[model] = urls
    fw_text[model] = txts
    urls = []
    txts = []
  end
  return fw_urls,fw_text
end

# If a ~/,mospasswd doesn't exist ask for details

def get_mos_details()
  mos_passwd_file = Dir.home+"/.mospasswd"
  if !File.exists?(mos_passwd_file)
    puts "Enter MOS Username:"
    STDOUT.flush
    mos_username = gets.chomp
    puts "Enter MOS Password:"
    STDOUT.flush
    mos_password = gets.chomp
    create_mos_passwd_file(mos_username,mos_password)
  else
    mos_data = File.readlines(mos_passwd_file)
    mos_data.each do |line|
      line.chomp
      if line.match(/http-user/)
        mos_username = line.split(/\=/)[1].chomp
      end
      if line.match(/http-password/)
        mos_password = line.split(/\=/)[1].chomp
      end
    end
  end
  return mos_username,mos_password
end

# Search patchdiag.xref for latest version of patch

def get_patch_full_id(patch_no)
  if !patch_no.match(/-/)
    doc      = open_patchdiag_xref()
    patch_no = doc.grep(/^#{patch_no}/)
    patch_no = patch_no.join.split("|")
    patch_no = patch_no[0]+"-"+patch_no[1]
  end
  return patch_no
end

# Search patchdiag.xref

def search_patchdiag_ref(search_string)
  doc    = open_patchdiag_xref()
  result = doc.grep(/#{search_string}/)
  return result
end

# If given a patch number generate the URL and download it

def get_patch_file(patch_no,output_file)
  base_url = "https://getupdates.oracle.com/all_unsigned/"
  patch_no = get_patch_full_id(patch_no)
  if !output_file.match(/[A-z]/)
    output_file = $work_dir+"/"+patch_no+".zip"
  end
  url = base_url+patch_no+".zip"
  get_download(url,output_file)
end

# Open a patch README and put it into an array

def open_patch_readme(patch_no)
  doc = ""
  patch_no    = get_patch_full_id(patch_no)
  output_file = $readme_dir+"/README."+patch_no
  get_patch_readme(patch_no,output_file)
  if File.exist?(output_file)
    doc = IO.readlines(output_file)
  else
    if $verbose == 1
      puts "README does not exist for: "+patch_no
    end
  end
  return doc
end

# If given a patch generate the URL for the README and download it

def get_patch_readme(patch_no,output_file)
  base_url = "https://getupdates.oracle.com/readme/"
  patch_no = get_patch_full_id(patch_no)
  if !output_file.match(/[A-z]/)
    output_file = $readme_dir+"/README."+patch_no
  end
  url = base_url+patch_no
  get_download(url,output_file)
end

# If MOS password file doesn't exist create it and give it appropriate permissions

def create_mos_passwd_file(mos_username,mos_password)
  mos_passwd_file = Dir.home+"/.mospasswd"
  FileUtils.touch(mos_passwd_file)
  File.chmod(0600,mos_passwd_file)
  output_text = "http-user="+mos_username+"\n"
  File.open(mos_passwd_file, 'a') { |file| file.write(output_text) }
  output_text = "http-password="+mos_password+"\n"
  File.open(mos_passwd_file, 'a') { |file| file.write(output_text) }
  output_text = "check-certificate=off\n"
  File.open(mos_passwd_file, 'a') { |file| file.write(output_text) }
  File.close(mos_passwd_file)
end

# Check the file age, if greateer that 30 days, delete it
# This is useful for making sure local cached copies of URLs are up to date

def check_file_age(output_file)
  if File.exists?(output_file)
    age = Time.now-File.mtime(output_file)
    age = (age/(24*60*60)).to_i
    if (age > 30)
      File.delete(output_file)
    end
  end
end

# Download URL and store a local cached copy to speed up processing

def get_url(url,output_file)
  check_file_age(output_file)
  if !File.exists?(output_file)
    if $verbose == 1
      puts "Caching "+url+" to "+output_file
    end
    url_content = open(url).read
    output_file = File.open(output_file,"w")
    output_file.write(url_content)
    output_file.close
  end
  return
end

def get_download(url,output_file)
  check_file_type(output_file)
  if !File.exists?(output_file)
    if $verbose == 1
      puts "Downloading: #{url}"
      puts "Destination: #{output_file}"
    end
    output_dir = File.dirname(output_file)
    if !Dir.exists?(output_dir)
      begin
        Dir.mkdir(output_dir)
      rescue
        puts "Cannot creating directory "+output_dir
        exit
      end
    end
    if $test_mode == 0
      if url.match(/Orion|getupdates/)
        (mos_username,mos_password) = get_mos_details()
        get_mos_url(url,output_file)
      else
        agent = Mechanize.new
        agent.redirect_ok = true
        agent.pluggable_parser.default = Mechanize::Download
        begin
          agent.get(url).save(output_file)
        rescue
          if $verbose == 1
            puts "Error fetching: "+url
          end
        end
      end
    end
  else
    if $verbose == 1
      puts "File: #{output_file} already exists"
    end
  end
  return
end

# Check file type

def check_file_type(file_name)
  if File.exist?(file_name)
    file_check = %x[file #{file_name}].chomp
    if file_check.match(/empty/)
      File.delete(file_name)
    end
  end
  if File.exists?(file_name) and file_name.match(/zip$/)
    file_check = %x[file "#{file_name}"].chomp
    if file_check.match(/HTML/)
      File.delete(file_name)
    end
  end
  return
end

# Open patchdiag,xref and read it into an array

def open_patchdiag_xref()
  output_file = $work_dir+"/patchdiag.xref"
  get_patchdiag_xref(output_file)
  doc = IO.readlines(output_file)
  return doc
end

# Get patchdiag.xref

def get_patchdiag_xref(output_file)
  url = "https://getupdates.oracle.com/reports/patchdiag.xref"
  if !output_file.match(/[A-z]/)
    output_file = $work_dir+"/patchdiag.xref"
  end
  check_file_age(output_file)
  check_file_type(output_file)
  if !File.exists?(output_file)
    agent = Mechanize.new
    agent.redirect_ok = true
    agent.pluggable_parser.default = Mechanize::Download
    begin
      agent.get(url).save(output_file)
    rescue
    if $verbose == 1
      puts "Error fetching: "+url
    end
    end
  else
    if $verbose == 1
      puts "File: "+output_file+" already exists"
    end
  end
  return
end

# Code to search the Emulex pages(s) for HBA firmware information
# This is a two stage process:
# First it fetches the page with a list of Oracle supported HBAs
# Second it follow the links of that page for each of the HBAs
# to get firmware information

def search_emulex_fw_page(search_model,url)
  urls        = []
  txts        = []
  model       = ""
  sun_model   = ""
  fw_urls     = {}
  fw_text     = {}
  url         = "http://www.emulex.com/products/fibre-channel-hbas/oracle-branded/selection-guide/"
  output_file = $html_dir+"/emulex.html"
  get_url(url,output_file)
  doc       = Nokogiri::HTML(File.open(output_file))
  fw_urls   = {}
  fw_text   = {}
  hba_model = {}
  hba_model['SG-XPCIE1FC-EM8-Z']  = "LPe12000"
  hba_model['SG-XPCIE2FC-EM8-Z']  = "LPe12002"
  hba_model['SG-XPCIE1FC-EM8-Z']  = "LPe12000"
  hba_model['SG-XPCIEFCGBE-E8-Z'] = "LPem12002E-S"
  hba_model['SG-XPCIE20FC-NEM-Z'] = "LPe11020-S"
  hba_model['SG-XPCIE2FC-EB4-Z']  = "LPem11002-S"
  hba_model['SG-XPCIE2FCGBE-E-Z'] = "LPem11002E-S"
  hba_model['SG-XPCIE2FC-ATCA-Z'] = "LPeA11002-S"
  hba_model['SG-XPCI1FC-EM4-Z']   = "LP11000"
  hba_model['SG-XPCI2FC-EM4-Z']   = "LP11002"
  hba_model['SG-XPCIe1FC-EM4']    = "LPe11000"
  hba_model['SG-XPCIe2FC-EM4']    = "LPe11002"
  # Populate older card information (Emulex page no longer works)
  fw_text["LP21000"] = [ "Version 3.10a3" ]
  fw_text["LP21002"] = [ "Version 3.10a3" ]
  fw_urls["LP21000"] = [ "http://www-dl.emulex.com/support/hardware/lp21000/ob/310a3/ao310a3.zip" ]
  fw_urls["LP21002"] = [ "http://www-dl.emulex.com/support/hardware/lp21000/ob/310a3/ao310a3.zip" ]
  #
  if search_model.match(/^LP|^7/)
    hba_model.each do |orace_part_no, emulex_part_no|
      if emulex_part_no.downcase == search_model.downcase
        search_model = orace_part_no
      end
    end
  end
  lc_model = search_model.downcase
  boot_url = "firmware-and-boot-code"
  doc.css("li a").each do |node|
    sub_url = node[:href]
    if sub_url
      if sub_url.match(/#{boot_url}/)
        if search_model.match(/all/) or sub_url.match(/#{lc_model}/)
          part_no = sub_url.split(/\//)[3].to_s
          doc_url = sub_url.gsub(/features/,boot_url)
          fw_info = part_no.upcase.gsub(/-AND-/," ")
          fw_file = $work_dir+"/html/"+part_no+".html"
          doc_url = "http://www.emulex.com/"+doc_url
          get_url(doc_url,fw_file)
          subdoc = Nokogiri::HTML(File.open(fw_file))
          subdoc.css("tbody").each do |subnode|
            if subnode.text.match(/BootCode|Firmware Version|OpenBoot/)
              subnode.css("tr").each do |info|
                zip_url = ""
                fw_info = info.text
                fw_info = fw_info.gsub(/\s+/," ")
                fw_info = fw_info.gsub(/^\s+/,"")
                fw_info = fw_info.gsub(/DownloadDescriptionDocumentation /,"")
                if !fw_info.match(/^SG|^SC/)
                  if fw_info.match(/^Universal/)
                    if fw_info.match(/Contains: /)
                      fw_head = fw_info.split(/ Download Contains: /)[0]
                      fw_tail = fw_info.split(/ Download Contains: /)[1].split(/ Boot Code/)[0]
                      fw_info = fw_head+" "+fw_tail
                      zip_url = subnode.to_s.split(/href="/)[1].split(/"/)[0]
                    end
                  else
                    if fw_info.match(/^Firmware/)
                      if fw_info.match(/ Product/)
                        zip_url = info.to_s.split(/"/)[3]
                        fw_info = fw_info.split(/ Product/)[0]
                      else
                        if fw_info.match(/ Download/)
                          zip_url = subnode.to_s.split(/href="/)[3].split(/"/)[0]
                          fw_info = fw_info.split(/ Download/)[0]
                        else
                          if fw_info.match(/Oracle VM Server/)
                            zip_url = info.to_s.split(/"/)[3]
                            fw_info = fw_info.split(/ Use /)[0]
                          end
                        end
                      end
                    end
                  end
                  if !zip_url.match(/http/)
                    zip_url = subnode.to_s.split(/href="/)[1].split(/"/)[0]
                  end
                  urls.push(zip_url)
                  if !fw_info.to_s.match(/DownloadDescriptionDocumentation|^Note/)
                    txts.push(fw_info)
                  end
                end
              end
            end
          end
        end
        if part_no.match(/-and-/)
          part_nos = part_no.split(/-and-/)
          part_nos.each do |part_no|
            fw_text[part_no.upcase] = txts
            fw_urls[part_no.upcase] = urls
            if hba_model[part_no.upcase]
              lp_part_no = hba_model[part_no.upcase]
              fw_text[lp_part_no.upcase] = txts
              fw_urls[lp_part_no.upcase] = urls
            end
          end
        else
          fw_text[part_no.upcase] = txts
          fw_urls[part_no.upcase] = urls
          if hba_model[part_no.upcase]
            lp_part_no = hba_model[part_no.upcase]
            fw_text[lp_part_no.upcase] = txts
            fw_urls[lp_part_no.upcase] = urls
          end
        end
        txts = []
        urls = []
      end
    end
  end
  return fw_urls,fw_text
end

# Get a MOS page

def get_mos_url(mos_url,local_file)
  if $verbose == 1
    puts "Downloading "+mos_url+" to "+local_file
  end
  if mos_url.match(/patch_file|zip$/)
    mos_passwd_file = Dir.home+"/.mospasswd"
    if !File.exists?(mos_passwd_file)
      (mos_username,mos_password)=get_mos_details()
      create_mos_passwd_file(mos_username,mos_password)
    end
    if $verbose == 1
      command="export WGETRC="+mos_passwd_file+"; wget --no-check-certificate "+"\""+mos_url+"\""+" -O "+"\""+local_file+"\""
    else
      command="export WGETRC="+mos_passwd_file+"; wget --no-check-certificate "+"\""+mos_url+"\""+" -q -O "+"\""+local_file+"\""
    end
    system(command)
  else
    (mos_username,mos_password) = get_mos_details()
    cap = Selenium::WebDriver::Remote::Capabilities.phantomjs('phantomjs.page.settings.userAgent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10) AppleWebKit/538.39.41 (KHTML, like Gecko) Version/8.0 Safari/538.39.41')
    doc = Selenium::WebDriver.for :phantomjs, :desired_capabilities => cap
    mos = "https://supporthtml.oracle.com"
    doc.get(mos)
    doc.manage.timeouts.implicit_wait = 20
    doc.find_element(:id => "pt1:gl3").click
    doc.find_element(:id => "Mssousername").send_keys(mos_username)
    doc.find_element(:id => "Mssopassword").send_keys(mos_password)
    doc.find_element(:link => "Sign In").click
    doc.get(mos_url)
    file = File.open(local_file,"w")
    file.write(doc.page_source)
    file.close
  end
  return
end

# Print SRU info

def print_sru_info(patch_no,patch_info,patch_url,download_url)
  puts patch_no+":"
  puts patch_info
  puts patch_url
  puts download_url
  return
end

# Get current SRU number from patch informtation

def get_current_sru_no(patch_info)
  if patch_info.match(/EXA/)
    current_sru = patch_info.split(/ /)[3].split(/-/)[0]
  else
    current_sru = patch_info.split(/ /)[2]
  end
  return current_sru
end

# Compare SRU Numbers

def compare_sru_vers(current_sru,latest_sru)
  versions = [ current_sru, latest_sru ]
  latest_sru = versions.map{ |v| (v.split '.').collect(&:to_i) }.max.join '.'
  return latest_sru
end

# Download Oracle SRUs

def download_oracle_sru(sru_info,sru_urls)
  sru_urls.each do |patch_no, patch_urls|
    download_url = patch_urls[1]
    output_file  = File.basename(download_url)
    output_dir   = $work_dir+"/srus"
    output_file  = output_dir+"/"+output_file
    if !File.directory?(output_dir)
      begin
        Dir.mkdir(output_dir)
      rescue
        puts "Cannot create directory "+output_dir
        exit
      end
    end
    if !File.exist?(output_file)
      download_url(download_url,output_file)
    end
  end
  return
end

# Search Oracle's SRU page

def search_oracle_sru_page(search_string,latest_only,url)
  (sru_info,sru_urls)=process_oracle_sru_page(url)
  current_sru = ""
  latest_sru  = ""
  sru_info.each do |patch_no, patch_info|
    patch_url = sru_urls[patch_no][0]
    download_url  = sru_urls[patch_no][1]
    if !search_string.match(/all/)
      if patch_info.match(/#{search_string}/)
        if latest_only == 1
          current_sru = get_current_sru_no(patch_info)
          if !latest_sru.match(/[0-9]/)
            latest_sru = current_sru
          else
            latest_sru = compare_sru_vers(current_sru,latest_sru)
          end
        else
          print_sru_info(patch_no,patch_info,patch_url,download_url)
        end
      end
    else
      if latest_only == 1
        current_sru = get_current_sru_no(patch_info)
        if !latest_sru.match(/[0-9]/)
          latest_sru = current_sru
        else
          latest_sru = compare_sru_vers(current_sru,latest_sru)
        end
      else
        print_sru_info(patch_no,patch_info,patch_url,download_url)
      end
    end
  end
  if latest_only == 1
    sru_info.each do |patch_no, patch_info|
      patch_url     = sru_urls[patch_no][0]
      download_url  = sru_urls[patch_no][1]
      if patch_info.match(/#{latest_sru}/)
        print_sru_info(patch_no,patch_info,patch_url,download_url)
      end
    end
  end
  return sru_info,sru_urls
end

# Process Oracle's SRU page

def process_oracle_sru_page(url)
  base_url = "https://support.oracle.com/epmos/faces/ui/patch/PatchDetail.jspx?patchId="
  sru_file = $html_dir+"/sru.html"
  sru_info = {}
  sru_urls = {}
  if !File.exist?(sru_file)
    get_mos_url(url,sru_file)
  end
  doc        = Nokogiri::HTML(File.open(sru_file))
  rows       = doc.css('table tr').xpath("//td[contains(@class,'x10t')]")
  patch_no   = ""
  patch_info = ""
  patch_url  = ""
  model      = "OS"
  rows.each do |row|
    if !row.text.match(/More.../)
      if row.to_s.match(/xfe/)
        if patch_no.match(/[0-9]/)
          patch_url = base_url+patch_no
          (download_url,file_name) = get_oracle_download_url(model,patch_info,patch_url)
          sru_info[patch_no] = patch_info
          patch_urls = []
          patch_urls.push(patch_url)
          patch_urls.push(download_url)
          sru_urls[patch_no] = patch_urls
          patch_no   = row.text
          patch_info = ""
        else
          patch_no   = row.text
          patch_info = ""
        end
      else
        text = row.text
        if !text.match(/^General$|^Operating System$/) and text.match(/[A-z]/)
          text = text.gsub(/^\s+|\s+$/,"")
          if patch_info.match(/[A-z]/)
            patch_info = patch_info+" "+text
          else
            patch_info = text
          end
        end
      end
    end
  end
  (download_url,file_name) = get_oracle_download_url(model,patch_info,patch_url)
  patch_urls = []
  patch_urls.push(patch_url)
  patch_urls.push(download_url)
  sru_urls[patch_no] = patch_urls
  return sru_info,sru_urls
end

# Process Oracle's system firmware page
# This code makes copies of hashes for similar models which
# use the same firmware so that it is searchable
# The web page will only have HTML tags (name) for one model
# E.g, the information for the T5220 is copied to the T5120

def search_system_fw_page(search_model,url)
  if url.match(/http/)
    doc = Nokogiri::HTML(open(url))
  else
    doc = Nokogiri::HTML(File.open(url))
  end
  urls        = []
  txts        = []
  fw_urls     = {}
  fw_text     = {}
  model       = ""
  new_model   = ""
  counter     = 0
  module_text = ""
  rows        = doc.css('table tr')
  rows.each do |row|
    info = ""
    url  = ""
    name = row.css('a').map{|td| td[:name]}
    if name[0]
      if name[0].match(/[A-z]|[0-9]/)
        new_model = name[0]
        counter   = counter+1
      end
    end
    if !model.match(/[A-z]|[0-9]/)
      model = new_model
    end
    info = row.content.to_s
    info = info.gsub(/\s+ /,' ')
    info = info.gsub(/^\s+ /,'')
    info = info.gsub(/ $/,'')
    info = info.gsub(/ download/,'')
    if info.match(/[0-9,A-z]\(/)
      (head,tail)=info.split("(")
      info=head+" ("+tail
    end
    info  = info.split(" ")
    info  = info.uniq
    info  = info.join(" ")
    if !info.match(/#{new_model}/)
      info = new_model+" "+info
    end
    links = row.css('a').map{|td| td[:href]}
    links.each do |link|
      if link
        if link.match(/http/) and link.match(/[0-9]/)
          url = link
        end
      end
    end
    if new_model.match(/[A-z]|[0-9]/)
      if new_model != model
        txts = txts.uniq
        urls = urls.uniq
        if urls.grep(/[A-z]|[0-9]/) and txts.grep(/[A-z]|[0-9]/)
          fw_text[model] = txts
          fw_urls[model] = urls
        end
        txts = []
        urls = []
        if info.match(/[0-9]/) and url.match(/http/) and !info.match(/Programmables 1.0.0/)
          txts.push(info)
          urls.push(url)
        end
        model = new_model
      else
        if info.match(/[0-9]/) and url.match(/http/) and !info.match(/Programmables 1.0.0/)
          if counter > 1
            txts.push(info)
            urls.push(url)
          end
        end
      end
    end
  end
  if search_model != "all"
    if urls.grep(/[A-z]|[0-9]/) and txts.grep(/[A-z]|[0-9]/)
      fw_urls["#{model}"] = urls
      fw_text["#{model}"] = txts
    end
  end
  ['NT3-1BA','CP3010','CP3020','CP3060','CP3220','CP3250','CP3260','CP3270'].each do |member|
    fw_text[member] = fw_text["CT900"]
    fw_urls[member] = fw_urls["CT900"]
  end
  ['8000P','X8400','X8420','X8440','X8450'].each do |member|
    fw_text[member] = fw_text["8000"]
    fw_urls[member] = fw_urls["8000"]
  end
  ['X4240','X4440'].each do |member|
    fw_text[member] = fw_text["X4140"]
    fw_urls[member] = fw_urls["X4140"]
  end
  ['X4270','X4275'].each do |member|
    fw_text[member] = fw_text["X4170"]
    fw_urls[member] = fw_urls["X4170"]
  end
  fw_text["T5120"]    = fw_text["T5220"]
  fw_urls["T5120"]    = fw_urls["T5220"]
  fw_text["T5140"]    = fw_text["T5240"]
  fw_urls["T5140"]    = fw_urls["T5240"]
  fw_text["X4200"]    = fw_text["X4100"]
  fw_urls["X4200"]    = fw_urls["X4100"]
  fw_text["X4200M2"]  = fw_text["X4100M2"]
  fw_urls["X4200M2"]  = fw_urls["X4100M2"]
  fw_text["X4170M3"]  = fw_text["X3-2"]
  fw_urls["X4170M3"]  = fw_urls["X3-2"]
  fw_text["X4270M3"]  = fw_text["X3-2L"]
  fw_urls["X4270M3"]  = fw_urls["X3-2L"]
  fw_text["X4470M2"]  = fw_text["X2-4"]
  fw_urls["X4470M2"]  = fw_urls["X2-4"]
  fw_text["X4800M2"]  = fw_text["X2-8"]
  fw_urls["X4800M2"]  = fw_urls["X2-8"]
  fw_text["X4270M3"]  = fw_text["X3-2"]
  fw_urls["X4270M3"]  = fw_urls["X3-2"]
  fw_text["X6270M3"]  = fw_text["X3-2B"]
  fw_urls["X6270M3"]  = fw_urls["X3-2B"]
  fw_text["NX6270M3"] = fw_text["NX3-2B"]
  fw_urls["NX6270M3"] = fw_urls["NX3-2B"]
  return fw_urls,fw_text
end

# If given -h switch print usage information

def print_usage(options)
  puts
  puts "Usage: "+$0+" -["+options+"]"
  puts
  puts "-V:          Display version information"
  puts "-h:          Display usage information"
  puts "-v:          Verbose output"
  puts "-b:          Test mode (don't perform downloads)"
  puts "-c:          Output in CSV format (default text)"
  puts "-x:          Download patchdiag.xref"
  puts "-w WORK_DIR: Set work directory (Default is ~/.firith)"
  puts "-u TERM:     Search all Solaris 11 SRUs for a term"
  puts "-U TERM:     Download Solaris 11 SRUs associated with a term"
  puts "-p PATCH:    Download a patch from MOS (Requires Username and Password)"
  puts "-r PATCH:    Download README for a patch from MOS (Requires Username and Password)"
  puts "-R PATCH:    Download README for a patch from MOS (Requires Username and Password) and send to STDOUT"
  puts "-P SEARCH:   Search patchdiag.xref (Solaris 10 and earlier)"
  puts "-S RELEASE:  Set Solaris release (used with -Y)"
  puts "-A ARCH:     Set architecture (e.g. SPARC, or x86, used with -Y, -m and -M)"
  puts "-o FILE:     Open a file for writing"
  puts "-H:          Delete temporary HTML files"
  puts "-Y:          Update patch archive"
  puts "-i FILE:     Open a locally saved HTML file for processing rather then fetching it"
  puts "-l:          Only show (or download) latest firmware versions (can be used in combination with the following options)"
  puts "-m all:      Display firmware information for all machines"
  puts "-m MODEL:    Display firmware information for a specific model (eg. X2-4)"
  puts "-M all:      Download firmware patch for all models from MOS (Requires Username and Password)"
  puts "-M MODEL:    Download firmware patch for a specific model (eg. X2-4) from MOS (Requires Username and Password)"
  puts "-z all:      Display firmware zip file contents for all models"
  puts "-z MODEL:    Display firmware zip file contents for a specific model (eg. X2-4)"
  puts "-t all:      Display TFTP file for all models"
  puts "-t MODEL:    Display TFTP file for a specfic model (e.g. T5440)"
  puts "-d all:      Display firmware information for all disks"
  puts "-d MODEL:    Display firmware information for a specific model of disk (eg. MAW3300FC)"
  puts "-D all:      Download firmware information for all disks"
  puts "-D MODEL:    Download firmware information for a specific model of disk (eg. MAW3300FC)"
  puts "-e all:      Display firmware information for all Emulex HBAs"
  puts "-e MODEL:    Display firmware information for a specific model of Emulex HBA (eg. SG-XPCIEFCGBE-E8-Z)"
  puts "-E all:      Download firmware patch for all Emulex HBAs"
  puts "-E MODEL:    Download firmware patch for a specific model of Emulex HBA"
  puts "-q all:      Display firmware information for all Qlogic HBAs"
  puts "-q MODEL:    Display firmware information for a specific model of Qlogic HBA (eg. SG-XPCIEFCGBE-Q8-Z)"
  puts "-n all:      Display firmware information for all older V Series"
  puts "-n MODEL:    Display firmware information for specific old V Series"
  puts "-N all:      Download firmware information for all older V Series"
  puts "-N MODEL:    Download firmware information for specific old V Series"
  puts "-x all:      Display firmware information for all older M Series (M3000 - M5000"
  puts "-x MODEL:    Display firmware information for specific old M Series model (M3000-M9000)"
  puts "-X all:      Download firmware information for all older M Series (M3000 - M5000"
  puts "-X MODEL:    Download firmware information for specific old M Series model (M3000-M9000)"
  puts "-u all:      Display all Solaris 11 SRUs"
  puts
end

# if given -V print version information

def print_version()
  file_array = IO.readlines $0
  version    = file_array.grep(/^# Version/)[0].split(":")[1].gsub(/^\s+/,'').chomp
  packager   = file_array.grep(/^# Packager/)[0].split(":")[1].gsub(/^\s+/,'').chomp
  name       = file_array.grep(/^# Name/)[0].split(":")[1].gsub(/^\s+/,'').chomp
  puts name+" v. "+version+" "+packager
end

# Get an aru number (required for download)

def get_aru_no(patch_url)
  aru_no     = ""
  base_url   = "https://updates.oracle.com/Orion/Services/download/"
  patch_no   = patch_url.split(/\=/)[1]
  patch_file = $html_dir+"/"+patch_no+".html"
  if !File.exist?(patch_file)
    get_mos_url(patch_url,patch_file)
  end
  file_array = IO.readlines(patch_file)
  if file_array.to_s.match(/aru\=/)
    aru_no = file_array.grep(/aru\=/)[0].split(/aru\=/)[1].split(/"|'/)[0]
  end
  return aru_no
end

# Get OBP version

def get_obp_ver(patch_url)
  obp_ver     = ""
  patch_no    = patch_url.split(/\=/)[1]
  readme_file = $readme_dir+"/"+patch_no+".readme"
  if !File.exist?(readme_file)
    readme_url = get_oracle_readme_url(patch_url)
    get_mos_url(readme_url,readme_file)
  end
  file_array = IO.readlines(readme_file)
  if file_array.to_s.match(/OpenBoot|OBP/)
    if readme_file.match(/-/)
      obp_ver = file_array.grep(/OpenBoot/)[0]
      if !obp_ver.match(/[0-9]\.[0-9]/)
        obp_ver = file_array.grep(/OBP/)[-1].split(/OBP /)[1].split(/ /)[0]
      else
        obp_ver = obp_ver.split(/OpenBoot /)[1].split(/ /)[0]
      end
    else
      obp_ver = file_array.grep(/OpenBoot/)[1].split(/OpenBoot /)[1].split(/ /)[0]
    end
  end
  return obp_ver
end

# Get README URL

def get_oracle_readme_url(patch_url)
  aru_no     = get_aru_no(patch_url)
  base_url   = "https://updates.oracle.com/Orion/Services"
  readme_url = base_url+"/download?type=readme&aru="+aru_no
  return readme_url
end

# This code takes a model and the information gathered from the system firmware
# page and crafts a URL for the patch download
# There seems to be some vague consistency for the patch file names,
# however it does change from one model to another

def get_oracle_download_url(model,patch_text,patch_url)
  old_base_url  = "https://getupdates.oracle.com/all_unsigned/"
  base_url      = "https://updates.oracle.com/Orion/Services/download"
  download_url  = ""
  head_url      = ""
  patch_no      = patch_url.split("=")[1].to_s
  rev_text      = ""
  download_file = ""
  if !patch_url
    if $verbose == 1
      puts "No patch URL found for "+model+" ["+patch_text+"] \n"
    end
    return
  end
  if !patch_url.match(/index/)
    if model == "OS"
      rev_text = "1100"
      if patch_text.match(/x86/)
        suffix = "Solaris86-64"
      else
        suffix = "SOLARIS64"
      end
    else
      suffix = "Generic"
    end
    if !patch_no.match(/\-/)
      aru_no  = get_aru_no(patch_url)
    end
    if patch_text.match(/Sun Blade 6048 Chassis|Sun Ultra 24 Workstation|Sun Fire X4450 Server/)
      rev_text = patch_text.split(" ")[-2].gsub(/\./,'')
    else
      if patch_text.match(/ILOM|SP|ELOM|BIOS|CR/) and !patch_text.match(/CMM Software /) and !patch_text.match(/SysFW/)
        ['Chassis ','Server ', 'Workstation '].each do |search_string|
          if patch_text.match(/#{search_string}/)
            if patch_text.match(/\(/) and !patch_text.match(/[0-9]$/)
              rev_text = patch_text.split(" ")[-2].gsub(/\./,'')
            else
              rev_text = patch_text.split(" ")[-1].gsub(/\./,'')
            end
          end
        end
      else
        if patch_text.match(/^XCP[0-9]/)
          rev_text = patch_text.split(/ /)[0].gsub(/XCP/,"")
          if rev_text.match(/1117/)
            rev_text = rev_text+"00"
          end
        else
          ['CMM Software ','Module ', 'Programmables ','XCP ','Firmware ','Box '].each do |search_string|
            if patch_text.match(/#{search_string}/)
              rev_text = patch_text.split("#{search_string}")[1].to_s
              rev_text = rev_text.split(" ")[0].gsub(/\./,'')
              if patch_text.match(/System Firmware /)
                rev_text = rev_text[0..1]
              end
            end
          end
        end
      end
    end
    [' FW '].each do |search_string|
      if patch_text.match(/#{search_string}/) and !patch_text.match(/RAID|InfiniBand|ConnectX|LSI|CR/)
        rev_text = patch_text.split("#{search_string}")[0]
        rev_text = rev_text.split(" ")[-1].gsub(/\./,'')
      end
    end
    if model.match(/N6000/)
      rev_text = "100"
    end
    if model.match(/M10-/)
      rev_text = rev_text+"00"
    end
    if patch_no.match(/\-/)
      download_file = patch_no+".zip"
      download_url  = old_base_url+download_file
    else
      if !patch_text.match(/SysFW|System Firmware|Hardware Programmables|Workstation|SW|3\.4 |^XCP[0-9]/) and !model.match(/X6275|X6270M2|X6270$|X2250|X4200|X4470|X4800|X2-8/)
        if rev_text.length < 3
          rev_text = rev_text+"0"
        end
      end
      download_file = "p"+patch_no+"_"+rev_text+"_"+suffix+".zip"
      download_url  = base_url+"/"+download_file+"?aru="+aru_no+"&patch_file="+download_file
    end
  end
  return download_url,download_file
end

# Code to download firmware
# If it finds a copy elsewhere locally it will attempt to symlink it rather
# than download another copy

def download_firmware(model,fw_urls,fw_text,latest_only,counter)
  download_file = ""
  wrong_file    = ""
  existing_file = []
  if !fw_urls[model]
    if $verbose == 1
      puts "No download URLs for "+model+"\n"
    end
    return
  end
  patch_url  = fw_urls[model][counter]
  patch_text = fw_text[model][counter]
  if patch_url.match(/oracle/)
    (download_url,file_name) = get_oracle_download_url(model,patch_text,patch_url)
  else
    download_url = patch_url
    file_name    = File.basename(patch_url)
  end
  if !download_url
    return
  end
  download_file = $firmware_dir+"/"+model.downcase+"/"+file_name
  check_file_type(download_file)
  if !File.exists?(download_file) and !File.symlink?(download_file)
    if $file_list
      existing_file = $file_list.select {|existing_file| existing_file =~ /#{file_name}/}
    end
    if existing_file[0]
      existing_file = existing_file[0]
      dir_name      = Pathname.new(download_file)
      dir_name      = dir_name.dirname
      if !Dir.exists?(dir_name)
        begin
          Dir.mkdir(dir_name)
        rescue
          puts "Cannot create directory "+dir_name
          exit
        end
      end
      if existing_file != download_file
        if $verbose == 1
          puts "Found "+existing_file+"\n"
          puts "Symlinking "+existing_file+" to "+download_file+"\n"
        end
        File.symlink(existing_file,download_file)
      end
    else
      if download_url.match(/oracle/) and download_url.match(/zip$/)
        get_mos_url(download_url,download_file)
      else
        get_download(download_url,download_file)
      end
    end
  else
    if $verbose == 1
      puts "File "+download_file+" already exists"
    end
  end
  return
end

# Code to list the contents of a downloaded zip file
# This is useful for determining the name of the firmware update file
# for creating information for TFTP and other services

def list_zipfile(model,fw_urls,fw_text,search_suffix,output_type,output_file,counter)
  download_file = ""
  output_text   = ""
  fw_data       = ""
  if !fw_urls[model]
    if $verbose == 1
      puts "No download URLs for "+model+"\n"
    end
    return
  end
  patch_url  = fw_urls[model][counter]
  patch_text = fw_text[model][counter]
  if model.match(/U24|U27/)
    if $verbose == 1
      puts "TFTP update not supported for "+model+"\n"
    end
    return
  end
  if patch_url and patch_text
    (download_url,download_file) = get_oracle_download_url(model,patch_text,patch_url)
    download_file                = $work_dir+"/"+model.downcase+"/"+download_file
    get_download(download_url,download_file)
    if !File.exists?(download_file)
      puts "File: "+download_file+" does not exist"
      return
    end
    puts model+":"
    archive_list = %x[unzip -l "#{download_file}" |awk '{print $4}'].split("\n")
    archive_list.each do |file_name|
      if file_name.match(/[A-z]|[0-9]/)
        if search_suffix.match(/[A-z]/)
          if search_suffix.match(/pkg/)
            if file_name.match(/pkg$|bin$|iso$|Ultra[0-9][0-9]$|[0-9][0-9][0-9][0-9]\.tar\.gz|[0-9][0-9][0-9]\.zip/)
              tftp_name = File.basename(file_name)
              if !tftp_name.match(/legal|remote|recovery|^fw|^q8|^firmware/)
                tftp_file = File.dirname(download_file)
                tftp_file = tftp_file+"/"+file_name
                if output_type == "CSV"
                  patch_text = patch_text.to_s.split(" ")
                  if patch_text[0].match(/^ILOM/)
                    fw_data = ","+patch_text[1]+","+tftp_name+","+patch_text[2]
                    case
                    when model.downcase.match(/^x4150$/)
                      output_text = "x4150"+fw_data+"\n"+"x4250"+fw_data+"\n"
                    else
                      output_text = model.downcase+fw_data+"\n"
                    end
                  end
                  if patch_text[0].match(/^Sun System Firmware/)
                    fw_data = ","+patch_text[7]+","+tftp_name+","+patch_text[-1]
                    output_text = model.downcase+fw_data+"\n"
                  end
                  if patch_text[0].match(/^SysFW|^XCP/)
                    if model.match(/[T,M][1-9][0-3][0,-][0-9]/)
                      fw_data = ",,"+tftp_name+","+patch_text[-1]
                      output_text = model.downcase+fw_data+"\n"
                    else
                      fw_data = ","+patch_text[5].gsub(/\)/,'')+","+tftp_name+","+patch_text[1]
                      case
                      when model.downcase.match(/^t5220$/)
                        output_text = "t5120"+fw_data+"\n"+"t5220"+fw_data+"\n"
                      when model.downcase.match(/^t5240$/)
                        output_text = "t5140"+fw_data+"\n"+"t5240"+fw_data+"\n"
                      else
                        output_text = model.downcase+fw_data+"\n"
                      end
                    end
                  end
                  if output_file.match(/[A-z,0-9]/)
                    File.open(output_file, 'a') { |file| file.write(output_text) }
                  else
                    print output_text
                  end
                else
                  output_text = "TFTP file: "+tftp_name+"\n"+"Location:  "+tftp_file+"\n"
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
            output_text = model+","+file_name+"\n"
          else
            output_text = file_name+"\n"
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

# Traverse the firmware information hashes and get download information

def handle_download_firmware(search_model,fw_urls,fw_text,latest_only,search_arch)
  counter   = 0
  do_output = 0
  if search_arch.match(/all/)
    do_output = 1
  end
  if search_arch.downcase.match(/sparc/)
    if model.match(/^T|^M|^V/)
      do_output = 1
    end
  end
  if search_arch.downcase.match(/x86|i386/)
    if model.match(/^X|^B|^8|^6|^NX|^U24|^U27/)
      do_output = 1
    end
  end
  if do_output == 1
    if search_model == "all"
      fw_text.each do |model, text|
        if $verbose == 1
          puts model+":"
        end
        if latest_only == 1
          download_firmware(model,fw_urls,fw_text,latest_only,counter)
        else
          counter = 0
          if fw_text[model]
            fw_text[model].each do
              download_firmware(model,fw_urls,fw_text,latest_only,counter)
              counter = counter+1
            end
          end
        end
      end
    else
      if $verbose == 1
        puts search_model+":"
      end
      if latest_only == 1
        download_firmware(search_model,fw_urls,fw_text,latest_only,counter)
      else
        fw_text[search_model].each do
          download_firmware(search_model,fw_urls,fw_text,latest_only,counter)
          counter = counter+1
        end
      end
    end
  end
  return
end

# Traverse the firmware information hashes and get zip file information

def handle_zipfile(search_model,fw_urls,fw_text,search_suffix,output_type,output_file,latest_only)
  counter = 0
  if search_model == "all"
    fw_text.each do |model, text|
      if $verbose == 1
        puts model+":"
      end
      if latest_only == 1
        list_zipfile(model,fw_urls,fw_text,search_suffix,output_type,output_file,counter)
      else
        counter = 0
        fw_text[model].each do
          list_zipfile(model,fw_urls,fw_text,search_suffix,output_type,output_file,counter)
          counter = counter+1
        end
      end
    end
  else
    if $verbose == 1
      puts search_model+":"
    end
    if latest_only == 1
      list_zipfile(search_model,fw_urls,fw_text,search_suffix,output_type,output_file,counter)
    else
      fw_text[search_model].each do
        list_zipfile(search_model,fw_urls,fw_text,search_suffix,output_type,output_file,counter)
        counter = counter+1
      end
    end
  end
  return
end

# Traverse the firmware information hashes and output information to the console
# Some support exists for creating a comma delimited CSV file

def print_output(model,fw_urls,fw_text,output_type,output_file,latest_only,search_arch)
  counter = 0
  txts    = []
  urls    = []
  if !fw_text[model]
    if $verbose == 1
      puts "Model: #{model} does not exist"
    end
    return
  end
  if latest_only == 1
    text = fw_text[model][0]
    txts.push(text)
    fw_text[model] = txts
    link = fw_urls[model][0]
    urls.push(link)
    fw_urls[model] = urls
  end
  if output_type != "CSV"
    output_text = model+":\n"
    if output_file.match(/[A-z,0-9]/)
      File.open(output_file, 'a') { |file| file.write(output_text) }
    else
      print output_text
    end
  end
  fw_text[model].each do
    patch_url  = ""
    patch_text = ""
    if fw_urls[model][counter]
      patch_url  = fw_urls[model][counter]
      patch_text = fw_text[model][counter]
      if !patch_url.match(/emulex|1002631|qlogic/)
        (download_url,download_file) = get_oracle_download_url(model,patch_text,patch_url)
        if model.match(/^T|^M|^V|^NT|^U25|^U45/) and !patch_text.match(/OBP [0-9]\.[0-9]|ScApp/)
          obp_ver = get_obp_ver(patch_url)
          if obp_ver
            patch_text = patch_text+" OBP "+obp_ver
          end
        end
      else
        download_url = ""
      end
      if output_type == "CSV"
        output_text = model+","+patch_text+","+patch_url+","+download_url+"\n"
      else
        if download_url.match(/[A-z]/)
          output_text = patch_text+"\n"+patch_url+"\n"+download_url+"\n"
        else
          output_text = patch_text+"\n"+patch_url+"\n"
        end
      end
      do_output = 0
      if search_arch.match(/all/)
        do_output = 1
      end
      if search_arch.downcase.match(/sparc/)
        if model.match(/^T|^M|^V/)
          do_output = 1
        end
      end
      if search_arch.downcase.match(/x86|i386/)
        if model.match(/^X|^B|^8|^6|^NX|^U24|^U27/)
          do_output = 1
        end
      end
      if do_output == 1
        if output_file.match(/[A-z,0-9]/)
          File.open(output_file, 'a') { |file| file.write(output_text) }
        else
          print output_text
        end
      end
      counter = counter+1
    end
  end
  return
end

# Traverse the firmware information hashes and output information

def handle_output(model,fw_urls,fw_text,output_type,output_file,latest_only,search_arch)
  if model == "all"
    fw_text.each do |model, text|
      print_output(model,fw_urls,fw_text,output_type,output_file,latest_only,search_arch)
    end
  else
    print_output(model,fw_urls,fw_text,output_type,output_file,latest_only,search_arch)
  end
  return
end

# Check local repository for zero length files (e.g. incorrect downloads)
# and delete them

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

# Check local configuration

def check_local_config
  [ $work_dir, $html_dir, $readme_dir, $firmware_dir ].each do |test_dir|
    if !Dir.exists?(test_dir)
      begin
        Dir.mkdir(test_dir)
      rescue
        puts "Cannot create directory "+test_dir
        exit
      end
    end
  end
  return
end

# Code to create and update a local Oracle system patch archive
# Currently only relevant to Solaris 10 or older

def update_patch_archive(search_arch,search_rel)
  zip_file    = ""
  readme_file = ""
  doc = open_patchdiag_xref()
  doc.each do |line|
    line.chomp
    if line.match(/^[0-9]/)
      (number,version,date,recommended,security,obsolete,bad,release,architecture,package,synopsis) = line.split("|")
      patch_no = number+"-"+version
      if !obsolete.match(/O/) and !bad.match(/[A-z]/) and !release.match(/Trusted/)
        if release.match(/Unbundled/)
          release = "all"
        end
        if !architecture.match(/[A-z]/)
          architecture = "all"
        end
        if release.match(/x86/) or architecture.match(/i386/)
          architecture = "x86"
          release      = release.split("_")[0]
        end
        if architecture.match(/sparc/)
          architecture = "sparc"
        end
        if architecture.match(/#{search_arch}/) or search_arch.match(/all/)
          if release.match(/#{search_rel}/) or search_rel.match(/all/)
            zip_file    = $work_dir+"/patches/"+architecture+"/"+release+"/"+patch_no+".zip"
            readme_file = $work_dir+"/readmes/"+architecture+"/"+release+"/README."+patch_no
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

# Get commandline switches of print help if none given

begin
  opt = Getopt::Std.getopts(options)
rescue
  print_usage(options)
  exit
end

if opt["a"]
  model = "all"
end

# If given -w switch set work directory

if opt["w"]
  $work_dir = opt["w"]
end

# If given a -M, -E, -P, or -R which involve local downloads get a list of the
# local repository so that duplicate files can be symlinked rather than
# downloaded again

if opt["M"] or opt["E"] or opt["R"] or opt["X"] or opt["V"]
  $file_list = []
  Find.find($work_dir) {|file_name| $file_list.push(file_name) if File.file?(file_name)}
  check_repository()
end

# If given a -m of -M or -t set the URL to be the Oracle System firmware page
# If given a -q set the URL to the Qlogic firmware page
# If given a -e or -E set the URL to the Emulex firmware page

if opt["m"] or opt["M"] or opt["t"]
  url = "http://www.oracle.com/technetwork/systems/patches/firmware/release-history-jsp-138416.html"
  if File.exists?(File.basename(url))
    url = File.basename(url)
  end
else
  if opt["d"] or opt ["q"]
    url = "https://getupdates.oracle.com/reports/patchdiag.xref"
    if File.exists?(File.basename(url))
      url = File.basename(url)
    end
  else
    if opt["e"] or opt['E']
      url = "http://www.emulex.com/interoperability/results/matrix-action/Interop/by-partner/?tx_elxinterop_interop%5Bpartner%5D=Oracle%20%28Sun%29&tx_elxinterop_interop%5Bsegment%5D=Servers&cHash=4f24beefa24e0dbfa5f76d523d29ffb7"
    end
  end
end

# Set search architecture

if opt["A"]
  search_arch = opt["A"]
else
  search_arch = "all"
end

# If given a -l only handle the latest revision of the firmware

if opt["l"]
  latest_only = 1
end

# If given a -v provide verbose output

if opt["v"]
  $verbose = 1
end

# If given a -b provide verbose output and run in test mode (no downloads)

if opt["b"]
  $verbose   = 1
  $test_mode = 1
end

# If given a -V print version information

if opt["V"]
  print_version()
  exit
end

# If given a -h or -? print help information

if opt["h"] or opt["?"]
  print_usage(options)
  exit
end

# If given a -o output to a file (currently only for CSV output)

if opt["o"]
  output_file = opt["o"]
  if File.exist?(output_file)
    File.delete(output_file)
  end
else
  output_file = ""
end

# If given a -i load url from a local file

if opt["i"]
  url = opt["i"]
  if !File.exist?(url)
    puts "File "+url+" does not exist"
    exit
  end
end

# If given a -c output in CSV format

if opt["c"]
  output_type = "CSV"
else
  output_type = "TXT"
end

check_local_config()

# If given -x get patchdiag.xref

if opt["x"]
  if opt["o"]
    $verbose    = 1
    output_file = opt["o"]
  else
    output_file = ""
  end
  get_patchdiag_xref(output_file)
end

# if given a -r -p or -R handle patch or README URLs

if opt["r"] or opt["p"] or opt["R"]
  if opt["p"]
    patch_no = opt["p"]
  else
    if opt["r"]
      patch_no = opt["r"]
    else
      patch_no = opt["R"]
    end
  end
  if !patch_no.match(/[0-9]/)
    puts "Invalid Patch Number"
    exit
  end
  if opt["o"]
    $verbose    = 1
    output_file = opt["o"]
  else
    output_file = ""
  end
  if opt["r"]
    get_patch_readme(patch_no,output_file)
  else
    if opt["R"]
      doc = open_patch_readme(patch_no)
      puts doc
    else
      get_patch_file(patch_no,output_file)
    end
  end
end

# If given -u process Oracle Solaris 11 SRU information

if opt["u"] or opt["U"]
  url = "https://support.oracle.com/epmos/faces/PatchSearchResults?searchdata=%3Ccontext+type%3D%22ADVANCED%22+search%3D%22%26lt%3BSearch%26gt%3B%0A%26lt%3BFilter+name%3D%26quot%3Bproduct_family%26quot%3B+op%3D%26quot%3Bis%26quot%3B+value%3D%26quot%3Btrue%26quot%3B%2F%26gt%3B%0A%26lt%3BFilter+name%3D%26quot%3Bproduct%26quot%3B+op%3D%26quot%3Bis%26quot%3B+value%3D%26quot%3B3-VFE6B2%26quot%3B%2F%26gt%3B%0A%26lt%3BFilter+name%3D%26quot%3Brelease%26quot%3B+op%3D%26quot%3Bis%26quot%3B+value%3D%26quot%3B400000110000%26quot%3B%2F%26gt%3B%0A%26lt%3BFilter+name%3D%26quot%3Bexclude_superseded%26quot%3B+op%3D%26quot%3Bis%26quot%3B+value%3D%26quot%3Bfalse%26quot%3B%2F%26gt%3B%0A%26lt%3B%2FSearch%26gt%3B%22%2F%3E"
  (sru_info,sru_urls) = search_oracle_sru_page(search_string,latest_only,url)
  if opt["U"]
    download_oracle_sru(sru_info,sru_urls)
  end
end


# If given a -q process Qlogic firmware information

if opt["q"]
  model = opt["q"]
  if model != "all"
    model = model.upcase
  end
  (fw_urls,fw_text) = search_qlogic_fw_page(model,url)
  handle_output(model,fw_urls,fw_text,output_type,output_file,latest_only,search_arch)
end

# If given a -d process disk firmware information

if opt["d"]
  model = opt["d"]
  if model != "all"
    model = model.upcase
  end
  (fw_urls,fw_text) = search_disk_fw_page(model,url)
  handle_output(model,fw_urls,fw_text,output_type,output_file,latest_only,search_arch)
end

# If given a -D process disk firmware downloads

if opt["D"]
  model = opt["D"]
  if model != "all"
    model = model.upcase
  end
  (fw_urls,fw_text) = search_disk_fw_page(model,url)
  handle_download_firmware(model,fw_urls,fw_text,latest_only,search_arch)
end

# If give -v process V series and other older hardware firmware

if opt["n"]
  model = opt["n"]
  if model != "all"
    model = model.upcase
  end
  (fw_urls,fw_text) = search_prom_fw_page(model,url)
  handle_output(model,fw_urls,fw_text,output_type,output_file,latest_only,search_arch)
end

# If given a -V process V series and older hardware firmware downloads

if opt["N"]
  model = opt["N"]
  if model != "all"
    model = model.upcase
  end
  (fw_urls,fw_text) = search_prom_fw_page(model,url)
  handle_download_firmware(model,fw_urls,fw_text,latest_only,search_arch)
end

# If given a -e process Emulex firmware information

if opt["e"]
  model = opt["e"]
  if model != "all"
    model = model.upcase
  end
  (fw_urls,fw_text) = search_emulex_fw_page(model,url)
  handle_output(model,fw_urls,fw_text,output_type,output_file,latest_only,search_arch)
end

# If given a -E process Emulex firmware downloads

if opt["E"]
  model = opt["E"]
  if model != "all"
    model = model.upcase
  end
  (fw_urls,fw_text) = search_emulex_fw_page(model,url)
  handle_download_firmware(model,fw_urls,fw_text,latest_only,search_arch)
end

# If given a -m process M series firmware information

if opt["m"]
  model = opt["m"]
  if model != "all"
    model = model.upcase
    model = model.gsub(/K/,'000')
  end
  (fw_urls,fw_text) = search_system_fw_page(model,url)
  handle_output(model,fw_urls,fw_text,output_type,output_file,latest_only,search_arch)
end

# If given a -M process M series firmware downloads

if opt["M"]
  model = opt["M"]
  if model != "all"
    model = model.upcase
    model = model.gsub(/K/,'000')
  end
  (fw_urls,fw_text) = search_system_fw_page(model,url)
  handle_download_firmware(model,fw_urls,fw_text,latest_only,search_arch)
end

# If given -H cleanup html directory

if opt["H"]
  if File.directory($html_dir)
    %x[rm $html_dir/*.html]
  end
  exit
end

# If given a -z or -t process zip files in repository

if opt["z"] or opt["t"]
  if opt["z"]
    model = opt["z"]
    search_suffix = ""
  end
  if opt["t"] or opt["o"]
    model = opt["t"]
    search_suffix = "pkg"
  end
  if model != "all"
    model = model.upcase
    model = model.gsub(/K/,'000')
  end
  (fw_urls,fw_text) = search_system_fw_page(model,url)
  handle_zipfile(model,fw_urls,fw_text,search_suffix,output_type,output_file,latest_only)
end

# If given a -Y process local patch repository

if opt["Y"]
  if !opt["A"]
    search_arch = "all"
  else
    search_arch = opt["A"]
  end
  if !opt["S"]
    search_rel = "all"
  else
    search_rel = opt["S"]
  end
  update_patch_archive(search_arch,search_rel)
end

# If given a -P search patchdiag.xref

if opt["P"]
  search_string = opt["P"]
  search_result = search_patchdiag_ref(search_string)
  puts search_result
end

# if given a -x output M Series XCP information

if opt["X"]
  model = opt["X"]
  if model != "all"
    model = opt["X"]
    model = model.upcase
    model = model.gsub(/K/,'000')
  end
  (fw_urls,fw_text) = search_xcp_fw_page(model)
  handle_output(model,fw_urls,fw_text,output_type,output_file,latest_only)
end

# If given a -m process M series firmware downloads

if opt["X"]
  model = opt["X"]
  if model != "all"
    model = model.upcase
    model = model.gsub(/K/,'000')
  end
  (fw_urls,fw_text) = search_xcp_fw_page(model)
  handle_download_firmware(model,fw_urls,fw_text,latest_only,search_arch)
end