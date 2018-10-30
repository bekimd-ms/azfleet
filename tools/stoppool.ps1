Param(
    [string] $vmPool
)

$configfile = "config.json"
$config = get-content $configfile | ConvertFrom-Json
$rg = $config.resourcegroup

#first check if pool with this name already exists. If it does exit with error
#check if the state of the pool machiknes in the pool is not "starting". 
$vms = get-azurermvm -ResourceGroupName $rg | where {$_.Tags.pool -eq $vmPool} 
$context = Get-AzureRMContext;
Enable-AzureRmContextAutosave -Scope CurrentUser

$jobs = @()

$script = {
    Param( $rg, $vmname, $context )
    Import-Module AzureRM -RequiredVersion 2.3.0
    Select-AzureRMContext -Name $context.Name
    Stop-AzureRMVM -ResourceGroupName $rg -Name $vmname -Force 
}

$vms | %{ 
    $job = Start-Job -Name ($_.Name + (get-date -Format "yyyyMMdd-HHmmss")) $script -ArgumentList $rg, $_.Name, $context
    Write-Output "VM $($_.Name) is being stopped in background job $($job.Name) ID $($job.Id)"
    $jobs += @($job)   
}

$sleepTime = 30
$timeElapsed = 0
$running = $true
$timeout = 1200
$completedjobs = @()

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

get-azurermvm -ResourceGroupName $rg -Status | where {$_.Tags.pool -eq $vmPool} 

