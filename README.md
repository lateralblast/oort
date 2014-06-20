![alt tag](https://raw.githubusercontent.com/lateralblast/firith/master/firith.jpg)

> Firith was the Sindarin name for the season in the Calendar of Imladris which corresponds with a period
<br>
> between autumn and winter, known as fading.
<br>
> -- <cite>The Lord of The Rings by J. R. R. Tolkien</cite>

> “And you, Ring-bearer,’ she said, turning to Frodo. ‘I come to you last who are not last in my thoughts.
<br>
> For you I have prepared this.’ She held up a small crystal phial: it glittered as she moved it, and rays
<br>
> of white light sprang from her hand. ‘In this phial,’ she said, ‘is caught the light of Eärendil’s star,
<br>
> set amid the waters of my fountain. It will shine still brighter when night is about you.
<br>
> May it be a light to you in dark places, when night is about you.
<br>
> May it be a light to you in dark places, when all other lights go out.
<br>
> -- <cite>Galadriel</cite>

FIRITH
======

Firmware Information Right In The Hand

Introduction
------------

This script parses the Oracle (and in the future other) firmware pages to get
firmware information. It returns the versions of firmware (top most is the current)
and their URLs. It can also download the firmware to a local repository if needed.

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

[Oracle firmware and patch resources](https://github.com/lateralblast/firith/wiki/Resources)

Usage
-----

[Information on usage](https://github.com/lateralblast/firith/wiki/Usage)


Examples
--------

[Examples of usage](https://github.com/lateralblast/firith/wiki/Usage)

