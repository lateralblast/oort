goofball
========

Get Oracle OBP Firmware 

This script parses the Oracle firmware page to get firmware information.
It returns the versions of firmware (top most is the current) and their
URLs. 

The Oracle downloads require a support contract and a MOS account.
You can prevent the script from displaying your MOS username and password
on the command line by creating a ~/.mospasswd file and putting your
username and password in it on one line separated by a colon.

	$ cat ~/.mospasswd
	Firstname.Lastname@company.com:P@$$W0rd

The Oracle downloads for patches and READMEs currently use wget as all
the ruby web modules fail with the Oracle site. Similarly the code
to download the XSCF firmware uses Selenium and Safari due to poorly formatted
html and hidden elements on the MOS login page. I've tried PhantomJS
and it fails.

Oracle Firmware URL:

http://www.oracle.com/technetwork/systems/patches/firmware/release-history-jsp-138416.html

Oracle README URL:

https://getupdates.oracle.com/readme/PATCH_NO-PATCH_REV

Eg:

https://getupdates.oracle.com/readme/119255-01

Oracle Patch URL:

https://getupdates.oracle.com/all_unsigned/PATCH_NO-PATCH_REV

Eg:

https://getupdates.oracle.com/all_unsigned/119255-01.zip

Oracle patchdiag.xref URL:

https://getupdates.oracle.com/reports/patchdiag.xref

Emulex Firmware URL:

http://www.emulex.com/downloads/oracle.html

Qlogic Firmware URLs:

http://driverdownloads.qlogic.com/QLogicDriverDownloads_UI/SearchByProductOracle.aspx?oemid=124&productid=928&OSTYPE=Solaris&category=1
http://driverdownloads.qlogic.com/QLogicDriverDownloads_UI/SearchByProductOracle.aspx?oemid=124&productid=928&OSTYPE=Solaris&category=2
http://driverdownloads.qlogic.com/QLogicDriverDownloads_UI/SearchByProductOracle.aspx?oemid=124&productid=928&OSTYPE=Solaris&category=3

M Series XSCF web page:

https://support.oracle.com/epmos/faces/DocContentDisplay?id=1002631.1

Usage
=====

	./goofball.rb-[h|V] -[q|m|d|e|M] [MODEL|all] -[p|r] [PATCH] -[i|o] [FILE] -w [WORK_DIR] -t -v

	-V:          Display version information
	-h:          Display usage information
	-v:          Verbose output
	-b:          Test mode (don't perform downloads)
	-m all:      Display firmware information for all machines
	-z all:      Display firmware zip file contents for all models
	-t all:      Display TFTP file for all models
	-M all:      Download firmware patch for all models from MOS (Requires Username and Password)
	-d all:      Display firmware information for all disks
	-e all:      Display firmware information for all Emulex HBAs
	-q all:      Display firmware information for all Qlogic HBAs
	-X all:      Display firmware information for all M Series
	-m MODEL:    Display firmware information for a specific model (eg. X2-4)
	-z MODEL:    Display firmware zip file contents for a specific model (eg. X2-4)
	-t MODEL:    Display TFTP file for a specfic model (e.g. T5440)
	-M MODEL:    Download firmware patch for a specific model (eg. X2-4) from MOS (Requires Username and Password)
	-d MODEL:    Display firmware information for a specific model of disk (eg. MAW3300FC)
	-e MODEL:    Display firmware information for a specific model of Emulex HBA (eg. SG-XPCIEFCGBE-E8-Z)
	-q MODEL:    Display firmware information for a specific model of Qlogic HBA (eg. SG-XPCIEFCGBE-Q8-Z)
	-X MODEL:    Display firmware information for specific M Series model (e.g. M3000)
	-i FILE:     Open a locally saved HTML file for processing rather then fetching it
	-p PATCH:    Download a patch from MOS (Requires Username and Password)
	-r PATCH:    Download README for a patch from MOS (Requires Username and Password)
	-R PATCH:    Download README for a patch from MOS (Requires Username and Password) and send to STDOUT
	-P SEARCH:   Search patchdiag.xref
	-w WORK_DIR: Set work directory (Default is ~/.goofball)
	-c:          Output in CSV format
	-x:          Download patchdiag.xref
	-l:          Only show latest firmware versions (used with -m)
	-Y:          Update patch archive
	-S RELEASE:  Set Solaris release (used with -Y)
	-A RELEASE:  Set architecture (used with -Y)
	-o FILE:     Open a file for writing (CSV mode)


Examples
========

Display firmware information for the X2-4:

	$./goofball -m x2-4
	X2-4:
	ILOM 3.1.2.24.c r81341 BIOS vers. 16.04.02.00
	https://support.oracle.com/epmos/faces/ui/patch/PatchDetail.jspx?patchId=16978905
	ILOM 3.1.2.24.b r79266 BIOS vers. 16.04.02.00
	https://support.oracle.com/epmos/faces/ui/patch/PatchDetail.jspx?patchId=16404931
	ILOM 3.1.2.24.a r75561 BIOS vers. 16.04.01.05
	https://support.oracle.com/epmos/faces/ui/patch/PatchDetail.jspx?patchId=14579071
	ILOM 3.1.2.24 r73820 BIOS vers. 16.04.01.02
	https://support.oracle.com/epmos/faces/ui/patch/PatchDetail.jspx?patchId=14099616
	ILOM 3.0.16.12.a r70287 BIOS vers. 16.03.01.03
	https://support.oracle.com/epmos/faces/ui/patch/PatchDetail.jspx?patchId=13648432
	ILOM 3.0.16.12 r65661 BIOS vers. 16.02.01.01
	https://support.oracle.com/epmos/faces/ui/patch/PatchDetail.jspx?patchId=12886608
	ILOM 3.0.14.20.a r64405 BIOS vers. 16.01.01.19 (only required on Windows with 1Tb configuration)
	https://support.oracle.com/epmos/faces/ui/patch/PatchDetail.jspx?patchId=12677099
	ILOM 3.0.14.20 r63740 BIOS vers. 16.01.01.18
	https://support.oracle.com/epmos/faces/ui/patch/PatchDetail.jspx?patchId=12673454

Output latest firmware TFTP information as CSV (Warning this will download the firmware also):

	$ ./goofball.rb -t all -w /export/firmware -l -c -o firmware.txt

Display firmware for all Emulex HBAs:

	$ ./goofball.rb -e all
	SG-XPCIEFCGBE-E8-Z:
	Firmware Version 1.11a5
	http://www.emulex.com/downloads/oracle/sg-xpciefcgbe-e8-z/firmware-and-boot-code.html
	SG-XPCIE1FC-EM8-ZSG-XPCIE2FC-EM8-Z:
	Firmware Version 1.11a5
	http://www.emulex.com/downloads/oracle/sg-xpcie1fc-em8-z-and-sg-xpcie2fc-em8-z/firmware-and-boot-code.html
	SG-XPCIE1FC-EM4SG-XPCIE2FC-EM4:
	Firmware version 2.82a4
	http://www.emulex.com/downloads/oracle/sg-xpcie1fc-em4-and-sg-xpcie2fc-em4/firmware-and-boot-code.html
	SG-XPCI1FC-EM4-Z SG-XPCI2FC-EM4-Z:
	Firmware version 2.82a3
	http://www.emulex.com/downloads/oracle/sg-xpci1fc-em4-z-and-sg-xpci2fc-em4-z/firmware-and-boot-code.html
	SG-XPCIE20FC-NEM-Z:
	Firmware Version 2.82a4 
	http://www.emulex.com/downloads/oracle/sg-xpcie20fc-nem-z.html
	SG-XPCIE2FC-EB4-Z:
	Firmware Version 2.82a4
	http://www.emulex.com/downloads/oracle/sg-xpcie2fc-eb4-z/firmware-and-boot-code.html
	SG-XPCIE2FC-ATCA-Z:
	Firmware Version 2.82a4
	http://www.emulex.com/downloads/oracle/sg-xpcie2fc-atca-z/firmware-and-boot-code.html
	SG-XPCI1FC-EM2 SG-XPCI2FC-EM2:
	Firmware Version 1.92a1
	http://www.emulex.com/downloads/oracle/sg-xpci1fc-em2-and-sg-xpci2fc-em2/firmware-and-boot-code.html

Display firmware for all Qlogic HBAs:

	./goofball.rb -q all
	SG-XPCIEFCGBE-Q8-Z:
	8Gb/sec PCI Express Dual FC / Dual Gigabit Ethernet Host Adapter ExpressModule, QLogic Firmware Version 2.5.2
	http://driverdownloads.qlogic.com/QLogicDriverDownloads_UI/SearchByProductOracle.aspx?oemid=124&productid=928&OSTYPE=Solaris&category=3
	SG-XPCIE2FC-QB4-Z:
	4Gb/sec PCI Express Dual Fibre Channel ExpressModule Host Adapter, QLogic FCode 2.01, BIOS 2.02
	https://support.oracle.com/epmos/faces/ui/patch/PatchDetail.jspx?patchId=123305-04
	SG-XPCIE2FCGBE-Q-Z:
	4Gb/sec PCI Express Dual FC / Dual Gigabit Ethernet ExpressModule Host Adapter, QLogic FCode 2.01, BIOS 2.02
	https://support.oracle.com/epmos/faces/ui/patch/PatchDetail.jspx?patchId=123305-04
	SG-XPCI2FC-QF4-Z:
	4Gb PCI-X Dual FC Host Adapter FCode 2.01, BIOS 2.02
	https://support.oracle.com/epmos/faces/ui/patch/PatchDetail.jspx?patchId=123305-04
	SG-XPCIE1FC-QF8-Z:
	8Gigabit/Sec PCI Express Single FC Host Adapter Firmware Version 2.5.2
	http://driverdownloads.qlogic.com/QLogicDriverDownloads_UI/SearchByProductOracle.aspx?oemid=124&productid=928&OSTYPE=Solaris&category=3
	SG-XPCIE2FC-QF8-Z:
	8Gigabit/Sec PCI Express Dual FC Host Adapter Firmware Version 2.5.2
	http://driverdownloads.qlogic.com/QLogicDriverDownloads_UI/SearchByProductOracle.aspx?oemid=124&productid=928&OSTYPE=Solaris&category=3
	SG-XPCI1FC-QF4-Z:
	4Gb PCI-X Single FC Host Adapter FCode 2.01, BIOS 2.02
	https://support.oracle.com/epmos/faces/ui/patch/PatchDetail.jspx?patchId=123305-04
	SG-XPCIE1FC-QF4-Z:
	4Gigabit/Sec PCI Express Single FC Host Adapter FCode 2.01, BIOS 2.02
	https://support.oracle.com/epmos/faces/ui/patch/PatchDetail.jspx?patchId=123305-04
	SG-XPCIE2FC-QF4-Z:
	4Gigabit/Sec PCI Express Dual FC Host Adapter FCode 2.01, BIOS 2.02
	https://support.oracle.com/epmos/faces/ui/patch/PatchDetail.jspx?patchId=123305-04

Download latest firmware for X6270M2:

	$ ./goofball.rb -M X6270M2 -w /export/firmware
	Downloading: https://getupdates.oracle.com/all_unsigned/p14568638_141_Generic.zip
	Destination: /export/firmware/x6270m2/p14568638_141_Generic.zip

Display TFTP boot image information for X6270M2:

	$ ./goofball.rb -t X6270M2 -w /export/firmware
	X6270M2:
	TFTP file: ILOM-3_0_16_11_h_r75207-Sun_Blade_X6270M2.pkg
	Location:  /export/firmware/x6270m2/ILOM_and_BIOS/ILOM-3_0_16_11_h_r75207-Sun_Blade_X6270M2.pkg

Display all M3000 XSCF firmware history:

	$ ./goofball.rb -X M3000
	M3000:
	XCP1115 02.32.0000 01.11.0005 POST 2.17.0 4.33.5.d M3000-M9000 April 2013
	https://support.oracle.com/epmos/faces/DocContentDisplay?id=1002631.1
	XCP1114 02.32.0000 01.11.0004 POST 2.17.0 4.33.5.d M3000-M9000 November 2012
	https://support.oracle.com/epmos/faces/DocContentDisplay?id=1002631.1
	XCP1113 02.29.0000 01.11.0003 POST 2.17.0 4.33.5.a M3000-M9000 July 2012
	https://support.oracle.com/epmos/faces/DocContentDisplay?id=1002631.1
	XCP1112 02.29.0000 01.11.0002 POST 2.17.0 4.33.5.a M3000-M9000 May 2012
	https://support.oracle.com/epmos/faces/DocContentDisplay?id=1002631.1
	XCP1111 02.29.0000 01.11.0000 POST 2.17.0 4.33.5.a M3000-M9000 April 2012
	https://support.oracle.com/epmos/faces/DocContentDisplay?id=1002631.1
	XCP1110 02.29.0000 01.11.0000 POST 2.17.0 4.33.5.a M3000-M9000 February 2012
	https://support.oracle.com/epmos/faces/DocContentDisplay?id=1002631.1
	XCP1102 02.24.0000 01.10.0002 POST 2.15.0 4.33.0.a M3000-M9000 June 2011
	https://support.oracle.com/epmos/faces/DocContentDisplay?id=1002631.1
	XCP1101 02.21.0000 01.10.0001 POST 2.15.0 4.24.16 M3000-M9000 Mar 2011
	https://support.oracle.com/epmos/faces/DocContentDisplay?id=1002631.1
	XCP1100 02.18.0000 01.10.0000 POST 2.14.0 4.24.15 M3000-M9000 Dec 2010
	https://support.oracle.com/epmos/faces/DocContentDisplay?id=1002631.1
	XCP1093 02.16.0000 01.09.0003 POST 2.14.0 4.24.14 M3000-M9000 Aug 2010
	https://support.oracle.com/epmos/faces/DocContentDisplay?id=1002631.1
	XCP1092 02.14.0000 01.09.0002 POST 2.13.0 4.24.13 M3000-M9000 Apr 2010
	https://support.oracle.com/epmos/faces/DocContentDisplay?id=1002631.1
	XCP1091 02.13.0000 01.09.0001 POST 2.13.0 4.24.12 M3000-M9000 Nov 2009
	https://support.oracle.com/epmos/faces/DocContentDisplay?id=1002631.1
	XCP1090 02.11.0000 01.09.0000 POST 2.11.0 4.24.11 M3000-M9000 Aug 2009
	https://support.oracle.com/epmos/faces/DocContentDisplay?id=1002631.1
	XCP1082 02.09.0000 01.08.0005 POST 2.9.0 OBP 4.24.10 M3000-M9000 May 2009
	https://support.oracle.com/epmos/faces/DocContentDisplay?id=1002631.1
	XCP1081 02.08.0000 01.08.0004 POST 2.8.0 OBP 4.24.10 M3000-M9000 Feb 2009
	https://support.oracle.com/epmos/faces/DocContentDisplay?id=1002631.1
	XCP1080 02.07.0000 01.08.0002 POST 2.7.0 OBP 4.24.10 M3000 31st Oct 2008 M4000-M9000 mid Nov 2008
	https://support.oracle.com/epmos/faces/DocContentDisplay?id=1002631.1
