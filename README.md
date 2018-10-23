# AzSFleet

AzSFleet (**Az**ure **S**tack **Fleet**) is a set of tools that enables you to run IO tests on a fleet of Linux or Windows VMs on Azure Stack. 
The tools consist of: 
* Set of PowerShell scripts that you use to create pools of VMs and execute workload jobs
* Set of ARM templates, Python, Bash and PowerShell scripts that execute and coordinate the workload jobs

## Prepare the tools 
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

##
Create a resource group 

### 3. Create configuration
Change to the tools directory and create a config.json file  


### 4. Deploy the control VM and vnet for all machines
Run the deploycontroller.ps1 script to deploy the controller. 


### 5. Create pool of VMs for testings
Run deploypool.ps1 script to deploy a pool. 
The script takes the following parameters: 

## Running a workload test  
### 1.Configure the fio jobs
AzSFleet uses teh fio to run tests on both windows and linux VMs.
The tool uses the fio job definitions decsribed here  (e.g.https://github.com/axboe/fio/tree/master/examples ). <br>
Two default jobs for windows and linux are available in the workloads directory. You can create additional job definitions that must be stored in the workloads directory.  

### 2.Start a workload test 
Execute the workload by using the control.ps1 script and passing a workload definition. 

    .\control.ps1 job start "pool1=jobfile1.job pool2=jobfile2.job" 

This will add a new job and the VM agents of the respective pools will start executing it. 

### 3.Monitor a workload test  
You can use control.ps1 script to check the status of a job. 

    .\control.ps1 job get [job_id]

When all VM agents have completed the job the script will output the summarized results for all the VMs. 


### 4. Managing pools
TBD


