Param(
    [string] $vmPool="none"
)

$configfile = $env:AZFLEET_CONFIG
$config = get-content $configfile | ConvertFrom-Json
$rg = $config.resourcegroup
$acct = $config.storageaccount

#first check if pool with this name already exists. If it does exit with error

Write-Host "Removing scale set..."
$vmssname = $vmPool + "ss"
Remove-AzVMSS -ResourceGroupName $rg -VMScaleSetName $vmssname -Force

Write-Host "Removing load balancer..."
$lbname = $vmPool + "lb"
Remove-AzLoadBalancer -ResourceGroupName $rg -Name $lbname -Force

Write-Host "Removing public ip..."
$ipname = $vmPool + "ip"
Remove-AzPublicIpAddress -ResourceGroupName $rg -Name $ipname -Force


