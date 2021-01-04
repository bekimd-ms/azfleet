Param(
    [string] $vmPool="none"
)

$configfile = $env:AZFLEET_CONFIG
$config = get-content $configfile | ConvertFrom-Json
$rg = $config.resourcegroup
$acct = $config.storageaccount

#first check if pool with this name already exists. If it does exit with error

$vmssname = $vmPool + "ss"
Remove-AzVMSS -ResourceGroupName $rg -VMScaleSetName $vmssname

$lbname = $vmPool + "lb"
Remove-AzLoadBalancer -ResourceGroupName $rg -Name $lbname

$ipname = $vmPool + "ip"
Remove-AzPublicIpAddress -ResourceGroupName $rg -Name $ipname


