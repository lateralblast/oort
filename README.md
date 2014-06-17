![alt tag](https://raw.githubusercontent.com/lateralblast/firith/master/firith.jpg)

> “And you, Ring-bearer,’ she said, turning to Frodo. ‘I come to you last who
<br>
> are not last in my thoughts. For you I have prepared this.’ She held up a
<br>
> small crystal phial: it glittered as she moved it, and rays of white light
<br>
> sprang from her hand. ‘In this phial,’ she said, ‘is caught the light of
<br>
> Eärendil’s star, set amid the waters of my fountain. It will shine still
<br>
> brighter when night is about you. May it be a light to you in dark places,
<br>
> when night is about you. May it be a light to you in dark places, when all
<br>
> all other lights go out.

FIRITH
======

Firmware Information Right In The Hand

Information
-----------

This script parses the Oracle (and in the future other) firmware pages to get
firmware information. It returns the versions of firmware (top most is the current)
and their URLs.

License
-------

This software is licensed as CC-BA (Creative Commons By Attrbution)

http://creativecommons.org/licenses/by/4.0/legalcode

Usage
-----

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

Emulex Firmware URLs:

http://www.emulex.com/products/fibre-channel-hbas/oracle-branded/selection-guide/
http://www.emulex.com/interoperability/results/matrix-action/Interop/by-partner/?tx_elxinterop_interop%5Bpartner%5D=Oracle%20%28Sun%29&tx_elxinterop_interop%5Bsegment%5D=Servers&cHash=4f24beefa24e0dbfa5f76d523d29ffb7

Qlogic Firmware URLs:

http://driverdownloads.qlogic.com/QLogicDriverDownloads_UI/SearchByProductOracle.aspx?oemid=124&productid=928&OSTYPE=Solaris&category=1
http://driverdownloads.qlogic.com/QLogicDriverDownloads_UI/SearchByProductOracle.aspx?oemid=124&productid=928&OSTYPE=Solaris&category=2
http://driverdownloads.qlogic.com/QLogicDriverDownloads_UI/SearchByProductOracle.aspx?oemid=124&productid=928&OSTYPE=Solaris&category=3

M Series XSCF web page:

https://support.oracle.com/epmos/faces/DocContentDisplay?id=1002631.1

Usage
=====

```
$ firith.rb -[h|V] -[q|m|d|e|E|M|X] [MODEL|all] -[p|r] [PATCH] -[i|o] [FILE] -w [WORK_DIR] -[t|z] -[v|b] -c

-V:          Display version information
-h:          Display usage information
-v:          Verbose output
-b:          Test mode (don't perform downloads)
-m all:      Display firmware information for all machines
-M all:      Download firmware patch for all models from MOS (Requires Username and Password)
-z all:      Display firmware zip file contents for all models
-t all:      Display TFTP file for all models
-d all:      Display firmware information for all disks
-e all:      Display firmware information for all Emulex HBAs
-E all:      Download firmware patch for all Emulex HBAs
-q all:      Display firmware information for all Qlogic HBAs
-X all:      Display firmware information for all M Series
-m MODEL:    Display firmware information for a specific model (eg. X2-4)
-M MODEL:    Download firmware patch for a specific model (eg. X2-4) from MOS (Requires Username and Password)
-z MODEL:    Display firmware zip file contents for a specific model (eg. X2-4)
-t MODEL:    Display TFTP file for a specfic model (e.g. T5440)
-d MODEL:    Display firmware information for a specific model of disk (eg. MAW3300FC)
-e MODEL:    Display firmware information for a specific model of Emulex HBA (eg. SG-XPCIEFCGBE-E8-Z)
-E MODEL:    Download firmware patch for a specific model of Emulex HBA
-q MODEL:    Display firmware information for a specific model of Qlogic HBA (eg. SG-XPCIEFCGBE-Q8-Z)
-X MODEL:    Display firmware information for specific M Series model (e.g. M3000)
-i FILE:     Open a locally saved HTML file for processing rather then fetching it
-p PATCH:    Download a patch from MOS (Requires Username and Password)
-r PATCH:    Download README for a patch from MOS (Requires Username and Password)
-R PATCH:    Download README for a patch from MOS (Requires Username and Password) and send to STDOUT
-P SEARCH:   Search patchdiag.xref
-w WORK_DIR: Set work directory (Default is ~/.firith)
-c:          Output in CSV format
-x:          Download patchdiag.xref
-l:          Only show latest firmware versions (used with -m)
-Y:          Update patch archive
-S RELEASE:  Set Solaris release (used with -Z)
-A RELEASE:  Set architecture (used with -Z)
-o FILE:     Open a file for writing (CSV mode)
```


Examples
========

Display firmware information for the X2-4:

```
$ firith.rb -m x2-4
X2-4:
Sun Server X2-4 (formerly Fire X4470 M2 Server) ILOM 3.1.2.24.c r81341 BIOS vers. 16.04.02.00 1.4.1
https://support.oracle.com/epmos/faces/ui/patch/PatchDetail.jspx?patchId=17023411
https://getupdates.oracle.com/all_unsigned/p17023411_141_Generic.zip
ILOM 3.1.2.24.b r79266 BIOS vers. 16.04.02.00 Server 1.4 (21-May-2013)
https://support.oracle.com/epmos/faces/ui/patch/PatchDetail.jspx?patchId=16404931
https://getupdates.oracle.com/all_unsigned/p16404931_140_Generic.zip
ILOM 3.1.2.24.a r75561 BIOS vers. 16.04.01.05 Server 1.3.1 (02-Oct-2012)
https://support.oracle.com/epmos/faces/ui/patch/PatchDetail.jspx?patchId=14579071
https://getupdates.oracle.com/all_unsigned/p14579071_131_Generic.zip
ILOM 3.1.2.24 r73820 BIOS vers. 16.04.01.02 Server 1.3 (07-Jul-2012)
https://support.oracle.com/epmos/faces/ui/patch/PatchDetail.jspx?patchId=14099616
https://getupdates.oracle.com/all_unsigned/p14099616_130_Generic.zip
ILOM 3.0.16.12.a r70287 BIOS vers. 16.03.01.03 Server 1.2 (08-Feb-2012)
https://support.oracle.com/epmos/faces/ui/patch/PatchDetail.jspx?patchId=13648432
https://getupdates.oracle.com/all_unsigned/p13648432_120_Generic.zip
ILOM 3.0.16.12 r65661 BIOS vers. 16.02.01.01 Server 1.1 (13-Sep-2011)
https://support.oracle.com/epmos/faces/ui/patch/PatchDetail.jspx?patchId=12886608
https://getupdates.oracle.com/all_unsigned/p12886608_110_Generic.zip
ILOM 3.0.14.20.a r64405 BIOS vers. 16.01.01.19 (only required on Windows with 1Tb configuration) Server 1.0.1
https://support.oracle.com/epmos/faces/ui/patch/PatchDetail.jspx?patchId=12677099
https://getupdates.oracle.com/all_unsigned/p12677099_Server_Generic.zip
ILOM 3.0.14.20 r63740 BIOS vers. 16.01.01.18 Server 1.0 (22-Jun-2011)
https://support.oracle.com/epmos/faces/ui/patch/PatchDetail.jspx?patchId=12673454
https://getupdates.oracle.com/all_unsigned/p12673454_100_Generic.zip
```

Output latest firmware TFTP information as CSV (Warning this will download the firmware also):

```
$ firith.rb -t all -w /export/firmware -l -c -o firmware.txt
```

Display firmware for all Emulex HBAs:

```
$ firith.rp -e all
LP21000:
LP21000 Version 3.10a3
http://www-dl.emulex.com/support/hardware/lp21000/ob/310a3/ao310a3.zip
LP21002:
LP21002 Version 3.10a3
http://www-dl.emulex.com/support/hardware/lp21000/ob/310a3/ao310a3.zip
SG-XPCIE1FC-EM8-Z:
LPE12000 (SG-XPCIE1FC-EM8-Z) Version 3.10a6
http://www-dl.emulex.com/support/elx/rt960/b12/firmware/LPe12000/uo310a6.zip
LPE12000:
LPE12000 (SG-XPCIE1FC-EM8-Z) Version 3.10a6
http://www-dl.emulex.com/support/elx/rt960/b12/firmware/LPe12000/uo310a6.zip
SG-XPCIE2FC-EM8-Z:
LPE12002 (SG-XPCIE2FC-EM8-Z) Version 3.10a6
http://www-dl.emulex.com/support/elx/rt960/b12/firmware/LPe12000/uo310a6.zip
LPE12002:
LPE12002 (SG-XPCIE2FC-EM8-Z) Version 3.10a6
http://www-dl.emulex.com/support/elx/rt960/b12/firmware/LPe12000/uo310a6.zip
SG-XPCI1FC-EM4-Z:
LP11000 (SG-XPCI1FC-EM4-Z) Version 3.10a6
http://www-dl.emulex.com/support/elx/rt960/b12/firmware/LP11000/bo310a6.zip
LP11000:
LP11000 (SG-XPCI1FC-EM4-Z) Version 3.10a6
http://www-dl.emulex.com/support/elx/rt960/b12/firmware/LP11000/bo310a6.zip
SG-XPCI2FC-EM4-Z:
LP11002 (SG-XPCI2FC-EM4-Z) Version 3.10a6
http://www-dl.emulex.com/support/elx/rt960/b12/firmware/LP11000/bo310a6.zip
LP11002:
LP11002 (SG-XPCI2FC-EM4-Z) Version 3.10a6
http://www-dl.emulex.com/support/elx/rt960/b12/firmware/LP11000/bo310a6.zip
SG-XPCIe1FC-EM4:
LPE11000 (SG-XPCIe1FC-EM4) Version 3.10a6
http://www-dl.emulex.com/support/elx/rt960/b12/firmware/LPe11000/zo310a6.zip
LPE11000:
LPE11000 (SG-XPCIe1FC-EM4) Version 3.10a6
http://www-dl.emulex.com/support/elx/rt960/b12/firmware/LPe11000/zo310a6.zip
SG-XPCIe2FC-EM4:
LPE11002 (SG-XPCIe2FC-EM4) Version 3.10a6
http://www-dl.emulex.com/support/elx/rt960/b12/firmware/LPe11000/zo310a6.zip
LPE11002:
LPE11002 (SG-XPCIe2FC-EM4) Version 3.10a6
http://www-dl.emulex.com/support/elx/rt960/b12/firmware/LPe11000/zo310a6.zip
```

Display firmware for all Qlogic HBAs:

```
$ firith.rb -q all
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
```

Download latest firmware for X6270M2:

```
$ firith.rb -M X6270M2 -w /export/firmware
Downloading: https://getupdates.oracle.com/all_unsigned/p14568638_141_Generic.zip
Destination: /export/firmware/x6270m2/p14568638_141_Generic.zip
```

Display TFTP boot image information for X6270M2:

```
$ firith.rb -t X6270M2 -w /export/firmware
X6270M2:
TFTP file: ILOM-3_0_16_11_h_r75207-Sun_Blade_X6270M2.pkg
Location:  /export/firmware/x6270m2/ILOM_and_BIOS/ILOM-3_0_16_11_h_r75207-Sun_Blade_X6270M2.pkg
```

Display all M3000 XSCF firmware history:

```
$ firith.rb -X M3000
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
```
