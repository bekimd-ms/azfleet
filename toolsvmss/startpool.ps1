Param(
    [string] $vmPool
)

$configfile = $env:AZFLEET_CONFIG
$config = get-content $configfile | ConvertFrom-Json
$rg = $config.resourcegroup
$vmssname = $vmPool + "ss"

Start-Azvmss -ResourceGroupName $rg -VMScaleSetName $vmssname

