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
Enable-AzureRmContextAutosave -Scope CurrentUser

$vms = get-azurermvm -ResourceGroupName $rg | where {$_.Tags.pool -eq $vmPool} | sort Name 

$script = {
    Param( $rg, $vmname, $context )
    Import-Module AzureRM -RequiredVersion 2.3.0
    Select-AzureRMContext -Name $context.Name
    $vm = Get-AzureRMVM -ResourceGroupName $rg -Name $vmname

    Write-Output "Removing VM $($vm.Name)"
    Remove-AzureRmVm -Name $vmName -ResourceGroupName $rg -force -verbose

    if( $vm.NetworkProfile.NetworkInterfaces.Count -gt 0 )
    {
        $vm.NetworkProfile.NetworkInterfaces[0].id -match "Interfaces/(.*)"
        $nicname = $matches[1]
        Write-Output "Removing network interface $nicname"
        Remove-AzureRmNetworkInterface -Name $nicname -ResourceGroupName $rg -force -verbose        
    }

    
    $osdiskname = $vm.StorageProfile.OSDisk.Name
    Write-Output "Removing OS disk $osdiskname"
    Remove-AzureRmDisk -Name $osdiskname -ResourceGroupName $rg -force -verbose
    
    $datadisknames = $vm.StorageProfile.DataDisks.Name
    Write-Output "Removing data disks $($datadisknames.Count)"
    $datadisknames | %{ Remove-AzureRmDisk -Name $_ -ResourceGroupName $rg -force -verbose }
}

$jobs = @()

Write-Output "Starting VM removal jobs"
$vms | %{ 
    $job = Start-Job -Name $_.Name $script -ArgumentList $rg, $_.Name, $context 
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
        else 
        {
            if( -not $completedjobs.Contains( $_.Name) ) 
            {
                Write-Output "   $($_.Name) ID $($_.Id) completed with status $($_.State)"
                $completedjobs += @( $_.Name )
            }
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

#cleanup orphaned network cards 
$nics = Get-AzureRmNetworkInterface -ResourceGroupName $rg | where Name -like ($vmPool + "*")
$nics | Remove-AzureRmNetworkInterface -force -verbose       

#cleanup orphaned disks 
$disks = Get-AzureRmDisk -ResourceGroupName $rg | where Name -like ($vmPool + "*")
$nics | Remove-AzureRmDisk -force -verbose       

#cleanup orphaned storage containers 
$vms | %
    { 
        $cont = Get-AzureStorageContainer -Context $ctx -Prefix ('bootdiagnostics-'+ ($_.Name -replace "-"))
        $cont | remove-azurestoragecontainer -Force
    }

