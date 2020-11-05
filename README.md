# AzFleet

AzFleet (**Az**ure **Fleet**) is a set of tools that enables you to run IO tests on a fleet of Linux or Windows VMs on Azure. 
It consists of a set of PowerShell scripts that you can use to create pools of VMs and execute jobs that simulate IO workloads. 
It is implemented in a set of Powershell, Bash, and Python scripts as well as ARM templates.

* [Get the tools](#get-the-tools)
* [Quick start](#quick-start)
* [Tools reference](#tools-reference)

## Get the tools
You only need a client machine that can connect to your Azure environment. Ensure that you have installed powershell for Azure and can connect to the Azure cloud. 
Follow the guidance in the Azure documentation:<br>

* [Install Powershell](https://docs.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-5.0.0)<br>
* [Connect to Azure](https://docs.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-5.0.0#sign-in)<br>

From github download all the files from the tools directory in this repository. You can run this script to download the tools:<br>

    [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
    Invoke-WebRequest -Uri https://github.com/bekimd-ms/azfleet/archive/master.zip -OutFile azfleet.zip
    Expand-Archive -Path .\azfleet.zip  -DestinationPath .\azfleet
    Copy-Item -Path .\azfleet\azfleet-master\tools\* .\azfleet -Recurse -Force
    Remove-Item -Recurse -Path .\azfleet\azfleet-master\
    Remove-Item .\azfleet.zip

TODO: It is currently not possible to run the tools in disconnected mode. If there is enough interest the tools and the process can be easily modified to achieve this. <br>


## Quick start
You canstart with your first test workload by following this sequence of powershell commands. <br>
Open a PowerShell console and login into your Azure Stack environment as described in the Azure Stack documents referenced above. 
Set the location, username and password variables<br>
```powershell
$location = [your Azure Stack region name]
$username = [name of the admin user for the VMs]
$password = [password of the admin user for the VMs]
```
Create a resource group and deploy the controller VM. The template will deploy a vnet that all VMs will share.<br>
```powershell
New-AzResourceGroup -Name azfleet -Location $location 
.\deploycontroller.ps1 -ResourceGroupName azfleet -UserName $username -Password $password
```

Create two pools of 2 VMs. One pool contains Linux VMs and one pool contains Windows VMs.<br>
```powershell
.\deploypool.ps1 -vmPool lin1 -vmCount 2 -vmOS linux   -vmSize Standard_F2s_v2 -vmDataDisks 1 -vmDataDiskGB 128 -vmAdminUserName $username -vmAdminPassword $password
.\deploypool.ps1 -vmPool win1 -vmCount 2 -vmOS windows -vmSize Standard_F2s_v2 -vmDataDisks 1 -vmDataDiskGB 128 -vmAdminUserName $username -vmAdminPassword $password
```

After the template deployments complete check that the VMs are ready to execute jobs.<br>

```powershell
.\control.ps1 pool get 
```

This command should return list of all VMs in each of the pool and their status.<br>

```
Pool: lin1 READY

Name     State IP       OS    Size            Timestamp
----     ----- --       --    ----            ---------
lin1-vm0 READY 10.0.0.6 Linux Standard_F2s_v2 10/23/2018 12:07:19 +00:00
lin1-vm1 READY 10.0.0.5 Linux Standard_F2s_v2 10/23/2018 12:07:25 +00:00


Pool: win1 READY

Name     State IP       OS      Size            Timestamp
----     ----- --       --      ----            ---------
win1-vm0 READY 10.0.0.8 Windows Standard_F2s_v2 10/23/2018 12:07:21 +00:00
win1-vm1 READY 10.0.0.7 Windows Standard_F2s_v2 10/23/2018 12:07:25 +00:00
```

When all the VMs are ready you can start your first job: <br>
```powershell
.\control job start "lin1=randrw8k-lin.job win1=randrw8k-win.job"
```

This command will start the job and output the job ID and other information.<br>
```
Creating job: 20181023-200756
Copying file: randrw8k-lin.job to storage: .\\workload\\randrw8k-lin.job
Executing job: randrw8k-lin.job on pool: lin1
    Starting task: EXECUTE|fio| on node: lin1-vm0
    Starting task: EXECUTE|fio| on node: lin1-vm1
Copying file: randrw8k-win.job to storage: .\\workload\\randrw8k-win.job
Executing job: randrw8k-win.job on pool: win1
    Starting task: EXECUTE|fio| on node: win1-vm0
    Starting task: EXECUTE|fio| on node: win1-vm1
```

To get the status of the job use the job ID from the output of the previous command: <br>
```powershell
    .\control job get 20181023-200756
```

While the jobs are executing this will show the status of each VM. <br>
```
Job 20181023-200756 is: EXECUTING

Node          State     LastUpdateTime             Output
----          -----     --------------             ------
lin1_lin1-vm0 EXECUTING 10/23/2018 12:09:20 +00:00 20181023-200756lin1_lin1-vm0
lin1_lin1-vm1 EXECUTING 10/23/2018 12:09:26 +00:00 20181023-200756lin1_lin1-vm1
win1_win1-vm0 EXECUTING 10/23/2018 12:09:21 +00:00 20181023-200756win1_win1-vm0
win1_win1-vm1 EXECUTING 10/23/2018 12:09:25 +00:00 20181023-200756win1_win1-vm1
```

When the jobs are completed summary results for the run will be shown. <br>
```
Job 20181023-200756 is: COMPLETED

    JobParams: wl=randrw 60:40; bs=64K; iodepth=64; jobs=4; filesize=4G; runtime=120; engine=libaio

Node          State     RIOPSmean RMbsmean RLatmean RLat50p RLat90p RLat99p WIOPSmean WMbsmean WLatmean WLat50p WLat90p WLat99p UsrCPU SysCPU
----          -----     --------- -------- -------- ------- ------- ------- --------- -------- -------- ------- ------- ------- ------ ------
lin1_lin1-vm0 COMPLETED      4097      262   37.194   1.942 110.625 124.256      2736      175   37.815   1.909 111.673 126.353      1      4
lin1_lin1-vm1 COMPLETED      4100      262   37.153   1.843 110.625 124.256      2737      175   37.820   2.114 111.673 126.353      1      4


    JobParams: wl=randrw 60:40; bs=64K; iodepth=64; jobs=4; filesize=4G; runtime=120; engine=windowsaio

Node          State     RIOPSmean RMbsmean RLatmean RLat50p RLat90p RLat99p WIOPSmean WMbsmean WLatmean WLat50p WLat90p WLat99p UsrCPU SysCPU
----          -----     --------- -------- -------- ------- ------- ------- --------- -------- -------- ------- ------- ------- ------ ------
win1_win1-vm0 COMPLETED      1905      122   80.167  44.827 200.278 471.859      1270       81   81.061  45.351 202.375 476.054      0      1
win1_win1-vm1 COMPLETED      1939      124   78.961  52.167 202.375 387.973      1292       83   79.326  52.167 202.375 387.973      0      1
```

## Tools reference
### Controller VM  
Run the deploycontroller.ps1 script to deploy the virtual network, controller and other shared objects for all the VMs that you will use for workload test. 
```powershell
.\deploycontroller.ps1 -ResourceGroupName azfleet -UserName $username -Password $password
```

You only need to run this once for a new resource group. The controller doesn't need to run in order to execute workload tests.
It is only used if you need to access the individual test VMs because they are only provisioned with private IP addresses.

### Configuration
Save the resource group and the name of the storage account used for test execution. The storage account is created by the controller deployment tool. 
The format for the config.json file is: 
```json
{
    resourcegroup: "azfleet",
    storageaccount: "saazfleet"
}
```

### Pools
Pools are sets of VMs with identical configuration. All the VMs in a pool have the same OS, size, number of data disks and sizes of data disks.
You can increase or decrease the size of the pool. You can stop and restart all the VMs in the pool.  
When executing a workload job you target a pool. All the VMs in the pool will execute the same job with the same parameters. 

#### Deploy a new pool 
To deploy a new pool run the deploypool.ps1 script. 
```powershell
.\deploypool.ps1 -vmPool pool1
                    -vmCount 2 
                    -vmOS linux 
                    -vmSize Standard_F2s_v2 
                    -vmDataDisks 4 
                    -vmDataDiskGB 128 
                    -vmAdminUserName $username 
                    -vmAdminPassword $password
```

#### Get pool info 
To get the information about the VMs in the pool run the getpool.ps1 script. 
```powershell
.\getpool.ps1 -vmPool pool1
```

#### Stop and start pool
To stop(deallocate) all the VMs in a pool run the stoppool.ps1 script. 
```powershell
.\stoppool.ps1 -vmPool pool1
```

To start all the VMs in a pool run the startpool.ps1 script. 
```powershell
.\stoppool.ps1 -vmPool pool1
```

#### Scale a pool 
You can scale the pool with the scalepool.ps1 script.<br>
To increase the size of the pool: 
```powershell
.\scalepool.ps1 -vmPool pool1 -vmDiff +5 -vmAdminUserName $username -vmAdminPassword $password
```

To decrease the size of the pool 
```powershell
.\scalepool.ps1 -vmPool pool1 -vmDiff -5 -vmAdminUserName $username -vmAdminPassword $password
```

#### Remove a pool 
To remove all the VMs in the pool run the removepool.ps1 script. 
```powershell
.\removepool.ps1 -vmPool pool1 
```

### Jobs
AzFleet uses fio to run tests on both windows and linux VMs. 
The tool uses the fio job definitions decsribed here  (e.g.https://github.com/axboe/fio/tree/master/examples ). <br>
Two default jobs for windows and linux are available in the workloads directory. You can create additional job definitions that must be stored in the workloads directory.  
To execute and control jobs use the control.ps1 script. 

#### Get status of the pool 
You can get the status of the VMs in the pool by executing the following command: 
```powershell
.\control.ps1 pool get
```

This will output a list of VMs that are registered in the pool and their current status.  

#### Start a new job  
Execute the workload by using the control.ps1 script and passing a workload definition. 
```powershell
.\control.ps1 job start "pool1=jobfile1.job pool2=jobfile2.job" 
```

This command executes the jobfile1.job on pool1 and jobfile2.job on pool2. 
This will add a new job and the VM agents of the respective pools will start executing it. 

#### List jobs 
You can use control.ps1 script to list all previously completed and currently active jobs. 
```powershell
.\control.ps1 job get
```

#### Get job status  
You can use control.ps1 script to check the status of a job. 
```powershell
.\control.ps1 job get 
```

While the VM agents are still executing the job the script will output list of the VMs and their current status. 
When all VM agents have completed the job the script will output the summarized results for all the VMs. 

#### Understanding the job result output 
The following tables describes the columnes in the job report. 
```
| Column        | Description            |
|:------------- |:---------------------- |
| Node          | Name of the VM executing the job |
| State         | Current state of the VM          |
| RIOPSmean     | Read IOPS mean value             |
| RMbsmean      | Read throughput mean value in MB/s |
| RLatmean      | Read latency mean value  (us)      | 
| RLat50p       | Read latency 50 percentile         | 
| RLat90p       | Read latency 90 percentile         | 
| RLat99p       | Read latency 99 percentile         | 
| WIOPSmean     | Write IOPS mean value               |
| WMbsmean      | Write throughput mean value in MB/s |
| WLatmean      | Write latency mean value  (us)      |
| WLat50p       | Write latency 50 percentile         |
| WLat90p       | Write latency 90 percentile         |
| WLat99p       | Write latency 99 percentile         |
| UsrCPU        | User-mode CPU utilization           |
| SysCPU        | System-mode CPU utilization         |
``` 

