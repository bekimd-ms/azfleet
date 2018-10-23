Param(
    [string] $vmPool
)

$configfile = "config.json"
$config = get-content $configfile | ConvertFrom-Json
$rg = $config.resourcegroup

if( $vmPool )
{
    $vms = get-azurermvm | where {$_.Tags.pool -eq $vmPool} | where ResourceGroupName -eq $rg
}
else {
    $vms = get-azurermvm | where {$_.Tags.pool -ne $Null} | where ResourceGroupName -eq $rg
}

$vms | select {$_.Tags.pool}, Name, StatusCode, ProvisioningState | ft

