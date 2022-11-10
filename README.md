# Get-FslVerions
PowerShell script to check the FSLogix version of Virtual Machines in an Azure Resource Group.

```PowerShell
$ResourceGroupName = ""

# Creates a collection object
[System.Collections.Generic.List[System.Object]]$FSLogixVirtualMachines = @()

Write-Host ("Checking VM's in Resource Group: {0}" -f $ResourceGroupName)

# Get all VMs in the Resource Group with PowerState information
$VMsToCheck = Get-AzVM -ResourceGroupName $ResourceGroupName -Status
$i = 0

# Loop through each VM in the collection
Foreach ($VirtualMachine in $VMsToCheck) {

    # Show progress of the operation
    Write-Progress -Activity "Verifying FSLogix Installed Version" -Status ("Working on {0} of {1} VMs" -f ($i+1),$VMsToCheck.Count) -CurrentOperation ("Current VM: {0}" -f $VirtualMachine.Name) -PercentComplete (($i / $VMsToCheck.Count) * 100)
    
    # Create an object to store the results (new object for each VM)
    $vmObject = $null
    $vmObject = [PSCustomObject]@{
        VMName = $VirtualMachine.Name
        ResourceGroup = $VirtualMachine.ResourceGroupName
        State = $VirtualMachine.PowerState
        FslVersion = "Unknown"
    }

    # Check the VM PowerState before calling Invoke-AzVMRunCommand
    If ($vmObject.State -eq "VM running") {
        # Use Invoke-AzVMRunCommand to call a PowerShell command and store the results
        $results = $VirtualMachine | Invoke-AzVMRunCommand -CommandId RunPowerShellScript -ScriptString "(Get-ItemProperty -Path HKLM:\SOFTWARE\FSLogix\Apps).InstallVersion"
        
        # Add the results to the object and add the object to the collection
        $vmObject.FslVersion = $results.Value[0].Message
        $FSLogixVirtualMachines.Add($vmObject)
    }
    Else {
        # Write warning if VM is not running, add to collection
        Write-Warning ("VM: {0} is not running, no data collected." -f $vmObject.VMName)
        $FSLogixVirtualMachines.Add($vmObject)
    }
    $i++
}

# Export data to CSV and output the path
$FSLogixVirtualMachines | Export-Csv -Path ("{0}\FSLogixVirtualMachines.csv" -f $env:TEMP) -NoTypeInformation -Force
Write-Host ("Results exported to CSV: {0}\FSLogixVirtualMachines.csv" -f $env:TEMP)

# Display collection to the console
$FSLogixVirtualMachines
```
