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

$vms | select {$_.Tags.pool}, Name, StatusCode, ProvisioningState, PowerState | ft


