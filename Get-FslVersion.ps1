<#
.SYNOPSIS
    Check computers for minimum version of FSLogix
.DESCRIPTION
    This script takes a list of computer names and will attempt to collect the FSLogix version information from those computers. The script will return the an object of collected version information for each computer. Use cmdlets like Export-Csv or Out-File to save the results to a file or store the value into a variable.
.NOTES
    The script will run with no input parameters and will collect information for the local computer.
.EXAMPLE
    Get-FslVersion.ps1
    Will collect FSLogix version information on the local computer.
.EXAMPLE
    Get-FslVersion.ps1 -ComputerNames "Computer1","Computer2" | Export-Csv -Path $ENV:TEMP\fsl_version_info.csv -NoTypeInformation
    Will collect FSLogix version information from Computer1 and Computer2 and save the data to a CSV file.
.EXAMPLE
    $Results = "Computer1","Computer2" | Get-FslVersion.ps1 -Verbose
    Takes the computer names from the pipeline, collects the FSLogix version information and stores the information into the $Results variable with Verbose output
.LINK
    https://learn.microsoft.com/en-us/powershell/scripting/learn/remoting/running-remote-commands?view=powershell-7.3#windows-powershell-remoting
#>
[CmdletBinding()]
Param (
    # List of ComputerName(s) to check (e.g., "Computer1", "Computer2"). Can be piped to the script or listed as part of the -ComputerNames parameter. Defaults to the local computer.
    [Parameter(Mandatory=$true,ValueFromPipeline=$true,HelpMessage="Type the list of computers to collect events from ('Computer1','Computer2').")]
    [System.String[]]$ComputerNames = $env:COMPUTERNAME,

    # Specifies the minimum FSLogix Version to check. Defaults to 2.9.7653.47581
    [Parameter(Mandatory=$false,HelpMessage="Enter the full FSLogix version number (x.x.xxxx.xxxxx)")]
    [System.String]$MinimumVersion = "2.9.7653.47581"
)
BEGIN {
    Write-Verbose ("FSLogix Version Validation | Minimum version: {0}" -f $MinimumVersion)
    
    # Create empty results object
    [System.Collections.Generic.List[System.Object]]$FslVersionInfo = @()
    
    # Counter used in progress bar and other output
    $countComputerNames = 0

    # Scriptblock sent to computers to run via the Invoke-Command cmdlet
    $ScriptBlock = {
        Param ($MinimumVersion)
        
        # Paths to check
        $uninstallPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
        $fslRegistryPath = "HKLM:\SOFTWARE\FSLogix\Apps"
        $fslInstallPath = "$env:ProgramFiles\FSLogix\Apps"
    
        # Empty results object
        $objResults = [PSCustomObject][Ordered]@{
            ComputerName          = $env:COMPUTERNAME
            FslValidationResult   = $false
            FslMinimumVersion     = $MinimumVersion
            FslMsiInstallCheck    = "Unknown"
            FslMsiInstallVersion  = "Unknown"
            FslRegistryVersion    = "Unknown"
            FslCommandLineVersion = "Unknown"
            FslAppsSvcVersion     = "Unknown"
            FslCcdSvcVersion      = "Unknown"
            FslAppDriverVersion   = "Unknown"
            FslAppVtDriverVersion = "Unknown"
            FslCcdDriverVersion   = "Unknown"
        }
    
        Write-Verbose ("====>  FSLogix Validation Tool - Checking version information on {0}" -f $env:COMPUTERNAME)

        # Empty array of all versions collected from various sources
        $allVersions = @()
    
        # Checks the uninstall registry path to validate installation
        $appCheck = Get-ItemProperty -Path $uninstallPath\* | Where-Object { $_.DisplayName -eq "Microsoft FSLogix Apps" }
    
        # Processes if installation is true
        If ($appCheck) {
            $objResults.FslMsiInstallCheck = "Installed"
            Write-Verbose ("{0} | FSL MSI Installation Check:  PASS" -f $env:COMPUTERNAME)
    
            # Processes if both installs for App Service and CCD Service are found
            If ($appCheck.Count -gt 1) {

                # Checks for the core app install which has the largest size versus CCD
                $objResults.FslMsiInstallVersion = ($appCheck | Where-Object {$_.EstimatedSize -eq ($appCheck | Measure-Object -Maximum EstimatedSize).Maximum}).DisplayVersion
                $objResults.FslRegistryVersion = (Get-ItemProperty -Path $fslRegistryPath).InstallVersion
                
                # Runs FRX Utility to check version data
                $frxOutput = (& $fslInstallPath\frx.exe version).Split(":").Trim()
                $objResults.FslCommandLineVersion = $frxOutput[1]
                $objResults.FslAppsSvcVersion = $frxOutput[3]
                $objResults.FslAppDriverVersion = $frxOutput[5]
                $objResults.FslAppVtDriverVersion = $frxOutput[7]
            
                $objResults.FslCcdSvcVersion = (Get-ItemProperty -Path $fslInstallPath\frxccds.exe).VersionInfo.FileVersion
                $objResults.FslCcdDriverVersion = (Get-ItemProperty -Path $fslInstallPath\frxccd.sys).VersionInfo.FileVersion
    
                # Adds version data to array
                $allVersions += $objResults.FslMsiInstallVersion
                $allVersions += $objResults.FslRegistryVersion
                $allVersions += $objResults.FslCommandLineVersion
                $allVersions += $objResults.FslAppsSvcVersion
                $allVersions += $objResults.FslAppDriverVersion
                $allVersions += $objResults.FslAppVtDriverVersion
                $allVersions += $objResults.FslCcdSvcVersion
                $allVersions += $objResults.FslCcdDriverVersion
    
                # Checks the array for any version less than the minimum version
                If (($allVersions | Where-Object {$_ -lt $MinimumVersion}) -OR ($allVersions | Where-Object {$_ -eq "Unknown"})) {
                    Write-Warning ("{0} | One or more FSLogix Components does not meet the minimum version" -f $env:COMPUTERNAME)
                    Return $objResults
                }
                Else {
                    $objResults.FslValidationResult = $true
                    Return $objResults
                }
            }
            Else {
                Write-Warning ("{0} | Unable to check FSL Install Version" -f $env:COMPUTERNAME)
                Return $objResults
            }
        }
        Else {
            Write-Warning ("{0} | FSL is not installed!" -f $env:COMPUTERNAME)
            $objResults.FslMsiInstallCheck = "Not Installed"
            Return $objResults
        }
    }
}
PROCESS {

    # Loops through each ComputerName via pipeline or parameter
    Foreach ($ComputerName in $ComputerNames) {
        try {
            # Show progress of the operation based on if the computernames are from the pipeline or parameter
            If ($ComputerNames.Count -gt 1) { Write-Progress -Activity "Verifying FSLogix Installed Version" -Status ("Working on {0} of {1} VMs" -f ($countComputerNames + 1),$ComputerNames.Count) -CurrentOperation ("{0}" -f $ComputerName) -PercentComplete (($countComputerNames / $ComputerNames.Count) * 100) }
            Else { Write-Progress -Activity "Verifying FSLogix Installed Version" -Status ("Working on VM(s)") -CurrentOperation ("{0}" -f $ComputerName) }

            # Check the access to the VM
            If (Test-Connection -ComputerName $ComputerName -Quiet -Count 1) {

                # Use Invoke-Command to send the scriptblock of code to the VM
                $results = Invoke-Command -ComputerName $ComputerName -ScriptBlock $ScriptBlock -ArgumentList $MinimumVersion -HideComputerName -ErrorAction Stop
                
                # Add the results object to the collection
                $FslVersionInfo.Add($results)
            }
            Else {
                # Write warning if VM is not reachable
                Write-Warning ("{0} | Unable to verify the system is reachable" -f $ComputerName)
                
                $objResults = [PSCustomObject][Ordered]@{
                    ComputerName          = $ComputerName
                    FslValidationResult   = $false
                    FslMinimumVersion     = $MinimumVersion
                    FslMsiInstallCheck    = "Unknown"
                    FslMsiInstallVersion  = "Unknown"
                    FslRegistryVersion    = "Unknown"
                    FslCommandLineVersion = "Unknown"
                    FslAppsSvcVersion     = "Unknown"
                    FslCcdSvcVersion      = "Unknown"
                    FslAppDriverVersion   = "Unknown"
                    FslAppVtDriverVersion = "Unknown"
                    FslCcdDriverVersion   = "Unknown"
                }

                $FslVersionInfo.Add($objResults)
            }
            $countComputerNames++
        }
        catch {

            # Catch any errors and display warning and continue to process
            Write-Warning ("====>  FAILED: Unable to check FSLogix version info on: {0} ({1})" -f $ComputerName,$_.Exception.Message)
            Continue
        }
    }
}
END {

    # Completes progress bar
    Write-Progress -Activity "Verifying FSLogix Installed Version" -Completed
    
    # Get specific results for verbose output
    $validationPassed = ($FslVersionInfo | Where-Object {$_.FslValidationResult -eq $true} | Measure-Object).Count
    $notInstalled = ($FslVersionInfo | Where-Object {$_.FslMsiInstallCheck -eq "Not Installed"} | Measure-Object).Count
    Write-Verbose ("Checked {0} Virtual Machines: {1} met the minimum version ({2}) or greater | No Install found in {3}" -f $countComputerNames,$validationPassed,$MinimumVersion,$notInstalled)

    Return $FslVersionInfo
}
