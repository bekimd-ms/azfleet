apt-get update
apt-get upgrade -y

#get the data disk configuration
disks=($(find /dev/disk/azure/scsi1/* ! -iname "*part*" -exec readlink -f {} \;))
diskscnt=${#disks[*]}
disksizes=($(lsblk -l -p -o size ${disks[0]}))
disksize=${disksizes[1]}

if [ "$diskcnt" = "" ]; then
       #single disk: format the disk
       disk=${disks[0]}
       parted --script $disk mklabel gpt mkpart xfspart xfs 0% 100%
       parted --script $disk print
       diskpart="$disk"1
       mkfs.xfs $diskpart
       diskuuid=$(blkid | grep $diskpart | grep -oP '(?<= UUID=").*(?=" TYPE)')
       echo -e "UUID=$diskuuid""\t/mnt/data\txfs\tdefaults,nofail\t1\t2" >> /etc/fstab
else
       #multiple disks: create one volume striped over all data disks
       for disk in ${disks[*]}
       do
              parted --script $disk mklabel gpt mkpart xfspart xfs 0% 100%
              parted --script $disk print
       done
       pdisks=($(find /dev/disk/azure/scsi1/*-part* -exec readlink -f {} \;))
       mdadm --create /dev/md0 --level 0 --raid-devices ${#pdisks[*]} ${pdisks[*]} --force
       mkfs.ext4 /dev/md0
       echo -e "/dev/md0\t/mnt/data\text4\tdefaults\t0\t2" >> /etc/fstab
fi

mkdir /mnt/data
mount -a
chmod -R 777 /mnt/data

#install libraries 
apt-get update
apt-get install make gcc g++ unzip zlib1g-dev libboost-all-dev libssl-dev libxml2-dev libxml++2.6-dev libxml++2.6-doc uuid-dev libaio-dev cmake -y
apt-get install fio -y

#configure python libs
apt-get install python3-pip -y 
pip3 install azure-storage-blob==12.5.0
pip3 install azure-cosmosdb-table==1.0.6
pip3 install pyyaml

#setup home directory
homedir=/home/azfleet 
mkdir $homedir
chmod -R 777 $homedir
cd $homedir 

#install diskspd
cd $homedir && wget https://github.com/Microsoft/diskspd-for-linux/archive/master.zip
cd $homedir && unzip master.zip -d diskspd
cd $homedir && ./diskspd/diskspd-for-linux-master
cd $homedir/diskspd/diskspd-for-linux-master && make
cd $homedir/diskspd/diskspd-for-linux-master && make install

#install azfleet agent
cd $homedir
wget https://raw.githubusercontent.com/bekimd-ms/azfleet/master/agent/azfleetagent.py
mkdir $homedir/output
chmod -R 777 ./output
mkdir $homedir/workload
chmod -R 777 ./workload

#configure agent
AccName=$1
AccKey=$2
AccEP=$3
VMPool=$4
VMOS=$5
VMSize=$6
VMDisks=$diskscnt
VMDiskSize=$disksize
VMName=$(hostname)
VMIP=$(hostname --ip-address)

python3 ./azfleetagent.py config $AccName $AccKey $AccEP $VMPool $VMName $VMIP $VMOS $VMSize $VMDisks $VMDiskSize
                                 
#schedule the agent 
echo 'SHELL=/bin/sh' > cron.txt
echo 'PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin' >> cron.txt 
echo '' >> cron.txt
echo '@reboot cd /home/azfleet && nohup python3 ./azfleetagent.py >console.log 2>error.log &' >> cron.txt
crontab cron.txt

#start agent
cd $homedir && nohup python3 ./azfleetagent.py >/dev/null 2>agent.err &





