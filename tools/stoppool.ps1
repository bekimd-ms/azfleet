Param(
    [string] $vmPool
)

$configfile = "config.json"
$config = get-content $configfile | ConvertFrom-Json
$rg = $config.resourcegroup

#first check if pool with this name already exists. If it does exit with error

#check if the state of the pool machiknes in the pool is not "starting". 
$vms = get-azurermvm | where {$_.Tags.pool -eq $vmPool} | where ResourceGroupName -eq $rg
$context = Get-AzureRMContext;

$jobIds = @()

$script = {
    Param( $rg, $vmname, $context )
    Stop-AzureRMVM -ResourceGroupName $rg -Name $vmname -Force -AzureRmContext $context
}

$vms | %{ 
    $job = Start-Job -Name $_.Name $script -ArgumentList $rg, $_.Name, $context
    Write-Output "VM $($_.Name) being stopped in background job $($job.Name) ID $($job.Id)"   
}

$sleepTime = 30
$timeElapsed = 0
$running = $true
$timeout = 1200

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

