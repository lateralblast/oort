goofball
========

Get Oracle OBP Firmware 

This script parses the Oracle firmware page to get firmware information.
It returns the versions of firmware (top most is the current) and their
URLs.

Oracle Firmware URL:

http://www.oracle.com/technetwork/systems/patches/firmware/release-history-jsp-138416.html

Usage
=====

	./goofball.rb -[h|V] -[q|m|d|e] [MODEL|all] -i [FILE] -o [FILE] -w [WORK_DIR]

	-V:          Display version information
	-h:          Display usage information
	-m all:      Display firmware information for all machines
	-d all:      Display firmware information for all disks
	-e all:      Display firmware information for all Emulex HBAs
	-q all:      Display firmware information for all Qlogic HBAs
	-m MODEL:    Display firmware information for a specific model (eg. X2-4)
	-d MODEL:    Display firmware information for a specific model of disk (eg. MAW3300FC)
	-e MODEL:    Display firmware information for a specific model of Emulex HBA (eg. SG-XPCIEFCGBE-E8-Z)
	-q MODEL:    Display firmware information for a specific model of Qlogic HBA (eg. SG-XPCIEFCGBE-Q8-Z)
	-i FILE:     Open a locally saved HTML file for processing rather then fetching it
	-r PATCH:    Get README for a patch from MOS (Requires Username and Password)
	-w WORK_DIR: Set work directory (Default is ~/.goofball)
	-c:          Output in CSV format
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

Todo
====

I plan to add the ability to download the firmware as well.
This will obviously require a My Oracle Support account.
