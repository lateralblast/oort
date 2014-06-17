#!/usr/bin/env ruby

# Name:         firith (Firmeare Information Right In The Hand)
# Version:      0.6.1
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
require 'zipruby'
require 'fileutils'
require 'find'
require 'pathname'

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

$work_dir  = Dir.home+"/.goofball"
$verbose   = 0
$test_mode = 0

# Search the M Series firmware page for information
# This requires the use of selenium and a web browser as none of the ruby
# modules seem to work with the MOS site

def search_xcp_fw_page(search_xcp)
  xcp_url     = "https://support.oracle.com/epmos/faces/DocContentDisplay?id=1002631.1"
  output_file = "xcp.html"
  if !File.exists?(output_file)
    puts "Download "+xcp_url+" to "+output_file
    puts "and rerun script"
    exit
  end
  xcp_release = ""
  xcp_version = ""
  xcp_post    = ""
  xcp_models  = ""
  xcp_info    = ""
  mseries     = ""
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
        xcp_text = ""
        xcp_info = node.text
        xcp_info = xcp_info.split(/\n/)
        xcp_info.each do |line|
          line = line.gsub(/\s+/,' ')
          line = line.gsub(/^\s+/,'')
          line = line.chomp
          line = line.strip
          if line.match(/[A-z]|[0-9]/)
            if line.match(/^XCP/) and !line.match(/Release/) and !line.match(/XSCF/)
              xcp_release = line
              xcp_release = xcp_release.gsub(/ EOL/,'')
              xcp_release = xcp_release.gsub(/\s+/,'')
            else
              if line.match(/^0[0-9]/)
                xcp_version = line
              else
                if line.match(/^POST/) and line.match(/[0-9]/)
                  xcp_post = line
                else
                  if line.match(/ 20[0-9][0-9]/)
                    xcp_models = line
                    xcp_models = xcp_models.gsub(/ \- /,'')
                    xcp_models = xcp_models.gsub(/0M/,'0-M')
                  else
                    if xcp_version.match(/[0-9]/)
                      xcp_text="#{xcp_release} #{xcp_version} #{xcp_post} #{xcp_models}"
                      if xcp_text.match(/[A-z]/)
                        xcp_text = xcp_text.gsub(/\s+/,' ')
                        xcp_text = xcp_text.gsub(/\n/,'')
                        if xcp_text.match(/M3000/) and !xcp_text.match(/M3000\-/)
                          mseries = "M3000"
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
                        xcp_release = ""
                        xcp_version = ""
                        xcp_post    = ""
                        xcp_models  = ""
                        xcp_info    = ""
                        xcp_text    = ""
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
  fw_text = {}
  fw_urls = {}
  ["M3000","M4000","M5000","M8000","M9000"].each do |mseries|
    fw_text[mseries] = eval("#{mseries}_txts")
    fw_urls[mseries] = eval("#{mseries}_urls")
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
      doc.each do |readme_line|
        patch_text = line[10].chomp
        patch_url  = base_url+patch_no
        readme_line.chomp
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
        mos_username = line.split(/\=/)[1]
      end
      if line.match(/http-password/)
        mos_password = line.split(/\=/)[1]
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
  patch_no    = get_patch_full_id(patch_no)
  output_file = $work_dir+"/README."+patch_no
  get_patch_readme(patch_no,output_file)
  doc = IO.readlines(output_file)
  return doc
end

# If given a patch generate the URL for the README and download it

def get_patch_readme(patch_no,output_file)
  base_url = "https://getupdates.oracle.com/readme/"
  patch_no = get_patch_full_id(patch_no)
  if !output_file.match(/[A-z]/)
    output_file = $work_dir+"/README."+patch_no
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
  output_text = "http-passwd="+mos_password+"\n"
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

# Code to download a file using wget
# I tried using a ruby module but non of them seem to work reliably with
# Oracle site and/or Akamai redirects so it just uses wget for the moment
# If the URL cotains oracle, include MOS handling

def get_download(url,output_file)
  if !File.exists?(output_file)
    if $verbose == 1
      puts "Downloading: #{url}"
      puts "Destination: #{output_file}"
    end
    output_dir = File.dirname(output_file)
    if !Dir.exists?(output_dir)
      Dir.mkdir(output_dir)
    end
    if $test_mode == 0
      if url.match(/oracle/)
        mos_passwd_file = Dir.home+"/.mospasswd"
        if !File.exists?(mos_passwd_file)
          (mos_username,mos_password) = get_mos_details()
          create_mos_passwd_file(mos_username,mos_password)
        end
        if $verbose == 1
          command = "export WGETRC="+mos_passwd_file+"; wget --no-check-certificate "+"\""+url+"\""+" -O "+"\""+output_file+"\""
        else
          command = "export WGETRC="+mos_passwd_file+"; wget --no-check-certificate "+"\""+url+"\""+" -q -O "+"\""+output_file+"\""
        end
      else
        if $verbose == 1
          command = "wget "+"\""+url+"\""+" -O "+"\""+output_file+"\""
        else
          command = "wget "+"\""+url+"\""+" -q -O "+"\""+output_file+"\""
        end
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

# Open patchdiag,xref and read it into an array

def open_patchdiag_xref()
  output_file = $work_dir+"/patchdiag.xref"
  get_patchdiag_xref(output_file)
  doc= I O.readlines(output_file)
  return doc
end

# Get patchdiag.xref

def get_patchdiag_xref(output_file)
  url = "https://getupdates.oracle.com/reports/patchdiag.xref"
  if !output_file.match(/[A-z]/)
    output_file = $work_dir+"/patchdiag.xref"
  end
  check_file_age(output_file)
  if !File.exists?(output_file)
    # have to use wget as all modules break with akamai redirect
    # have tried all the TLS workarounds
    command = "wget "+url+" -O "+output_file
    system(command)
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
  output_file = "emulex.html"
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
  if search_model.match(/^SG/)
    search_model = hba_model[search_model]
  else
    if search_model != "all"
      search_model = search_model.gsub(/PEM/,'Pem')
      search_model = search_model.gsub(/PE/,'Pe')
    end
  end
  lc_model = search_model.downcase
  boot_url = "firmware-and-boot-code"
  doc.css("table tr a").each do |node|
    urls = []
    txts = []
    if node.text.match(/^LP/)
      model = node.text.upcase
    end
    if node.text.match(/^SG/)
      sun_model = node.text
    end
    suburl = node[:href]
    if suburl.match(/firmware/)
        doc_url = suburl.gsub(/drivers/,boot_url)
        if sun_model.match(/^SG/)
          fw_info = model+" ("+sun_model+")"
        else
          fw_info = model
        end
        output_file = model+".html"
        get_url(doc_url,output_file)
        subdoc = Nokogiri::HTML(File.open(output_file))
        subdoc.css("table tr").each do |subnode|
        if subnode.text.match(/Open Boot/)
          zip_url = subnode.css("td a").to_s.split(/"/)[1]
          if fw_info.match(/SG/)
            fw_version = subnode.text.split(/\s+/)[5..6].join(" ")
          else
            fw_version = subnode.text.split(/\s+/)[4..5].join(" ").gsub(/Platform:/,'')
          end
          fw_info = fw_info+" "+fw_version
          txts.push(fw_info)
          if zip_url
            if zip_url.to_s.match(/http/)
              urls.push(zip_url)
            else
              urls.push(doc_url)
            end
          else
            urls.push(doc_url)
          end
          if model == search_model.upcase or search_model == "all"
            if sun_model.match(/^SG/)
              fw_text[sun_model] = txts
              fw_urls[sun_model] = urls
            end
            fw_text[model] = txts
            fw_urls[model] = urls
          end
        end
      end
    end
  end
  return fw_urls,fw_text
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

def print_usage()
  puts
  puts "Usage: "+$0+" -[h|V] -[q|m|d|e|M] [MODEL|all] -[p|r] [PATCH] -[i|o] [FILE] -w [WORK_DIR] -t -v"
  puts
  puts "-V:          Display version information"
  puts "-h:          Display usage information"
  puts "-v:          Verbose output"
  puts "-b:          Test mode (don't perform downloads)"
  puts "-m all:      Display firmware information for all machines"
  puts "-M all:      Download firmware patch for all models from MOS (Requires Username and Password)"
  puts "-z all:      Display firmware zip file contents for all models"
  puts "-t all:      Display TFTP file for all models"
  puts "-d all:      Display firmware information for all disks"
  puts "-e all:      Display firmware information for all Emulex HBAs"
  puts "-E all:      Download firmware patch for all Emulex HBAs"
  puts "-q all:      Display firmware information for all Qlogic HBAs"
  puts "-X all:      Display firmware information for all M Series"
  puts "-m MODEL:    Display firmware information for a specific model (eg. X2-4)"
  puts "-M MODEL:    Download firmware patch for a specific model (eg. X2-4) from MOS (Requires Username and Password)"
  puts "-z MODEL:    Display firmware zip file contents for a specific model (eg. X2-4)"
  puts "-t MODEL:    Display TFTP file for a specfic model (e.g. T5440)"
  puts "-d MODEL:    Display firmware information for a specific model of disk (eg. MAW3300FC)"
  puts "-e MODEL:    Display firmware information for a specific model of Emulex HBA (eg. SG-XPCIEFCGBE-E8-Z)"
  puts "-E MODEL:    Download firmware patch for a specific model of Emulex HBA"
  puts "-q MODEL:    Display firmware information for a specific model of Qlogic HBA (eg. SG-XPCIEFCGBE-Q8-Z)"
  puts "-X MODEL:    Display firmware information for specific M Series model (e.g. M3000)"
  puts "-i FILE:     Open a locally saved HTML file for processing rather then fetching it"
  puts "-p PATCH:    Download a patch from MOS (Requires Username and Password)"
  puts "-r PATCH:    Download README for a patch from MOS (Requires Username and Password)"
  puts "-R PATCH:    Download README for a patch from MOS (Requires Username and Password) and send to STDOUT"
  puts "-P SEARCH:   Search patchdiag.xref"
  puts "-w WORK_DIR: Set work directory (Default is ~/.goofball)"
  puts "-c:          Output in CSV format (default text)"
  puts "-x:          Download patchdiag.xref"
  puts "-l:          Only show latest firmware versions (used with -m)"
  puts "-Y:          Update patch archive"
  puts "-S RELEASE:  Set Solaris release (used with -Z)"
  puts "-A RELEASE:  Set architecture (used with -Z)"
  puts "-o FILE:     Open a file for writing"
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

# This code takes a model and the information gathered from the system firmware
# page and crafts a URL for the patch download
# There seems to be some vague consistency for the patch file names,
# however it does change from one model to another

def get_oracle_download_url(model,patch_text,patch_url)
  base_url      = "https://getupdates.oracle.com/all_unsigned/"
  download_url  = ""
  head_url      = ""
  patch_no      = ""
  rev_text      = ""
  download_file = ""
  if !patch_url
    if $verbose == 1
      puts "No patch URL found for "+model+" ["+patch_text+"] \n"
    end
    return
  end
  if !patch_url.match(/index/)
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
    [' FW '].each do |search_string|
      if patch_text.match(/#{search_string}/) and !patch_text.match(/RAID|InfiniBand|ConnectX|LSI|CR/)
        rev_text = patch_text.split("#{search_string}")[0]
        rev_text = rev_text.split(" ")[-1].gsub(/\./,'')
      end
    end
    if model.match(/N6000/)
      rev_text = "100"
    end
    patch_no = patch_url.split("=")[1].to_s
    if patch_no.match(/\-/)
      download_file = patch_no+".zip"
      download_url  = base_url+download_file
    else
      if !patch_text.match(/SysFW|System Firmware|Hardware Programmables|Workstation|SW|3\.4 /) and !model.match(/X6275|X6270M2|X6270$|X2250|X4200|X4470|X4800|X2-8/)
        if rev_text.length < 3
          rev_text = rev_text+"0"
        end
      end
      download_file = "p"+patch_no+"_"+rev_text+"_Generic.zip"
      download_url  = base_url+download_file
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
  download_file = $work_dir+"/"+model.downcase+"/"+file_name
  if !File.exists?(download_file)
    existing_file = $file_list.select {|existing_file| existing_file =~ /#{file_name}/}
    if existing_file[0]
      existing_file = existing_file[0]
      dir_name      = Pathname.new(download_file)
      dir_name      = dir_name.dirname
      if !Dir.exists?(dir_name)
        Dir.mkdir(dir_name)
      end
      if existing_file != download_file
        if $verbose == 1
          puts "Found "+existing_file+"\n"
          puts "Symlinking "+existing_file+" to "+download_file+"\n"
        end
        File.symlink(existing_file,download_file)
      end
    else
      get_download(download_url,download_file)
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
    Zip::Archive.open(download_file) do |archive|
      entry_names = archive.map do |file|
        if search_suffix.match(/[A-z]/)
          if search_suffix.match(/pkg/)
            if file.name.match(/pkg$|bin$|iso$|Ultra[0-9][0-9]$|[0-9][0-9][0-9][0-9]\.tar\.gz|[0-9][0-9][0-9]\.zip/)
              tftp_name = File.basename(file.name)
              if !tftp_name.match(/legal|remote|recovery|^fw|^q8|^firmware/)
                tftp_file = File.dirname(download_file)
                tftp_file = tftp_file+"/"+file.name
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
            output_text = model+","+file.name+"\n"
          else
            output_text = file.name+"\n"
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

def handle_download_firmware(search_model,fw_urls,fw_text,latest_only)
  counter = 0
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

def print_output(model,fw_urls,fw_text,output_type,output_file,latest_only)
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
      else
        download_url = ""
      end
      if output_type == "CSV"
        output_text = model+","+fw_text[model][counter]+","+fw_urls[model][counter]+","+download_url+"\n"
      else
        if download_url.match(/[A-z]/)
          output_text = fw_text[model][counter]+"\n"+fw_urls[model][counter]+"\n"+download_url+"\n"
        else
          output_text = fw_text[model][counter]+"\n"+fw_urls[model][counter]+"\n"
        end
      end
      if output_file.match(/[A-z,0-9]/)
        File.open(output_file, 'a') { |file| file.write(output_text) }
      else
        print output_text
      end
      counter = counter+1
    end
  end
  return
end

# Traverse the firmware information hashes and output information

def handle_output(model,fw_urls,fw_text,output_type,output_file,latest_only)
  if model == "all"
    fw_text.each do |model, text|
      print_output(model,fw_urls,fw_text,output_type,output_file,latest_only)
    end
  else
    print_output(model,fw_urls,fw_text,output_type,output_file,latest_only)
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
  if !Dir.exists?($work_dir)
    Dir.mkdir($work_dir)
  end
  return
end

# Code to create and update a local Oracle system patch archive
# Currently only relevant to Solaris 10 or older

def update_patch_archive(search_architecture,search_release)
  zip_file    = ""
  readme_file = ""
  doc=open_patchdiag_xref()
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
        if architecture.match(/#{search_architecture}/) or search_architecture.match(/all/)
          if release.match(/#{search_release}/) or search_release.match(/all/)
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
  opt = Getopt::Std.getopts("VZ?abchlvxA:E:M:P:R:S:X:d:e:i:m:o:p:q:r:t:w:z:")
rescue
  print_usage()
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

if opt["M"] or opt["E"] or opt["R"]
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
  print_usage()
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

# If given a -q process Qlogic firmware information

if opt["q"]
  model = opt["q"]
  if model != "all"
    model = model.upcase
  end
  (fw_urls,fw_text) = search_qlogic_fw_page(model,url)
  handle_output(model,fw_urls,fw_text,output_type,output_file,latest_only)
end

# If given a -d process disk firmware information

if opt["d"]
  model = opt["d"]
  if model != "all"
    model = model.upcase
  end
  (fw_urls,fw_text) = search_disk_fw_page(model,url)
  handle_output(model,fw_urls,fw_text,output_type,output_file,latest_only)
end

# If given a -e process Emulex firmware information

if opt["e"]
  model = opt["e"]
  if model != "all"
    model = model.upcase
  end
  (fw_urls,fw_text) = search_emulex_fw_page(model,url)
  handle_output(model,fw_urls,fw_text,output_type,output_file,latest_only)
end

# If given a -E process Emulex firmware downloads

if opt["E"]
  model = opt["E"]
  if model != "all"
    model = model.upcase
  end
  (fw_urls,fw_text) = search_emulex_fw_page(model,url)
  handle_download_firmware(model,fw_urls,fw_text,latest_only)
end

# If given a -m process M series firmware information

if opt["m"]
  model = opt["m"]
  if model != "all"
    model = model.upcase
    model = model.gsub(/K/,'000')
  end
  (fw_urls,fw_text) = search_system_fw_page(model,url)
  handle_output(model,fw_urls,fw_text,output_type,output_file,latest_only)
end

# If given a -m process M series firmware downloads

if opt["M"]
  model = opt["M"]
  if model != "all"
    model = model.upcase
    model = model.gsub(/K/,'000')
  end
  (fw_urls,fw_text) = search_system_fw_page(model,url)
  handle_download_firmware(model,fw_urls,fw_text,latest_only)
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
    search_architecture = "all"
  else
    search_architecture = opt["A"]
  end
  if !opt["S"]
    search_release = "all"
  else
    search_release = opt["S"]
  end
  update_patch_archive(search_architecture,search_release)
end

# If given a -P search patchdiag.xref

if opt["P"]
  search_string = opt["P"]
  search_result = search_patchdiag_ref(search_string)
  puts search_result
end

# if given a -X output M Series XCP information

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
