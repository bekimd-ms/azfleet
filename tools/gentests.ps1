$numl = (4, 8, 16 )
$bsl = (8, 32, 64)
$iodl = ( 16, 32, 64, 128 )

foreach( $num in $numl)
{
    foreach( $bs in $bsl )
    {
        foreach( $iod in $iodl )
        {
            $jobname = ( "j" + $num + "_bs" + $bs + "_iod" + $iod ) 
            $filename = ( ".\workload\" + $jobname ) 
            Write-Host $filename
            $template = get-content ".\workload\template-lin.job"
            $linfile = $filename + "-lin.job"
            ($template -replace "#JOBNAME", $jobname -replace "#BLOCKSIZE", $bs -replace "#JOBS", $num -replace "#IODEPTH", $iod) | out-file $linfile -Encoding ascii
            $template = get-content ".\workload\template-win.job"
            $winfile = $filename + "-win.job"
            ($template -replace "#JOBNAME", $jobname -replace "#BLOCKSIZE", $bs -replace "#JOBS", $num -replace "#IODEPTH", $iod) | out-file $winfile -Encoding ascii
        }
    }
}