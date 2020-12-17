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
$storageEndpointSuffix= ((Get-AzContext).Environment | Get-AzEnvironment).StorageEndpointSuffix

if( $vmAddCount -gt 0 )
{
    Write-Output "Scaling pool $vmPool up with $vmAddCount new nodes." 
    $vms = Get-AzVM -ResourceGroupName $rg | where {$_.Tags.pool -eq $vmPool} 
    $index = $vms.Count
    
    if( $index -gt 0 )
    {
        $vmZero = $vms[0]
        $vmOS = $vmZero.StorageProfile.OsDisk.OsType
        $vmDataDisks = $vmZero.StorageProfile.DataDisks.Count
        $vmDataDiskGB =$vmZero.StorageProfile.DataDisks[0].DiskSizeGB
        $vmSize = $vmZero.HardwareProfile.VmSize
        New-AzResourceGroupDeployment -Name $dn -ResourceGroupName $rg `
                                   -TemplateFile .\templates\agent.template\agent.template.$vmOS.json `
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
    $vms = Get-AzVM | where {$_.Tags.pool -eq $vmPool} | where ResourceGroupName -eq $rg
    $vms = $vms | sort Name | select -last $vmAddCount
    $vms | Remove-AzVm -force -verbose
    
    $nics = Get-AzNetworkInterface | where Name -like $vmPool* | where ResourceGroupName -eq $rg
    $nics = $nics | sort Name | select -last $vmAddCount
    $nics | Remove-AzNetworkInterface -force -verbose

    #also delete the storage containers
    $key = Get-AzStorageAccountKey -ResourceGroupName $rg -Name $acct
    $ctx = New-AzStorageContext -StorageAccountName $acct -StorageAccountKey $key.Key1
    
    foreach( $vm in $vms)
    {
        $cont = Get-AzStorageContainer -Context $ctx -Prefix $vm.Name
        $cont | Remove-AzStorageContainer -Force
    }

}

get-Azvm -ResourceGroupName $rg -Status | where {$_.Tags.pool -eq $vmPool} | ft