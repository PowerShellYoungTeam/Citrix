
Function Get-CitrixWorkspaceVdaversions{
    <#
    .SYNOPSIS
    Function to check version of Citrix Workspace and VDA installed on machines listed in CSV
    by Steven Wight

    .DESCRIPTION
    Get-CitrixWorkspaceVdaversions -Domain <domain> -infile <Path and name of input csv file> -outfile <Path and name of output csv file>

    .EXAMPLE
    Get-CitrixWorkspaceVdaversions -Domain Blah.com -infile C:\scripts\Citrixmachines.csv
    #>
    [CmdletBinding()]
    Param(  
    [Parameter()] [String] [ValidateNotNullOrEmpty()] $Domain = "POSHYT", 
    [Parameter()] [String] [ValidateNotNullOrEmpty()] $infile = ("c:\temp\posh_inputs\CitrixHostnames.csv"),
    [Parameter()] [String] [ValidateNotNullOrEmpty()] $outfile =("C:\temp\posh_outputs\CitrixWorkspaceVDA_version_$(get-date -f yyyy-MM-dd-HH-mm).csv"))

    #import hostnames and start loop
    Import-CSV $infile -Header PCname | Foreach-Object{

        #Clear Variables from last loop    
        $computer = $username = $workspacever = $VDAversion =$user = $uptime = $null

        # Get Computer info from AD
        $computer = (Get-ADComputer $_.PCname -properties DNSHostname -server $Domain | Select-Object DNSHOSTNAME).DNSHostname

        # Check machine is online    
        $PathTest = Test-Connection -Computername $computer -BufferSize 16 -Count 1 -Quiet

        #if Machine is online
        if($PathTest -eq $True) {
            
            #Get logged on user
            $username = (Get-WmiObject –ComputerName $computer –Class Win32_ComputerSystem | Select-Object UserName)

            #Get Citrix Workspace Version
            $workspacever = (Get-ChildItem "\\$($computer)\c$\Program Files (x86)\Citrix\ICA Client\SelfServicePlugin\selfservice.exe" -erroraction SilentlyContinue).VersionInfo.ProductVersion

            #If it can't find selfservice.exe
            if($null -eq $workspacever){

                #Set $workspacever with not installed message
                $workspacever = "Workspace not installed"
            } #End of if $workspacever is Null

            #Get Citrix Virtual Delivery Agent Version
            $VDAversion = (Get-ChildItem "\\$($computer)\C$\Program Files\Citrix\Virtual Desktop agent\brokeragent.exe" -ErrorAction SilentlyContinue).VersionInfo.ProductVersion
            
            #If it can't find brokeragent.exe
            if($null -eq $VDAversion){

                #Set $VDAversion with not installed message
                $VDAversion = "VDA not installed"
            } #End of if $VDAversion is Null

            #drop domain of logged on username and Query AD for user
            Try{
            $username = ($username -split "\\" )[1]
            $user = get-aduser $Username -properties * -server $Domain
            }catch{ # and issue store error message in $user
            $user = $_.Exception.Message
            }#End of Try..Catch for user

            # Get Machine uptime
            Try{
            $uptime = (Get-Date) - [Management.ManagementDateTimeConverter]::ToDateTime((Get-WmiObject Win32_OperatingSystem -ComputerName $Computer).LastBootUpTime) 
            $uptime = "$($Uptime.Days) D $($Uptime.Hours) H $($Uptime.Minutes) M"
            }catch{# any issues store error in $uptime
            $uptime = $_.Exception.Message
            }#End of Try..Catch for uptime

            #Put data into pscustomeobject and pump into CSV
            [pscustomobject][ordered] @{
            ComputerName =  $computer
            "Citrix WorkSpace Version" = $workspacever
            "VDA Version" = $VDAversion
            "uptime (days)" = $uptime
            "loggedon username" = $user.name
            Displayname = $user.displayname
            Email = $user.Emailaddress 
            } | Export-csv -Path $outfile -NoTypeInformation  -Append -Force
        }else{#If machine wasn't online

            # Stick Hostname into variable for use in pscustomobject
            $Hostname = $_.PCname 
            
            #Put data into pscustomeobject and pump into CSV
            [pscustomobject][ordered] @{
            ComputerName =  $Hostname
            "Citrix WorkSpace Version" = "Offline"
            "VDA Version" = "Offline"
            "uptime (days)" = "Offline"
            "loggedon username" = $user 
            Displayname = "N/A" 
            Email = "N/A" 
            } | Export-csv -Path $outfile -NoTypeInformation  -Append -Force
        }# End of If 

    }#end of foreach

}# end of Function