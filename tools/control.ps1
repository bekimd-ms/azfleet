Param(
    [string] $Object,
    [string] $Command="", 
    [string] $Params=""
)

$configfile = "config.json"
$config = get-content $configfile | ConvertFrom-Json

$rgname = $config.resourcegroup
$AccountName = $config.storageaccount
$AccountKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $rgname -Name $AccountName)[0].Value
$AccountEndpoint  = (Get-AzureRmEnvironment (Get-AzureRmContext).Environment).StorageEndpointSuffix

$NodeTableName  = 'AzSFleetNodes'
$ExecTableName  = 'AzSFleetExec'
$TaskTableName  = 'AzSFleetTask'
$JobTableName   = 'AzSFleetJob'

$workloadContainer = "workload"
$workloadPath = ".\\workload\\"
$outputContainer = "output"
$outputPath = ".\\output\\"


$ctx = New-AzureStorageContext -StorageAccountName $AccountName -StorageAccountKey $AccountKey -Endpoint $AccountEndpoint

$tables = Get-AzureStorageTable -Context $ctx

$NodeTable = $tables | where Name -eq $NodeTableName 
if( -not $NodeTable ) { New-AzureStorageTable -Name $NodeTableName -Context $ctx }
$ExecTable = $tables | where Name -eq $ExecTableName 
if( -not $ExecTable ) { New-AzureStorageTable -Name $ExecTableName -Context $ctx}
$TaskTable = $tables | where Name -eq $TaskTableName 
if( -not $TaskTable ) { New-AzureStorageTable -Name $TaskTableName -Context $ctx}
$JobTable = $tables | where Name -eq $JobTableName 
if( -not $JobTable ) { New-AzureStorageTable -Name $JobTableName -Context $ctx}

if( -not (Get-AzureStorageContainer -context $ctx -Name $workloadContainer -ErrorAction Ignore ) ){ New-AzureStorageContainer -Name $workloadContainer -Context $ctx }
if( -not (Get-AzureStorageContainer -context $ctx -Name $outputContainer -ErrorAction Ignore ) ){ New-AzureStorageContainer -Name $outputContainer -Context $ctx }

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
    $query = New-Object "Microsoft.WindowsAzure.Storage.Table.TableQuery"
    $data = $NodeTable.CloudTable.ExecuteQuery($query)
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
                Timestamp = $nodeentry.TimeStamp
                State = $nodeentry.Properties["State"].StringValue
                IP = $nodeentry.Properties["IP"].StringValue
                OS = $nodeentry.Properties["OS"].StringValue
                Size = $nodeentry.Properties["Size"].StringValue               
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
        $temp = Set-AzureStorageBlobContent -File $jobfilepath `
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

    # write the job record into the jobs table
    $entity = New-Object "Microsoft.WindowsAzure.Storage.Table.DynamicTableEntity" $jobId, ''
    $entity.Properties.Add("Command", "EXECUTE")
    $entity.Properties.Add("Params", $Params)
    $temp = $JobTable.CloudTable.Execute([Microsoft.WindowsAzure.Storage.Table.TableOperation]::Insert($entity))        
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
    $query = New-Object "Microsoft.WindowsAzure.Storage.Table.TableQuery"
    $filter = [Microsoft.WindowsAzure.Storage.Table.TableQuery]::GenerateFilterCondition( `
                    "PartitionKey",`
                    [Microsoft.WindowsAzure.Storage.Table.QueryComparisons]::Equal,`
                    $partitionKey )
    $query.FilterString = $filter    
    $result = $ExecTable.CloudTable.ExecuteQuery($query)

    $executions = $result | select @{Label="JobId"; Expression={$_.PartitionKey}}, `
                   @{Label="Node"; Expression={$_.RowKey}}, `
                   @{Label="LastUpdateTime"; Expression={$_.TimeStamp}}, `
                   @{Label="Executable"; Expression={$_.Properties['Executable'].StringValue}}, `
                   @{Label="Output"; Expression={$_.Properties['Output'].StringValue}}, `
                   @{Label="State";Expression={$_.Properties['State'].StringValue}} 


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

    if( ($executions | where State -ne "EXECUTING").Count -eq $executions.Count )
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
        $outfile = Get-AzureStorageBlobContent -Container $outputContainer `
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

    $execution | Add-Member  "RLatmean"  ([math]::Round($json.jobs.read.clat_ns.mean / 1000000, 3 ))
    $execution | Add-Member  "RLat50p"  ([math]::Round($json.jobs.read.clat_ns.percentile.'50.000000' / 1000000, 3))
    $execution | Add-Member  "RLat90p"  ([math]::Round($json.jobs.read.clat_ns.percentile.'90.000000' / 1000000, 3))
    $execution | Add-Member  "RLat99p"  ([math]::Round($json.jobs.read.clat_ns.percentile.'99.000000' / 1000000, 3))

    $execution | Add-Member  "WLatmean"  ([math]::Round($json.jobs.write.clat_ns.mean / 1000000, 3 ))
    $execution | Add-Member  "WLat50p"  ([math]::Round($json.jobs.write.clat_ns.percentile.'50.000000' / 1000000, 3))
    $execution | Add-Member  "WLat90p"  ([math]::Round($json.jobs.write.clat_ns.percentile.'90.000000' / 1000000, 3))
    $execution | Add-Member  "WLat99p"  ([math]::Round($json.jobs.write.clat_ns.percentile.'99.000000' / 1000000, 3))

    $execution
}

function ListJobs() 
{
    $query = New-Object "Microsoft.WindowsAzure.Storage.Table.TableQuery"
    $data = $JobTable.CloudTable.ExecuteQuery($query)
    $data | select @{Label="JobId"; Expression={$_.PartitionKey}}, `
                   @{Label="Command"; Expression={$_.Properties['Command'].StringValue}}, `
                   @{Label="Params";Expression={$_.Properties['Params'].StringValue}} `
          | sort JobId -Descending


}

function StartTask( $node, $job )
{
    Write-Output( "  Starting task: " + $job.Command + "|" + $job.CommandLine + "| on node: " + $Node.Name  )

    $entity = New-Object "Microsoft.WindowsAzure.Storage.Table.DynamicTableEntity" ($node.Pool + "_" + $node.Name), $job.Id
    $entity.Properties.Add("Command", $job.Command)
    $entity.Properties.Add("CommandLine", $job.CommandLine)
    $entity.Properties.Add("File", $job.JobFile)
    $temp = $TaskTable.CloudTable.Execute([Microsoft.WindowsAzure.Storage.Table.TableOperation]::Insert($entity))

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

    default{
        Write-Output "ERROR: unrecognized object"
    }
}

