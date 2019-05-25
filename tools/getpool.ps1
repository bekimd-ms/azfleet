Param(
    [string] $vmPool
)

$configfile = "config.json"
$config = get-content $configfile | ConvertFrom-Json
$rg = $config.resourcegroup

if( $vmPool )
{
    $vms = get-azurermvm -ResourceGroupName $rg -Status | where {$_.Tags.pool -eq $vmPool} 
}
else {
    $vms = get-azurermvm -ResourceGroupName $rg -Status | where {$_.Tags.pool -ne $Null} 
}

$controllerIP = Get-AzureRmPublicIpAddress -ResourceGroupName $rg -Name "controller-ip"
Write-Output ""
Write-Output "Controller IP " $controllerIP.IpAddress
Write-Output ""
Write-Output "Retrieving VM data..."

$vmlist = @()
foreach( $vm in $vms )
{
    $nif = (Get-AzureRmResource -ResourceId $vm.NetworkProfile.NetworkInterfaces[0].Id | Get-AzureRmNetworkInterface)
    if( $vm.OSProfile.LinuxConfiguration)
    {
        $os = "Linux"
    }
    else
    {
        $os = "Windows"
    }
    $vm = [PSCustomObject]@{
        Pool = $vm.Tags.pool
        Name = $vm.Name
        StatusCode = $vm.StatusCode
        ProvisioningState = $vm.ProvisioningState
        PowerState = $vm.PowerState
        PrivateIP = $nif.IpConfigurations[0].PrivateIpAddress
        OS = $os
        Size = $vm.HardwareProfile.VmSize
    }
    $vmlist += @($vm)
}

$vmlist | ft
