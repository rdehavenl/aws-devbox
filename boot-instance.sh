#!/bin/bash
# Boot Instance
#
# Boot an instance, and store the dingles to a source file
#
#
# By Richard DeHaven (2015/11/08)

check_ssh () {
  ssh_check=1
  ssh_check_count=0
  echo "[BOOTING]"
  while [ "${ssh_check}" != 0 ]; do
  nc -z -w5 ${instance_hostname} 22 >/dev/null
  ssh_check=$?
  echo -n '.'
  done
  echo "DONE!"
}

### Boot the instance
echo "Booting instance"
echo "[INFO] Boot String: ec2-run-instances ami-61bbf104 -t t2.micro -k 'rdehaven@rldemail.com' -g 'default'"
instance_id=$(ec2-run-instances ami-61bbf104 -t t2.micro -k 'rdehaven@rldemail.com' -g 'default' | grep 'INSTANCE' | awk '{ print $2}')

### Give it some time to associate the public IP
echo "Waiting for Boot"
sleep 5

### Get the hostname of the new instance
echo "Fetching Hostname"
instance_hostname=$(ec2-describe-network-interfaces -F "attachment.instance-id=${instance_id}" | grep ASSOCIATION | awk '{ print $5}')

check_ssh

echo "Setting Params in Stat File"
echo "[INFO] AWS_HOSTNAME: ${instance_hostname}"
sed -i "s/AWS_INSTANCE_ID=.*/AWS_INSTANCE_ID=${instance_id}/" $HOME/.aws_my_instance 
sed -i "s/AWS_INSTANCE_HOSTNAME=.*/AWS_INSTANCE_HOSTNAME=${instance_hostname}/" $HOME/.aws_my_instance
