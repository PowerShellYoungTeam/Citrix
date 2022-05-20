Function Fix-CIBVDA {
    <#
    .SYNOPSIS
    Function to change DDC's (if required) and restart Citrix Desktops Services
    by Steven Wight
    .DESCRIPTION
    Fix-CIBVDA -ComputerName <Hostname> -DDC <DDCServerNames> (Default = DDC001V &002V) -Domain <domain> (default = POSHYT)
    .EXAMPLE
    Fix-CIBVDA Computer01
    .Notes
    This if for an enviroment where VM and Physical machines have different DDCs, also Hostnames end in letter designating what type they are 
    #>
    [CmdletBinding()]
    Param( 
        [Parameter(Mandatory=$true)] [String] [ValidateNotNullOrEmpty()] $ComputerName,
        [Parameter()] [string] [ValidateNotNullOrEmpty()] $DDC = "DDC001V.POSHYT.corp DDC002V.POSHYT.corp", 
        [Parameter()] [string] [ValidateNotNullOrEmpty()] $Domain = "POSHYT"
    )

    #Ensure output fields aren't cut short
    $FormatEnumerationLimit = -1
    
    #clear variables encase they have been used in session
    $VDAReg = $adcheck = $isVM = $null
    
    #If Computer is a Virtual, set flag
    if($ComputerName -like "*V"){

        Write-host -ForegroundColor Cyan "$($ComputerName) is a Virtual"
        $isVM = $true
    
    }else{

        Write-host -ForegroundColor Cyan "$($ComputerName) is a Physical "
        $isVM = $false

    } 
    
    try{# check if in AD, if not output to console then quit function

        $adcheck = (Get-ADComputer $ComputerName -server $Domain)
        Write-host -ForegroundColor Green "$($ComputerName) Computer object found in AD"

    }catch{

        #if no machine found, output to console and quit function
        Write-host -ForegroundColor RED "$($ComputerName) Computer object not found in AD"
        Break

    } # End of Try...Catch
    
    #Check machine is online
    $PathTest = (Test-Connection -Computername $adcheck.DNSHostName -BufferSize 16 -Count 1 -Quiet)

    If($true -eq $PathTest ){ # if machine is online
        
        #Output to console machine is online
        Write-host -ForegroundColor Green "$($ComputerName) Computer is online"

        try{# Check if VDA is installed

            $VDAinstalled = Test-Path -Path ("\\$($adcheck.DNSHostName)\C$\Program Files\Citrix\Virtual Desktop agent\brokeragent.exe")
            
        }catch{

            #if there is an issue, output to console and quit function
            Write-host -ForegroundColor RED "$($ComputerName) Issue checking VDA installation"
            Break
        }#end of try ..catch

        if($True -eq $VDAinstalled){

            #Get VDA Version for info purposes
            $VDAversion = (Get-ChildItem "\\$($ComputerName)\C$\Program Files\Citrix\Virtual Desktop agent\brokeragent.exe" -ErrorAction SilentlyContinue).VersionInfo.ProductVersion
            Write-host -ForegroundColor Cyan "$($ComputerName) Citrx VDA version: $($VDAversion)"
            
            If($false -eq $isVM){
            
                try{# set reg setting to support multiple 

                    #local of reg keys put in variable to be used by invoke command
                    $searchScopes = "registry::HKEY_LOCAL_MACHINE\SOFTWARE\Citrix\VirtualDesktopAgent"

                    #Set reg keys via Invoke command and get the reg setting returned and stored in $VDAreg
                    $VDAReg =  Invoke-Command -ComputerName $adcheck.DNShostname -ScriptBlock  {
                        Set-ItemProperty -Path $using:searchScopes -type Dword -Name SupportMultipleForest -Value 00000001
                        Set-ItemProperty -Path $using:searchScopes -type String -Name ListOfDDCs -Value $using:DDC 
                        $CitrixRegSettings = Get-ItemProperty $using:searchScopes 
                        Return $CitrixRegSettings
                    } # end of Scriptblock
                    
                    # output reg keys to console encase of errors/issues
                    Write-host -ForegroundColor Cyan "$($ComputerName) SupportMultipleForest - $($VDAreg.SupportMultipleForest)"
                    Write-host -ForegroundColor Cyan "$($ComputerName) ListOfDDCs - $($VDAreg.ListOfDDCs)"

                }catch{
                    
                    #if there is an issue, output to console and quit function
                    $VDAReg = $_.Exception.Message
                    Write-host -ForegroundColor RED "$($ComputerName) Issue when checking/setting registry settings $($VDAreg)"
                    Break

                }#end of try ..catch
                
            }# End of If isVM is false
    
            try{# restart Citrix Services, also check CtxSensVcSvc & MRVCSvc are set to manual

                $BrokerAgent = Invoke-Command -ComputerName $adcheck.DNShostname -ScriptBlock  {
                    Stop-Service -Name "BrokerAgent"
                    Stop-Service -Name "CtxSensVcSvc"
                    Stop-Service -Name "MRVCSvc"
                    Set-Service -Name "CtxSensVcSvc" -StartupType Manual
                    Set-Service -Name "MRVCSvc" -StartupType Manual
                    Start-Sleep 5
                    Start-Service -Name "BrokerAgent"
                    Start-Sleep 5
                    $BAsvc = Get-Service -name "BrokerAgent"
                    Return $BAsvc
                }
                
                If('Running' -ne $BrokerAgent.Status){ # If the service isn't running

                    #Output message to console
                    Write-host -ForegroundColor Red "$($ComputerName) Service haven't restarted"

                }else{ # if it's running, output to the console

                    #Output message to console
                    Write-host -ForegroundColor Green "$($ComputerName) Restarted services"

                }

            }catch{
                
                #if there is an issue, output to console and quit function
                Write-host -ForegroundColor RED "$($ComputerName) Issue when trying to restart services"
                Break

            }

            }else{
            
            #Output if VDA isn't found
            Write-host -ForegroundColor RED "$($ComputerName) Computer doesn't have Citrx VDA installed"

        }# end of IF VDAinstalled = true
    
    }else{#If machine wasn't online 

        #Output machine is online to the console
        Write-host -ForegroundColor Red "$($ComputerName) Computer is offline"

    } # end of IF else $Pathtest
    
}# End of function

function Check-CIBWorkspaceandVDAVersion {
    <#
    .SYNOPSIS
    Function to Check Citrix Workspace and VDA version
    by Steven Wight
    .DESCRIPTION
    Check-CIBWorkspaceandVDAVersion -ComputerName <Hostname> -Domain <Domain> default = 'POSHYT'
    .EXAMPLE
    Check-CIBWorkspaceandVDAVersion Computer01
    .NOTES
    Ensure Path to Workspace and VDA match below
    #>
    [CmdletBinding()]
    Param ( 
        [Parameter(Mandatory=$true)] [string] $ComputerName, 
        [Parameter()] $Domain = 'POSHYT'
    )

    try{ # Get Computer info from AD

        $Computer = (Get-ADComputer $ComputerName -properties DNSHostname -server $Domain -ErrorAction stop).DNSHostname
        $AdCheck = $true

    }Catch{ #actions if not online

        Write-Host -ForegroundColor Red "Machine $($ComputerName) not found in AD" 
        $ComputerName = $_.Exception.Message
        $AdCheck = $false

    } #end of try catch

    If($True -eq $AdCheck){ # if Machine is in AD, check for Workspace and VDA versions

        #Check machine is online
        $PathTest = Test-Connection -Computername $Computer -BufferSize 16 -Count 1 -Quiet

        If($false -eq $PathTest){ # If Machine isn't oline, set variables to say so

            $WorkSpaceVer = "Offline"
            $VDAversion = "Offline"

        }Else{# if online, continue with checks
    
            Try{ # get Workspace version

                $WorkSpaceVer = (Get-ChildItem "\\$($computer)\c$\Program Files (x86)\Citrix\ICA Client\SelfServicePlugin\selfservice.exe" -erroraction SilentlyContinue).VersionInfo.ProductVersion
        
            }Catch{

                $WorkSpaceVer = $_.Exception.Message

            } # End of Try...catch
    
            If($null -eq $WorkSpaceVer){

                $WorkSpaceVer = "Workspace not installed"

            }# End of IF $null = $WorkSpaceVer
    
            Try{ # get VDA version

                $VDAversion = (Get-ChildItem "\\$($computer)\C$\Program Files\Citrix\Virtual Desktop agent\brokeragent.exe" -ErrorAction SilentlyContinue).VersionInfo.ProductVersion

            }catch{

                $VDAversion = $_.Exception.Message

            } # End of Try...catch

            If($null -eq $VDAversion){

                $VDAversion = "VDA not installed"

            }# End of IF $null = $VDAversion

        }#end of if else online

    }# End of If true= $ADCheck

    #output info to console
    Write-Host -ForegroundColor Cyan "Hostname          : $($ComputerName)"
    Write-Host -ForegroundColor Cyan "Workspace version : $($WorkSpaceVer)"
    Write-host -ForegroundColor Cyan "VDA Version       : $($VDAversion)"
    
} # end of function

Function Get-CitrixEventLogs{
    <#
    .SYNOPSIS
    Function to search for errors in Citrix Event logs
    by Steven Wight
    .DESCRIPTION
    Get-CitrixEventLogs -ComputerName <Hostname> -Days <Days> -Domain <domain> (default = POSHYT)
    .EXAMPLE
    Get-CitrixEventLogs Computer01
    .Notes
    Will search for errors in the last month (Days will go back that many days so -Days 10 will go back 10 days from today)
    If you find this error, VDA is gubbed : -  6 Error Citrix ICA could not configure Thinwire and switch to the remote ICA display.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)] [String] [ValidateNotNullOrEmpty()] $ComputerName, 
        [Parameter()] [String] [ValidateNotNullOrEmpty()] $Days = 30, 
        [Parameter()] [String] [ValidateNotNullOrEmpty()] $Domain = "POSHYT" 
    )

    #Clear Variables encase function/variables has been used before in session (never know!)   
    $Computer = $AdCheck = $PathTest = $null

    #Get the start time (So we know how far back we need to search)
    $StartDays = (Get-Date)
    $StartDays = $StartDays.AddDays(-$days)
    
    try{# Get Computer info from AD, if no machine found, output to console and quit function

        $Computer = (Get-ADComputer $ComputerName -properties DNSHostname -server $Domain -ErrorAction stop)
        $AdCheck = $true

    }Catch{ #if no machine found, output to console and quit function

        Write-Host -ForegroundColor Red "Machine $($ComputerName) not found in AD"
        $AdCheck = $false
        Break

    }#end of Try...Catch

    # Check machine is online 
    $PathTest = Test-Connection -Computername $Computer.DNSHostname -BufferSize 16 -Count 1 -Quiet

    #if Machine is online
    if($True -eq $PathTest) {
    
        #Output machine is online to the console
        Write-host -ForegroundColor Green "$($ComputerName) Computer is online"  
        
        Try{#Fetch Event Logs

            Get-WinEvent -ComputerName $Computer.DNSHostname -ErrorAction Stop -FilterHashtable @{ LogName='Citrix-HostCore-ICA Service/Admin'; Level = 2 ; StartTime=$StartDays }

        }catch{

            #Output error to console
            Write-Error $_.Exception.Message

        }# end of try..catch event logs

    }Else{#if not online

        #Output to console machine is online
        Write-host -ForegroundColor Red "$($ComputerName) Computer is offline"

    }# End of IF..else online
    
} #End of Function

Function Correct-SystemTime{
    <#
    .SYNOPSIS
    Function to correct wrong time and date on remote machines
    by Steven Wight
    .DESCRIPTION
    Correct-SystemTime -ComputerName <Hostname> -Domain <domain> (default = POSHYT)
    .EXAMPLE
    Correct-SystemTime Computer01
    .Notes
    This assumes the correct time and date on the machine it's being run from 
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)] [String] [ValidateNotNullOrEmpty()] $ComputerName,  
        [Parameter()] [String] [ValidateNotNullOrEmpty()] $Domain = "POSHYT" 
    )

    #Clear Variables encase function has been used before in session (never know!)   
    $Computer = $AdCheck = $PathTest = $TimeAndDate = $RemoteTimeAndDate = $null
    
    try{ # Get Computer info from AD & if no machine found, output to console and quit function

        $Computer = (Get-ADComputer $ComputerName -properties DNSHostname,description,OperatingSystem -server $Domain -ErrorAction stop)
        $AdCheck = $true

    }Catch{ #if no machine found, output to console and quit function

        Write-Host -ForegroundColor Red "Machine $($ComputerName) not found in AD"
        $AdCheck = $false
        Break

    } #end of try...catch

    # Check machine is online  
    $PathTest = Test-Connection -Computername $Computer.DNSHostname -BufferSize 16 -Count 1 -Quiet


    #if Machine is online
    if($True -eq $PathTest) {
    
        #Output machine is online to the console
        Write-host -ForegroundColor Green "$($ComputerName) Computer is online"

        #Get remote machines Time and date
        $RemoteTimeAndDate = Invoke-Command -ComputerName $Computer.DNSHostname -ScriptBlock { 
            return Get-Date -Format "dddd MM/dd/yyyy HH:mm" 
        } # End of Scriptblock
        
        #get local machines date and time
        $TimeAndDate = Get-date -Format "dddd MM/dd/yyyy HH:mm"
        
        #if time is out
        if($RemoteTimeAndDate -ne $TimeAndDate){
            
            Write-Host ""
            Write-Host -ForegroundColor RED "$($ComputerName) time is out"
            Write-Host -ForegroundColor RED "Remote Time - $($RemoteTimeAndDate)"
            Write-Host -ForegroundColor RED "Local Time - $($TimeAndDate)"
            Write-Host ""

            $Continue = Read-Host -Prompt 'Do you wish to correct? -  Press Y to continue'

            if ("Y" -eq $Continue.ToUpper()) {
                
                Write-Host ""
                Write-Warning -Message "Correcting time on $($ComputerName)"
                Write-Host ""

                #get local machines date and time
                $TimeAndDate = Get-date 

                #Correct time on remote machine
                $RemoteTimeAndDate = Invoke-Command -ComputerName $Computer.DNSHostname -ScriptBlock {  
                    Set-Date -Date $using:TimeAndDate
                    return Get-Date -Format "dddd MM/dd/yyyy HH:mm" 
                } # End of Scriptblock

                #confirm time and date was set correctly
                if($RemoteTimeAndDate -eq $TimeAndDate){
            
                    #output if successful
                    Write-Host ""
                    Write-Host -ForegroundColor Green "$($ComputerName) time was successfully corrected"
                    Write-Host ""

                }else{

                    #output if unsuccessful and what the difference is
                    Write-Host ""
                    Write-Host -ForegroundColor RED "$($ComputerName) issue correcting time"
                    Write-Host -ForegroundColor RED "Remote Time - $($RemoteTimeAndDate)"
                    Write-Host -ForegroundColor RED "Local Time - $($TimeAndDate)"
                    Write-Host ""

                }
            }

        }else{
            
            #output if time is okay
            Write-Host ""
            Write-Host -ForegroundColor Green "$($ComputerName) time is correct"
            Write-Host ""  
        
        }                                                                                               

    }else{#If machine wasn't online 
        
        #Output machine is online to the console
        Write-host -ForegroundColor Red "$($ComputerName) Computer is offline"

    }# End of If

}# end of Function
