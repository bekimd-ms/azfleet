Param(
    [string] $vmPool,
    [int] $vmAddCount=0,
    [string] $vmAdminUserName,
    [string] $vmAdminPassword
)

$configfile = "config.json"
$config = get-content $configfile | ConvertFrom-Json
$rg = $config.resourcegroup
$acct = $config.storageaccount

$dn=$rg+$vmPool+"scale"
$storageEndpointSuffix= ((Get-AzureRmContext).Environment | Get-AzureRmEnvironment).StorageEndpointSuffix

if( $vmAddCount -gt 0 )
{
    Write-Output "Scaling pool $vmPool up with $vmAddCount new nodes." 
    $vms = get-azurermvm | where {$_.Tags.pool -eq $vmPool} | where ResourceGroupName -eq $rg
    $index = $vms.Count
    
    if( $index -gt 0 )
    {
        $vmZero = $vms[0]
        $vmOS = $vmZero.StorageProfile.OsDisk.OsType
        $vmDataDisks = $vmZero.StorageProfile.DataDisks.Count
        $vmDataDiskGB =$vmZero.StorageProfile.DataDisks[0].DiskSizeGB
        $vmSize = $vmZero.HardwareProfile.VmSize
        New-AzureRmResourceGroupDeployment -Name $dn -ResourceGroupName $rg `
                                   -TemplateFile .\md\agent.template\agent.template.$vmOS.json `
                                   -StorageEndpointSuffix $storageEndpointSuffix -vmPool $vmPool `
                                   -vmIndex $index -vmCount $vmAddCount -vmSize $vmSize `
                                   -vmDataDiskCount $vmDataDisks -vmDataDiskSizeInGB $vmDataDiskGB `
                                   -vmAdminUserName $vmAdminUserName -vmAdminPassword $vmAdminPassword `
                                   -verbose 
    }
}   
if( $vmAddCount -lt 0 )
{
    $vmAddCount = [math]::abs($vmAddCount)
    Write-Output "Scaling pool $vmPool down by $vmAddCount nodes."
    $vms = get-azurermvm | where {$_.Tags.pool -eq $vmPool} | where ResourceGroupName -eq $rg
    $vms = $vms | sort Name | select -last $vmAddCount
    $vms | Remove-AzureRmVm -force -verbose
    
    $nics = Get-AzureRmNetworkInterface | where Name -like $vmPool* | where ResourceGroupName -eq $rg
    $nics = $nics | sort Name | select -last $vmAddCount
    $nics | Remove-AzureRmNetworkInterface -force -verbose

    #also delete the storage containers
    $key = Get-AzureRmStorageAccountKey -ResourceGroupName $rg -Name $acct
    $ctx = New-AzureStorageContext -StorageAccountName $acct -StorageAccountKey $key.Key1
    
    foreach( $vm in $vms)
    {
        $cont = Get-AzureStorageContainer -Context $ctx -Prefix $vm.Name
        $cont | remove-azurestoragecontainer -Force
    }

}
