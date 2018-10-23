Param(
    [string] $vmPool
)

$configfile = "config.json"
$config = get-content $configfile | ConvertFrom-Json
$rg = $config.resourcegroup
$acct = $config.storageaccount

#first check if pool with this name already exists. If it does exit with error

$key = Get-AzureRmStorageAccountKey -ResourceGroupName $rg -Name $acct
$ctx = New-AzureStorageContext -StorageAccountName $acct -StorageAccountKey $key[0].Value
$context = Get-AzureRMContext;

$vms = get-azurermvm | where {$_.Tags.pool -eq $vmPool} | where ResourceGroupName -eq $rg | sort Name 

$script = {
    Param( $rg, $vm, $context )
    Write-Output $context
    Write-Output $rg, $vm.Name
    $vmname = $vm.Name
    Write-Output $vm.NetworkProfile.NetworkInterfaces.Count
    $vm.NetworkProfile.NetworkInterfaces[0].id -match "Interfaces/(.*)"
    $nicname = $matches[1]
    Write-Output $rg, $vmname, $nicname
    $osdiskname = $vm.StorageProfile.OSDisk.Name
    $datadisknames = $vm.StorageProfile.DataDisks.Name
    Write-Output "Removing VM"
    Remove-AzureRmVm -Name $vmName -ResourceGroupName $rg -AzureRmContext $context  -force -verbose
    Write-Output "Removing NIC"
    Remove-AzureRmNetworkInterface -Name $nicname -ResourceGroupName $rg -AzureRmContext $context -force -verbose
    Write-Output "Removing OS Disk"
    Remove-AzureRmDisk -Name $osdiskname -ResourceGroupName $rg -AzureRmContext $context -force -verbose
    Write-Output "Removing Data Disk"
    $datadisknames | %{ Remove-AzureRmDisk -Name $_ -ResourceGroupName $rg -AzureRmContext $context -force -verbose }
}

$jobs = @()

Write-Output "Starting VM removal jobs"
$vms | %{ 
    $job = Start-Job -Name $_.Name $script -ArgumentList $rg, $_, $context 
    Write-Output "($_.Name) being removed in background job $($job.Name) ID $($job.Id)"   
    $jobs += @($job)
}


$sleepTime = 30
$timeElapsed = 0
$running = $true
$timeout = 3600

while($running -and $timeElapsed -le $Timeout)
{
	$running = $false
	Write-Output "Checking job status"
	$jobs | % {
		if($_.State -eq 'Running')
		{
			$running = $true
		}
    }
    if( $running) {
	    Start-Sleep -Seconds $sleepTime
        $timeElapsed += $sleepTime
    }
}

foreach( $job in $jobs )
{
    Write-Output ("Job result for " + $job.Name )
    Receive-Job $job
    Write-Output ""
}

$vms | %{ 
    $cont = Get-AzureStorageContainer -Context $ctx -Prefix ('bootdiagnostics-'+ ($_.Name -replace "-"))
    $cont | remove-azurestoragecontainer -Force
}
