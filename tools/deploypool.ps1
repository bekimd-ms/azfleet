Param(
    [string] $vmPool,
    [int] $vmCount=1,
    [string] $vmOS="",
    [string] $vmSize="Standard_DS2", 
    [int] $vmDataDisks=1, 
    [int] $vmDataDiskGB=4,
    [string] $vmAdminUserName,
    [string] $vmAdminPassword
)

$configfile = "config.json"
$config = get-content $configfile | ConvertFrom-Json
$rg = $config.resourcegroup

#first check if pool with this name already exists. If it does exit with error

$dn=$rg+$vmPool
$storageEndpointSuffix= ((Get-AzContext).Environment | Get-AzEnvironment).StorageEndpointSuffix

New-AzResourceGroupDeployment -Name $dn -ResourceGroupName $rg `
                                   -TemplateFile .\templates\agent.template\agent.template.$vmOS.json `
                                   -StorageEndpointSuffix $storageEndpointSuffix -vmPool $vmPool `
                                   -vmCount $vmCount -vmSize $vmSize `
                                   -vmDataDiskCount $vmDataDisks -vmDataDiskSizeInGB $vmDataDiskGB `
                                   -vmAdminUserName $vmAdminUserName -vmAdminPassword $vmAdminPassword `
                                   -verbose