# Citrix
 Scripts (or Functions/cmdlets and modules) for use with Citrix Snapin and other related Scripts

## Get-CitrixWorkspaceVDAversions
### SYNOPSIS:
    Function to check version of Citrix Workspace and VDA installed on machines listed in CSV
    by Steven Wight
### DESCRIPTION:
    Get-CitrixWorkspaceVdaversions -Domain <domain> -infile <Path and name of input csv file> -outfile <Path and name of output csv file>

### EXAMPLE:
    Get-CitrixWorkspaceVdaversions -Domain Blah.com -infile C:\scripts\Citrixmachines.csv

# Citrix_VDA_Support_Tools

These are some tools I made for our support teams to troubleshoot issues with VDA on our machines.

## Prerequisites

You will need Remote Server Administration Tools (RSAT) installed on your PC . I'm assuming that this is being used in an enviroment with Active Directory

If not, you can download it from this site

https://www.microsoft.com/en-gb/download/details.aspx?id=45520 (will get you to choose between 32 bit or 64 bit, either will do)

## How to install

You will need to move the Module folder and file into a location PowerShell can read it from. To find those locations, open PowerShell / PowerShell ISE / Windows Terminal (whatever you prefer!) and enter this command:

### $env:PSModulePath -split’;’

Then drop the .psm1 into a folder called **Citrix_VDA_Support_Tools** into one of those locations, so the path is like..

C:\Windows\System32\WindowsPowerShell\Modules\Citrix_VDA_Support_Tools\Citrix_VDA_Support_Tools.psm1

To load the module enter this command into the PowerShell Console:

### Import-Module Citrix_VDA_Support_Tools

(If you get a warning about “unapproved verbs” ignore it, PowerShell doesn’t like how I name my functions)

## How to add to profile

If you don’t want to load the module each time you restart, you can add it to your PowerShell Profile (can add loads of handy stuff in here)

Just enter this command in the PowerShell console to open it 

Notepad $Profile

Notepad will open, just add **Import-Module Citrix_VDA_Support_Tools** and save the file, now the module will load each time you open PowerShell and be ready for use.

## Get-Command

If you forget what the commands/function names are, the easy way to get them is enter this into the PowerShell Console:

### Get-Command -Module Citrix_VDA_Support_Tools

## Check-CitrixWorkspaceandVDAVersion

Function to Check Citrix Workspace and VDA version, use like below 

### Check-CitrixWorkspaceandVDAVersion Computer01

## Correct-SystemTime

Function to correct wrong time and date on remote machines as if it’s too far out, VDA won’t register, use like below (FYI – this assumes the time and date on your machine is correct)

### Correct-SystemTime Computer01

## Fix-CitrixVDA

Function to change DDC's (We need to set our physical machines to use Multi DDCs and add in the DDCs)  and restart Citrix Desktops Services, Use like below (FYI doesn’t change reg setting on VM as they don’t need to be, just restarts services, also there us built in 10 second pause to start services)

### Fix-CitrixVDA Computer01

## Get-CitrixEventLogs

Function to search for errors in Citrix Event logs, use like below (FYI – Ignore the red writing, that is good that it can’t find the error! If you see - 6 Error Citrix ICA could not configure Thinwire and switch to the remote ICA display. Then VDA needs reinstalled)

### Get-CitrixEventLogs Computer01

If you get an error saying no events found, that is good, if you get an error saying no citrix event log found, VDA isnt installed or fully installed
