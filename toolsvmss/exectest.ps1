$numl = ( 16 )
$bsl = (8, 32, 64)
$iodl = ( 16, 32, 64, 128 )
$sleepTime = 20

foreach( $num in $numl)
{
    foreach( $bs in $bsl )
    {
        foreach( $iod in $iodl )
        {
            $filename = ( "j" + $num + "_bs" + $bs + "_iod" + $iod ) 
            Write-Host "Starting job " $filename
            $linfile = $filename + "-lin.job"
            $winfile = $filename + "-win.job"
            $output = .\control.ps1 job start ("lin1=" + $linfile + " win1=" + $winfile )
            $m = $output[1] -match "Creating job: (.*)"
            $job = $matches[1]
            $executing = $true
            while( $executing )
            {
                Start-Sleep -Seconds $sleepTime
                $output = .\control.ps1 job get $job
                $m = $output[1] -match "is: (.*)"
                $jobstatus = $matches[1]
                if( $jobstatus -ne "EXECUTING" ) 
                {
                    Write-Host "Job " $job " completed"
                    $output | out-file (".\testrun\" + $filename + ".txt")
                    $executing = $false
                }
            }
        }
    }
}