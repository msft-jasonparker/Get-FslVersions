# FSLogix Version Validation

The script in this repository can be used to check or validate the version of FSLogix running on one (1) or more Virtual Machines running in your environment.  This script assumes the user running it has administrative rights to the VM(s) and that [PowerShell remoting](https://learn.microsoft.com/en-us/powershell/scripting/learn/remoting/running-remote-commands?view=powershell-5.1#windows-powershell-remoting) is working and enabled in the environment.

This script will produce an object that can be stored into a variable, saved to a file or exported into a comma-separated (CSV) file.

## Examples

Below are a few examples of how this script could be run.

### Local Computer

Will collect FSLogix version information on the local computer.

```PowerShell
Get-FslVersion.ps1
```

### Multiple VM(s) using the parameter

Will collect FSLogix version information from Computer1 and Computer2 and save the data to a CSV file.

```PowerShell
Get-FslVersion.ps1 -ComputerNames "Computer1","Computer2" | Export-Csv -Path $ENV:TEMP\fsl_version_info.csv -NoTypeInformation
```

### Multiple VM(s) from the pipeline

Takes the computer names from the pipeline, collects the FSLogix version information and stores the information into the $Results variable with Verbose output

```PowerShell
$Results = "Computer1","Computer2" | Get-FslVersion.ps1 -Verbose
```
