apt-get update
apt-get upgrade -y

#create one volume striped over all data disks
disks=($(lsblk -l -p -o NAME | grep "sd" | grep -v "sda" | grep -v "sdb"))
diskscnt=${#disks[*]}
disksizes=($(lsblk -l -p -o size ${disks[0]}))
disksize=${disksizes[1]}

for disk in ${disks[*]}
do
       echo -e "n\np\n1\n\n\nt\nfd\nw" | fdisk $disk
done
pdisks=($(lsblk -l -p -o NAME | grep "sd" | grep -v "sda" | grep -v "sdb" | grep 1))
mdadm --create /dev/md0 --level 0 --raid-devices ${#pdisks[*]} ${pdisks[*]} --force
mkfs -t ext4 /dev/md0
mkdir /data
echo -e "/dev/md0\t/data\text4\tdefaults\t0\t2" >> /etc/fstab
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

#install diskspd
cd /home && wget https://github.com/Microsoft/diskspd-for-linux/archive/master.zip
cd /home && unzip master.zip -d diskspd
cd /home && ./diskspd/diskspd-for-linux-master
cd /home/diskspd/diskspd-for-linux-master && make
cd /home/diskspd/diskspd-for-linux-master && make install

#configure python libs
apt-get install python3-pip -y 
pip3 install azure-storage-blob==2.1.0
pip3 install azure-cosmosdb-table==1.0.6  
pip3 install pyyaml

#install azsfleet agent
cd /home/ 
mkdir azsfleet
chmod -R 777 ./azsfleet
cd azsfleet
wget https://raw.githubusercontent.com/bekimd-ms/azsfleet/master/agent/azsfleetagent.py
mkdir /home/azsfleet/output
chmod -R 777 ./output
mkdir /home/azsfleet/workload
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

python3 ./azsfleetagent.py config $AccName $AccKey $AccEP $VMPool $VMName $VMIP $VMOS $VMSize $VMDisks $VMDiskSize
                                 
#schedule the agent 
echo 'SHELL=/bin/sh' > cron.txt
echo 'PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin' >> cron.txt 
echo '' >> cron.txt
echo '@reboot cd /home/azsfleet && nohup python3 ./azsfleetAgent.py >console.log 2>error.log &' >> cron.txt
crontab cron.txt

#start agent
cd /home/azsfleet && nohup python3 ./azsfleetagent.py >/dev/null 2>agent.err &





