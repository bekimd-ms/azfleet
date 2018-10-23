# azsfleet

## Deploy AzSFleet
### 1. Download the code 
From github download all the files from the tools directy in this repository  

### 2. Deploy controller VM and some resources.
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

.\control.ps1 job get <job_id>

When all VM agents have completed the job the script will output the summarized results for all the VMs. 

