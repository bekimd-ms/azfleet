Param(
    [string] $vmPool,
    [int] $vmCount
)

$configfile = $env:AZFLEET_CONFIG
$config = get-content $configfile | ConvertFrom-Json
$rg = $config.resourcegroup
$acct = $config.storageaccount
$vmssname = $vmPool + "ss"

# Get current scale set
$vmss = Get-AzVmss -ResourceGroupName $rg -VMScaleSetName $vmssname
Write-Host "Reconfiguring scale set..."
# Set and update the capacity of your scale set
$vmss.sku.capacity = $vmCount
Update-AzVmss -ResourceGroupName $rg -Name $vmssname -VirtualMachineScaleSet $vmss

