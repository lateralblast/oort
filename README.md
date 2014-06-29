![alt tag](https://raw.githubusercontent.com/lateralblast/oort/master/OracleSunBoxes.jpg)

OORT
====

Oracle OBP Reporting/Retrieval Tool

Introduction
------------

This script parses the Oracle (and in the future other) firmware pages to get
firmware information. It returns the versions of firmware (top most is the current)
and their URLs. It can also download the firmware to a local repository if needed.

For example to find the latest version of system firmware available for the T5-4:

```
$ oort.rb -m t5-4 -l
T5-4:
SPARC T5-4 Server Sun System Firmware 9.2.0.a (based on ILOM 3.2.1) SysFW (24-Apr-2014) OBP 4.36.0
https://support.oracle.com/epmos/faces/ui/patch/PatchDetail.jspx?patchId=18544280
https://updates.oracle.com/Orion/Services/download/p18544280_92_Generic.zip?aru=17568338&patch_file=p18544280_92_Generic.zip
```

Long term this script will hopefully slowly bring the various firmware information
tools I have into one script.

Features:

- Get a list of available system firmware for particular model(s)
- Get a list of available XCF firmware for particular M series model(s)
- Get a list of available SRUs for Solaris 11
- Search Oracle Solaris patchdiag.xref patch list (Solaris 10 and earlier)
- Download system firmware for particular model(s)
- Download XCF firmware for particular M series model(s)
- Get a list of firware for Emulex or QLogic Fibre Channel adaptor(s)
- Get a list of firmware for disks(s)
- Extract version information from system firmware download
  - Useful for documentation
  - Can be used in conjunction with [sice](https://github.com/lateralblast/sice) script to update firmware
- Create a local repository of patches

Issues:

- MOS login is slow (up to 20s) as it has to wait for javascript
  - As such the script may take a while to run
  - Where possible files are cached locally so they don't need to be fetched each time
- To determine the download URL for firmware patches a MOS login is required
  - This is because the ARU number needs to be retrieved in order to generate the URL

License
-------

This software is licensed as CC-BA (Creative Commons By Attrbution)

http://creativecommons.org/licenses/by/4.0/legalcode

Information
-----------

The Oracle downloads require a support contract and a MOS account. To prevent
the possibility of displaying username and password details the script sets the
WGETRC environment variable to read them from a file. If the file does not exist
it will ask you for the details and create a file. The files permission are set
so only you can read it, e.g.

```
$ cat ~/.mospasswd
http-user=Firstname.Lastname@company.com
http-password=P@$$w0r]
check-certificate=off
```

Resources
---------

[Oracle firmware and patch resources](https://github.com/lateralblast/oort/wiki/3.-Resources)

Usage
-----

[Information on usage](https://github.com/lateralblast/oort/wiki/1.-Usage)


Examples
--------

[Examples of usage](https://github.com/lateralblast/oort/wiki/2.-Examples)

Requirements
------------

Required Ruby Gems:

- rubygems
- nokogiri
- open-uri
- getopt/std
- fileutils
- find
- pathname
- selenium-webdriver
- phantomjs
- mechanize
