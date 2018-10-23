# AzSFleet

AzSFleet (**Az**ure **S**tack **Fleet**) is a set of tools that enables you to run IO tests on a fleet of Linux or Windows VMs on Azure Stack. 
It consists of a set of PowerShell scripts that you can use to create pools of VMs and execute jobs that simulate IO workloads. 
It is implemented in a set of Powershell, Bash, and Python scripts as well as ARM templates.

* [Get the tools](#get-the-tools)
* [Quick start](#quick-start)
* [Tools reference](#tools-reference)

## Get the tools
You only need a client machine that can connect to your Azure Stack deployment. Ensure that you have installed powershell for Azure Stack and can connect to the Azure Stack instance. 
Follow the guidance in the Azure Stack documentation:<br>

* [Install Powershell](https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-powershell-install)<br>
* [Connect to Azure Stack](https://docs.microsoft.com/en-us/azure/azure-stack/user/azure-stack-powershell-configure-user)<br>

From github download all the files from the tools directory in this repository. <br>

    TODO Code to download from github directory 

TODO: It is currently not possible to run the tools in disconnected mode. If there is enough interest the tools and the process can be easily modified to achieve this. <br>


## Quick start
You canstart with your first test workload by following this sequence of powershell commands. <br>
Open a PowerShell console and login into your Azure Stack environment as described in the Azure Stack documents referenced above. 
Set the location, username and password variables<br>

    $location = [your Azure Stack region name]
    $username = [name of the admin user for the VMs]
    $password = [password of the admin user for the VMs]

Create a resource group and deploy the controller VM. The template will deploy a vnet that all VMs will share.<br>

     New-AzureRmResourceGroup -Name azsfleet -Location $location 
     .\deploycontroller.ps1 -ResourceGroupName azsfleet -UserName $username -Password $password

Create two pools of 2 VMs. One pool contains Linux VMs and one pool contains Windows VMs.<br>

     .\deploypool.ps1 -vmPool lin1 -vmCount 2 -vmOS linux   -vmSize Standard_F2s_v2 -vmDataDisks 4 -vmDataDiskGB 128 -vmAdminUserName $username -vmAdminPassword $password
     .\deploypool.ps1 -vmPool win1 -vmCount 2 -vmOS windows -vmSize Standard_F2s_v2 -vmDataDisks 4 -vmDataDiskGB 128 -vmAdminUserName $username -vmAdminPassword $password

After the template deployments complete check that the VMs are ready to execute jobs.<br>

     .\control pool get 

This command should return list of all VMs in each of the pool and their status.<br>
When all the VMs are ready you can start your first job: 

     .\control job start "lin1=randrw8k-lin.job win1=randrw8k-win.job"

This command will start the job and output the job ID and other information.<br>
To get the status of the job: 

    .\control job get [job id copied from output of previous command]

While the jobs are executing this will show the status of each VM. When the jobs are completed summary results for the run will be shown. <br>

    Job 20181016-204004 is: COMPLETED

        JobParams: wl=randrw 60:40; bs=32K; iodepth=128; jobs=16; filesize=4G; runtime=300; engine=libaio

    Node          State     RIOPSmean RMbsmean RLatmean RLat50p RLat90p RLat99p WIOPSmean WMbsmean WLatmean WLat50p WLat90p WLat99p UsrCPU SysCPU LastUpdateTime            Output                   
    ----          -----     --------- -------- -------- ------- ------- ------- --------- -------- -------- ------- ------- ------- ------ ------ --------------            ------                   
    lin1_lin1-vm0 COMPLETED      3443      110  353.726 312.476 624.951 809.501      2296       73  354.552 312.476 624.951 809.501      0      1 10/17/2018 3:45:07 +00:00 20181016-204004lin1_li...
    lin1_lin1-vm1 COMPLETED      3445      110  353.387 312.476 624.951 809.501      2296       73  354.768 312.476 650.117 817.889      0      1 10/17/2018 3:45:10 +00:00 20181016-204004lin1_li...


        JobParams: wl=randrw 60:40; bs=32K; iodepth=128; jobs=16; filesize=4G; runtime=300; engine=windowsaio

    Node          State     RIOPSmean RMbsmean RLatmean RLat50p  RLat90p  RLat99p WIOPSmean WMbsmean WLatmean WLat50p  WLat90p  WLat99p UsrCPU SysCPU LastUpdateTime            Output               
    ----          -----     --------- -------- -------- -------  -------  ------- --------- -------- -------- -------  -------  ------- ------ ------ --------------            ------               
    win1_win1-vm0 COMPLETED      1696       54  724.843   4.948 2801.795 3170.894      1131       36  722.968   4.751 2801.795 3170.894      0      0 10/17/2018 3:45:24 +00:00 20181016-204004win...
    win1_win1-vm1 COMPLETED      1657       53  739.642   4.424 2868.904 3238.003      1105       35  743.393   4.293 2902.458 3271.557      0      0 10/17/2018 3:45:24 +00:00 20181016-204004win...


## Tools reference
### Controller VM  
Run the deploycontroller.ps1 script to deploy the virtual network, controller and other shared objects for all the VMs that you will use for workload test. 

    .\deploycontroller.ps1 -ResourceGroupName azsfleet -UserName $username -Password $password

You only need to run this once for a new resource group. The controller doesn't need to run in order to execute workload tests.
It is only used if you need to access the individual test VMs because they are only provisioned with private IP addresses.

### Configuration
Save the resource group and the name of the storage account used for test execution. The storage account is created by the controller deployment tool. 
The format for the config.json file is: 

    {
        resourcegroup: "azsfleet",
        storageaccount: "saazsfleet"
    }

### Pools
Pools are sets of VMs with identical configuration. All the VMs in a pool have the same OS, size, number of data disks and sizes of data disks.
You can increase or decrease the size of the pool. You can stop and restart all the VMs in the pool.  
When executing a workload job you target a pool. All the VMs in the pool will execute the same job with the same parameters. 

#### Deploy a new pool 
To deploy a new pool run the deploypool.ps1 script. 

    .\deploypool.ps1 -vmPool pool1
                     -vmCount 2 
                     -vmOS linux 
                     -vmSize Standard_F2s_v2 
                     -vmDataDisks 4 
                     -vmDataDiskGB 128 
                     -vmAdminUserName $username 
                     -vmAdminPassword $password


#### Get pool info 
To get the information about the VMs in the pool run the getpool.ps1 script. 

    .\getpool.ps1 -vmPool pool1

#### Stop and start pool
To stop(deallocate) all the VMs in a pool run the stoppool.ps1 script. 

    .\stoppool.ps1 -vmPool pool1

To start all the VMs in a pool run the startpool.ps1 script. 
    
    .\stoppool.ps1 -vmPool pool1

#### Scale a pool 
You can scale the pool with the scalepool.ps1 script.<br>
To increase the size of the pool: 

    .\scalepool.ps1 -vmPool pool1 -vmDiff +5 -vmAdminUserName $username -vmAdminPassword $password

To decrease the size of the pool 

    .\scalepool.ps1 -vmPool pool1 -vmDiff -5 -vmAdminUserName $username -vmAdminPassword $password

#### Remove a pool 
To remove all the VMs in the pool run the removepool.ps1 script. 

    .\removepool.ps1 -vmPool pool1 

### Jobs
AzSFleet uses fio to run tests on both windows and linux VMs. 
The tool uses the fio job definitions decsribed here  (e.g.https://github.com/axboe/fio/tree/master/examples ). <br>
Two default jobs for windows and linux are available in the workloads directory. You can create additional job definitions that must be stored in the workloads directory.  
To execute and control jobs use the control.ps1 script. 

#### Get status of the pool 
You can get the status of the VMs in the pool by executing the following command: 

    .\control.ps1 pool get

This will output a list of VMs that are registered in the pool and their current status.  

#### Start a new job  
Execute the workload by using the control.ps1 script and passing a workload definition. 

    .\control.ps1 job start "pool1=jobfile1.job pool2=jobfile2.job" 

This command executes the jobfile1.job on pool1 and jobfile2.job on pool2. 
This will add a new job and the VM agents of the respective pools will start executing it. 

#### List jobs 
You can use control.ps1 script to list all previously completed and currently active jobs. 

    .\control.ps1 job get

#### Get job status  
You can use control.ps1 script to check the status of a job. 

    .\control.ps1 job get 

While the VM agents are still executing the job the script will output list of the VMs and their current status. 
When all VM agents have completed the job the script will output the summarized results for all the VMs. 

#### Understanding the job result output 
TBD

