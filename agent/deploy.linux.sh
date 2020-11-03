apt-get update
apt-get upgrade -y

#get the data disk configuration
#disks=($(lsblk -l -p -o NAME | grep "sd" | grep -v "sda" | grep -v "sdb"))
disks=($(find /dev/disk/azure/scsi1/* -exec readlink -f {} \;))
diskscnt=${#disks[*]}
disksizes=($(lsblk -l -p -o size ${disks[0]}))
disksize=${disksizes[1]}

if [ "$diskcnt" = "1"]; then
       #single disk: format the disk
       disk = ${disks[0]}
       parted $disk --script mklabel gpt mkpart xfspart xfs 0% 100%
       $diskpart = "$disk"1
       mkfs.xfs $diskpart
       echo -e "$diskpart""\t/data\xfs\tdefaults,nofail\t1\t2" >> /etc/fstab

else
       #multiple disks: create one volume striped over all data disks
       for disk in ${disks[*]}
       do
              echo -e "n\np\n1\n\n\nt\nfd\nw" | fdisk $disk
       done
       #pdisks=($(find /dev/disk/azure/scsi1/*-part* -exec readlink -f {} \;))
       mdadm --create /dev/md0 --level 0 --raid-devices ${#pdisks[*]} ${pdisks[*]} --force
       mkfs -t ext4 /dev/md0
       echo -e "/dev/md0\t/data\text4\tdefaults\t0\t2" >> /etc/fstab
fi

mkdir /data
mount -a
chmod -R 777 /data

#install libraries 
apt-get install make gcc g++ unzip zlib1g-dev libboost-all-dev libssl-dev libxml2-dev libxml++2.6-dev libxml++2.6-doc uuid-dev libaio-dev cmake -y

#install fio
cd /home && wget http://brick.kernel.dk/snaps/fio-3.5.tar.bz2
cd /home && tar -xjvf fio-3.5.tar.bz2
cd /home && ./fio-3.5/configure
cd /home/fio-3.5 && make
cd /home/fio-3.5 && make install

#TODO: Must install unzip first
#install diskspd
cd /home && wget https://github.com/Microsoft/diskspd-for-linux/archive/master.zip
cd /home && unzip master.zip -d diskspd
cd /home && ./diskspd/diskspd-for-linux-master
cd /home/diskspd/diskspd-for-linux-master && make
cd /home/diskspd/diskspd-for-linux-master && make install

#configure python libs
apt-get install python3-pip -y 
pip3 install azure-storage-blob==12.5.0
pip3 install azure-cosmosdb-table==1.0.6
pip3 install pyyaml

#install azfleet agent
cd /home/ 
mkdir azfleet
chmod -R 777 ./azfleet
cd azfleet
wget https://raw.githubusercontent.com/bekimd-ms/azfleet/master/agent/azfleetagent.py
mkdir /home/azfleet/output
chmod -R 777 ./output
mkdir /home/azfleet/workload
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
cd /home/azfleet && nohup python3 ./azfleetagent.py >/dev/null 2>agent.err &





