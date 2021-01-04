Param(
    [string] $vmPool
)

$configfile = $env:AZFLEET_CONFIG
$config = get-content $configfile | ConvertFrom-Json
$rg = $config.resourcegroup
$vmssname = $vmPool + "ss"

Write-Host "Starting scale set..."
Start-Azvmss -ResourceGroupName $rg -VMScaleSetName $vmssname

