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
