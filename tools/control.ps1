Param(
    [string] $Object,
    [string] $Command="", 
    [string] $Params=""
)

$configfile = "config.json"
$config = get-content $configfile | ConvertFrom-Json

$rgname = $config.resourcegroup
$AccountName = $config.storageaccount
$AccountKey = (Get-AzStorageAccountKey -ResourceGroupName $rgname -Name $AccountName)[0].Value
$AccountEndpoint  = (Get-AzEnvironment (Get-AzContext).Environment).StorageEndpointSuffix

$NodeTableName  = 'AzFleetNode'
$ExecTableName  = 'AzFleetExec'
$TaskTableName  = 'AzFleetTask'
$JobTableName   = 'AzFleetJob'

$workloadContainer = "workload"
$workloadPath = ".\\workload\\"
$outputContainer = "output"
$outputPath = ".\\output\\"


$ctx = New-AzStorageContext -StorageAccountName $AccountName -StorageAccountKey $AccountKey -Endpoint $AccountEndpoint

$tables = Get-AzStorageTable -Context $ctx

$NodeTable = $tables | where Name -eq $NodeTableName 
if( -not $NodeTable ) { $NodeTable = New-AzStorageTable -Name $NodeTableName -Context $ctx }
$ExecTable = $tables | where Name -eq $ExecTableName 
if( -not $ExecTable ) { $ExecTable = New-AzStorageTable -Name $ExecTableName -Context $ctx}
$TaskTable = $tables | where Name -eq $TaskTableName 
if( -not $TaskTable ) { $TaskTable = New-AzStorageTable -Name $TaskTableName -Context $ctx}
$JobTable = $tables | where Name -eq $JobTableName 
if( -not $JobTable ) { $JobTable = New-AzStorageTable -Name $JobTableName -Context $ctx}

if( -not (Get-AzStorageContainer -context $ctx -Name $workloadContainer -ErrorAction Ignore ) ){ New-AzStorageContainer -Name $workloadContainer -Context $ctx }
if( -not (Get-AzStorageContainer -context $ctx -Name $outputContainer -ErrorAction Ignore ) ){ New-AzStorageContainer -Name $outputContainer -Context $ctx }

if( -not (Test-Path $outputPath)) { md $outputPath }

function EntityToObject ($item)
{
    $p = new-object PSObject
    $p | Add-Member -Name ETag -TypeName string -Value $item.ETag -MemberType NoteProperty 
    $p | Add-Member -Name PartitionKey -TypeName string -Value $item.PartitionKey -MemberType NoteProperty
    $p | Add-Member -Name RowKey -TypeName string -Value $item.RowKey -MemberType NoteProperty
    $p | Add-Member -Name Timestamp -TypeName datetime -Value $item.Timestamp -MemberType NoteProperty

    $item.Properties.Keys | foreach { 
        $type = $item.Properties[$_].PropertyType;
        $value = $item.Properties[$_].PropertyAsObject; 
        Add-Member -InputObject $p -Name $_ -Value $value -TypeName $type -MemberType NoteProperty -Force 
    }
    $p
}

$pools = @()
function LoadPools()
{
    $global:pools = @()
    $data = Get-AzTableRow -table $NodeTable.CloudTable 
    $pooldata = $data | group PartitionKey 
    foreach( $poolentry in $pooldata )
    {
        $pool = [PSCustomObject]@{
            Name = $poolentry.Name
            Nodes = @()
            State = 'NA'
        }
        $global:pools += @( $pool )
        if( $poolentry.Group.Length -gt 0 ) { $pool.State = "READY"} 
        foreach( $nodeentry in $poolentry.Group )
        {
            $node = [PSCustomObject]@{
                Pool = $nodeentry.PartitionKey
                Name = $nodeentry.RowKey
                Timestamp = $nodeentry.TableTimestamp
                State = $nodeentry.State
                IP = $nodeentry.IP
                OS = $nodeentry.OS
                Size = $nodeentry.Size               
            }
            if( $node.State -ne "READY" ) { $pool.State = "NOT READY"} 
            $pool.Nodes += @($node)            
        }
    }
}

function ListPools()
{
    LoadPools
    foreach( $pool in $global:pools )
    {
        Write-Output ("Pool: " + $pool.Name + " " + $pool.State)
        $pool.Nodes | select Name, State, IP, OS, Size, Timestamp | ft
    }

}

function CleanTables( $Params )
{
    Get-AzTableRow -table $NodeTable.CloudTable | Remove-AzTableRow -table $NodeTable.CloudTable 
    Get-AzTableRow -table $JobTable.CloudTable | Remove-AzTableRow -table $JobTable.CloudTable 
    Get-AzTableRow -table $ExecTable.CloudTable | Remove-AzTableRow -table $ExecTable.CloudTable 
    Get-AzTableRow -table $TaskTable.CloudTable | Remove-AzTableRow -table $TaskTable.CloudTable 
}

function DebugTables()
{
    Get-AzTableRow -table $NodeTable.CloudTable  | ft 
    Get-AzTableRow -table $JobTable.CloudTable   | ft
    Get-AzTableRow -table $ExecTable.CloudTable  | ft
    Get-AzTableRow -table $TaskTable.CloudTable  | ft
}

function StartJob( $Params )
{
    #$params format:
    #pool1=fiojobfile1 pool2=fiojobfile2

    LoadPools


    $jobid = (get-date -Format "yyyyMMdd-HHmmss")

    Write-Output ""
    Write-Output ("Creating job: " + $jobid)
    $pooljobs = @()
    foreach( $param in $Params.split( ' ' ) )
    {
        $poolparam = $param.split( '=' )
        $jobfilepath = ($workloadpath  + $poolparam[1])

        #check if file exists
        if( -not (Test-path $jobfilepath)) 
        { 
            Write-Output ("File " + $jobfilepath + " does not exist!" )
            exit
        }

        $pool = $global:pools | where Name -eq $poolparam[0] | where State -eq "READY"
        if( -not $pool) 
        {
            Write-Output ("Pool " + $poolparam[0] + " does not exist or is not ready to accept jobs" )
            return
        }

        $pooljob = [PSCustomObject]@{
            Id      = $jobId
            Pool    = $pool 
            Command = "EXECUTE"
            CommandLine = "fio"
            JobFile = $poolparam[1]            
        }

        $pooljobs += @($pooljob)
    }

    foreach( $pooljob in $pooljobs )
    {
        #copy file $pooljob.FileName to blob storage 
        $jobfilepath = ($workloadpath + $pooljob.JobFile)
        Write-Output ( "Copying file: " + $pooljob.JobFile + " to storage: " + $jobfilepath )
        $temp = Set-AzStorageBlobContent -File $jobfilepath `
                                         -Container $workloadContainer `
                                         -Blob $poolJob.JobFile `
                                         -Context $ctx `
                                         -Force 

        #create task for each node 
        Write-Output ( "Executing job: " + $pooljob.JobFile + " on pool: " + $pooljob.Pool.Name )
        foreach( $node in $pooljob.Pool.Nodes )
        {
            StartTask $node $pooljob
        }


    }

    Write-Output ''
    Write-Output ''

    Add-AzTableRow -table $JobTable.CloudTable `
                   -PartitionKey $jobId `
                   -RowKey '' `
                   -property @{"Command"="Execute";"Params"=$Params}
                   
}



function GetJob( $Params)
{
    $job = GetJobData $Params 
    
    Write-Output ""
    Write-Output ("Job " + $job.Id + " is: " + $job.State)
    Write-Output ""
    if( $job.State -eq 'EXECUTING' )
    {
        $job.Executions | ft -group JobParams -property Node, State, LastUpdateTime, Output 
    }
    else
    {
        $job.Executions | ft -group JobParams -property Node, State, `
                        RIOPSmean, RMbsmean, Rlatmean, Rlat50p, Rlat90p, Rlat99p, `
                        WIOPSmean, WMbsmean, Wlatmean, Wlat50p, Wlat90p, Wlat99p, `
                        UsrCPU, SysCPU, LastUpdateTime, Output

                        
    }

}

function GetJobData( $Params )
{
    $job = [PSCustomObject]@{
        Id = $Params
        State = 'EXECUTING'
        Executions = @()
    }

    $partitionKey = $Params
    $result = Get-AzTableRow -table $ExecTable.CloudTable -partitionKey $partitionKey

    $executions = $result | select @{Label="JobId"; Expression={$_.PartitionKey}}, `
                   @{Label="Node"; Expression={$_.RowKey}}, `
                   @{Label="LastUpdateTime"; Expression={$_.TimeStamp}}, `
                   @{Label="Executable"; Expression={$_.Executable}}, `
                   @{Label="Output"; Expression={$_.Output}}, `
                   @{Label="State";Expression={$_.State}} 


    #Check also if the hearbeat from Nodes is stale. 
    #If stale more then 60 seconds, then something is wrong with the nodes. 

    foreach( $execution in $executions )
    {
        if( $execution.State -eq "COMPLETED" ) 
        {
            $execution = ExecutionResultParse $execution
            
        }
        $job.Executions += @($execution)                                
    }

    if( ($executions | where State -eq "COMPLETED").Count -eq $executions.Count )
    {
        $job.State = 'COMPLETED'
    }
    else 
    {
        $job.State = 'EXECUTING'
    }

    $job
}

function ExecutionResultParse( $execution )
{
    $outputfile = $outputPath + $execution.Output
    if( -not (Test-Path $outputfile) )
    {
        $outfile = Get-AzStorageBlobContent -Container $outputContainer `
                                            -Blob $execution.Output `
                                            -Destination ($outputPath + $execution.Output) `
                                            -Context $ctx -Force
    }

    $json = get-content ( $outputPath + $execution.Output ) | convertfrom-json
    
    $j = $json.jobs.'job options'.numjobs
    $x = ($json.jobs.'job options')

    $execution | Add-Member "JobParams" ("wl=" + $x.rw + " " + $x.rwmixread +":" + $x.rwmixwrite +"; bs=" + $x.bs + "; iodepth=" + $x.iodepth + `
                                         "; jobs=" + $x.numjobs + "; filesize=" + $x.size + "; runtime=" + $x.runtime + "; engine=" + $x.ioengine  )
    
    $execution | Add-Member "RIOPSmean" ([math]::Round($json.jobs.read.iops ))
    $execution | Add-Member "RIOPSstd" ([math]::Round($json.jobs.read.iops_stddev ))
    $execution | Add-Member "WIOPSmean" ([math]::Round($json.jobs.write.iops ))
    $execution | Add-Member "WIOPSstd" ([math]::Round($json.jobs.write.iops_stddev ))

    $execution | Add-Member "RMbsmean" ([math]::Round($json.jobs.read.bw / 1000 ))
    $execution | Add-Member "RMbsstd" ([math]::Round($json.jobs.read.bw_dev / 1000, 2 ))
    $execution | Add-Member "WMbsmean" ([math]::Round($json.jobs.write.bw / 1000 ))
    $execution | Add-Member "WMbsstd" ([math]::Round($json.jobs.read.bw_dev / 1000, 2 ))
    
    $execution | Add-Member "UsrCPU" ([math]::Round($json.jobs.usr_cpu ))
    $execution | Add-Member "SysCPU" ([math]::Round($json.jobs.sys_cpu ))

    write-host $json.jobs.read.clat_ns.percentile
    if( $json.jobs.read.clat_ns.percentile -ne $null ){
        $readlatstat = $json.jobs.read.clat_ns
        $writelatstat = $json.jobs.write.clat_ns
    }
    else {
        $readlatstat = $json.jobs.read.lat_ns
        $writelatstat = $json.jobs.write.lat_ns
    }

    $execution | Add-Member  "RLatmean"  ([math]::Round($readlatstat.mean / 1000000, 3 ))
    $execution | Add-Member  "RLat50p"  ([math]::Round($readlatstat.percentile.'50.000000' / 1000000, 3))
    $execution | Add-Member  "RLat90p"  ([math]::Round($readlatstat.percentile.'90.000000' / 1000000, 3))
    $execution | Add-Member  "RLat99p"  ([math]::Round($readlatstat.percentile.'99.000000' / 1000000, 3))

    $execution | Add-Member  "WLatmean"  ([math]::Round($writelatstat.mean / 1000000, 3 ))
    $execution | Add-Member  "WLat50p"  ([math]::Round($writelatstat.percentile.'50.000000' / 1000000, 3))
    $execution | Add-Member  "WLat90p"  ([math]::Round($writelatstat.percentile.'90.000000' / 1000000, 3))
    $execution | Add-Member  "WLat99p"  ([math]::Round($writelatstat.percentile.'99.000000' / 1000000, 3))

    $execution

}

function ListJobs() 
{
    $data = Get-AzTableRow -Table $JobTable.CloudTable
    $data | select @{Label="JobId"; Expression={$_.PartitionKey}}, `
                   @{Label="Command"; Expression={$_.Command}}, `
                   @{Label="Params";Expression={$_.Params}} `
          | sort JobId -Descending


}

function StartTask( $node, $job )
{
    Write-Output( "  Starting task: " + $job.Command + "|" + $job.CommandLine + "| on node: " + $Node.Name  )

    Add-AzTableRow -Table $TaskTable.CloudTable `
                   -PartitionKey ($node.Pool + "_" + $node.Name) `
                   -RowKey $job.Id `
                   -property @{"Command"=$job.Command;"CommandLine"=$job.CommandLine;"File"=$job.JobFile} 
                   
}

switch( $object ){
    "job" {
        switch( $command ){
            "get"{
                if( $Params -eq "" ){
                    ListJobs
                }
                else{
                    GetJob $Params
                }
                break
            }
            "start"{
                StartJob $Params
                break
            }
            default{
                Write-Output "ERROR: unrecognized command"
            }    
        }
    }

    "pool"{
        switch( $command ){
            "get"{
                if( $Params -eq "" ){
                    ListPools
                }
                else{
                    GetPool $Params
                }
                break
            }
            "clean"{
                if( $Params -eq "" ){
                    CleanPools
                }
                else{
                    #not yet implemented cleaning a single pool
                    CleanPools #$Params
                }
                break
            }
            "enable"{
                EnablePool $Params
                break
            }
            "disable"{
                DisablePool $Params
                break
            }
            default{
                Write-Output "ERROR: unrecognized command"
            }    
        }
    }

    "debug"{
        switch( $command ){
            "show"{
                if( $Params -eq "" ){
                    DebugTables
                }
                else{
                    DebugTables
                }
                break
            }
            "clean"{
                if( $Params -eq "" ){
                    CleanTables
                }
                else{
                    #not yet implemented cleaning a single pool
                    CleanTables #$Params
                }
                break
            }
            default{
                Write-Output "ERROR: unrecognized command"
            }    
        }
    }

    default{
        Write-Output "ERROR: unrecognized command"
    }
}

