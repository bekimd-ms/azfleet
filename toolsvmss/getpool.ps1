Param(
    [string] $vmPool
)

$configfile = $env:AZFLEET_CONFIG
$config = get-content $configfile | ConvertFrom-Json
$rg = $config.resourcegroup

Write-Host "Deployment: " $rg
Write-Host ""
if( $vmPool )
{
    $vmss_list = Get-AzVMSS -ResourceGroupName  $rg -VMScaleSetName $vmPool
}
else 
{
    $vmss_list = Get-AzVMSS -ResourceGroupName  $rg
}

Write-Output "Retrieving VM data..."

$vmlist = @()
foreach( $vmss in $vmss_list)
{
    $vm_list = Get-AzVMSSVM -ResourceGroupName $rg -VMScaleSetName $vmss.Name -InstanceView
    foreach( $vm in $vm_list )
    {
        if( $vm.OSProfile.LinuxConfiguration)
        {
            $os = "Linux"
        }
        else
        {
            $os = "Windows"
        }
        $vm = [PSCustomObject] @{
            Pool = $vmss.Name
            Name = $vm.Name
            PowerState = ($vm.InstanceView.Statuses | where Code -like "PowerState*").DisplayStatus
            ProvisioningState = $vm.ProvisioningState
            OS = $os
            Size = $vmss.Sku.Name
            DiskSize = $vm.StorageProfile.DataDisks[0].DiskSizeGB
            DiskCache = $vm.StorageProfile.DataDisks[0].Caching
        }
        $vmlist += @($vm)
    }
}

$vmlist | ft -GroupBy Pool
