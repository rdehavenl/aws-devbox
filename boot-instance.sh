#!/bin/bash
# Boot Instance
#
# Boot an instance, and store the dingles to a source file
#
#
# By Richard DeHaven (2015/11/08)
#
# 2017-03-01
#  Major Refactoring!
#    - Functions
#    - Fetch latest AMI
#    - Check for Existing Instances
#    - Ability to kill
#    - Tag Checking

instance_name="DevBox"
aws_cli_base="aws --output text --profile personal"
aws_type_name="t2.micro"
aws_system_key="mba-temp"
aws_secgroup="linux-basics-inbound"
run_date=$(date +%Y-%m-%d)
skip_ssh_check=1

source $HOME/.aws_my_instance

get_ami_id () {
  aws_ami_id=$(${aws_cli_base} ec2 describe-images --owners amazon --filters "Name=root-device-type,Values=ebs" "Name=virtualization-type,Values=hvm" "Name=name,Values=amzn-ami-hvm*x86_64-gp2" --query "Images[*].{Name:Name,ID:ImageId}" | grep -v "beta\|.rc" | sort -k2,2 | tail -n1 | cut -f 1)
  aws_ami_date=${run_date}
}

check_ami_id () {
  _image_date=${AWS_AMI_DATE}
  _image=${AWS_AMI_ID}
  if [ -z "$_image" ]; then
    echo "Info: Missing AMI, getting latest image"
    get_ami_id
  elif [ $(( ($(date -d "${run_date}" +%s)-$(date -d "${_image_date}" +%s))/86400 )) -gt 30 ]; then
    echo "Info: AMI is older than 30 days, getting latest image"
    get_ami_id
  else 
    aws_ami_id=$_image
    aws_ami_date=$_image_date
  fi
}

check_errors () {
  _exit_status=$1
  _exit_message=$2
  if [ ${_exit_status} != 0 ]; then
    echo "ERROR: Something went wrong, exit code:"${_exit_status}" ${_exit_message}"
    if [ ! -z "$instance_id" ]; then
      cleanup_failed $_exit_status
    else
      exit $_exit_status
    fi
  fi
}

cleanup_failed () {
  _cleanup_reason=$1
  _cleanup_id=$instance_id
  $aws_cli_base ec2 terminate-instances --instance-ids $_cleanup_id
  echo "Instance "$_cleanup_id" cleaned-up due to failure"
  exit $_cleanup_reason
}

check_ssh () {
  if [ "${skip_ssh_check}" != 0 ]; then 
    _check_ssh_hostname=$1
    _check_ssh_secs=$2
    _ssh_check=1
    _ssh_check_count=0
    _ssh_check_timeout=$(( $(date +%s) + $_check_ssh_secs ))
    echo -n "Waiting for SSH "
    while [[ $(date +%s) -lt "$_ssh_check_timeout" && "${_ssh_check}" -ne 0 ]]; do
      nc -z -w5 ${_check_ssh_hostname} 22 >/dev/null
      _ssh_check=$?
      echo -n '.'
    done
    if [[ $(date +%s) -ge "$_ssh_check_timeout" ]]; then
      check_errors 300 "SSH Check Timeout"
    fi
    echo "DONE!"
  else
    echo "Waring: Skipping SSH Check, allow ~60s before attempting connection"
  fi
}

check_for_existing () {
  _instance_ids=$(${aws_cli_base} ec2 describe-instances --filter "Name=tag:Name,Values=${instance_name}" "Name=instance-state-name,Values=pending,running" --query "Reservations[].Instances[].InstanceId[]")
  _instance_count=$(echo ${_instance_ids} | wc -w)
  if [ $_instance_count != 0 ]; then
   echo "Warning: $_instance_count instance(s) already exists with name'${instance_name}'"
   echo -n "Would you like to replace them all with this new instance? (y/N): "
   read -r -n 1 destroy
   case "$destroy" in
    Y|y)
      echo -n "WARNING: ARE YOU SURE? Type 'YES' and hit [ENTER]: "
      read -r confirm
      if [[ $confirm == "YES" ]]; then
        $aws_cli_base ec2 terminate-instances --instance-ids $_instance_ids
      else
        echo "Info: Please Clean-up the instances and try again"
        exit 0
      fi
      ;;
    
    *)
      echo "Info: Please consider cleaning up your instances, proceeding..."
      ;;
    esac
  fi 
}

tag_instance () {
  _tagged=1
  _tag_instance_id=$1
  echo "Tagging Instace"
  if [ $_tagged != 0 ]; then
    $aws_cli_base ec2 create-tags --resources ${_tag_instance_id} --tags "Key=Name,Value=${instance_name}" "Key=Date,Value=${run_date}"
    check_errors $?
    sleep 2
    $aws_cli_base ec2 describe-instances --instance-id ${_tag_instance_id} --filter "Name=tag:Name,Values=${instance_name}" | grep -q ${instance_name}
    check_errors $?
  fi
}

boot_instance () {
  ### Boot the instance
  echo "Booting instance"
  #echo "[INFO] Boot String: ${aws_cli_base} ec2 run-instances --image-id ${aws_ami_id} --instance-type ${aws_type_name} --security-groups ${aws_secgroup} --key-name ${aws_system_key}"
  _instance_boot=$(${aws_cli_base} ec2 run-instances --image-id ${aws_ami_id} --instance-type ${aws_type_name} --security-groups ${aws_secgroup} --key-name ${aws_system_key})
  check_errors $?
  instance_id=$(echo ${_instance_boot} | awk '{ print $9 }')
  echo "InstanceId: ${instance_id}"
  ### Give it some time to associate the public IP
  echo "Waiting for Boot"
  sleep 5

  ### Get the hostname of the new instance
  echo "Fetching Hostname"
  instance_hostname=$(${aws_cli_base} ec2 describe-instances --instance-ids ${instance_id} --query "Reservations[*].Instances[*].PublicDnsName")
  check_errors $?
}

set_status () {
  _set_status_id=$1
  _set_status_hostname=$2
  _set_status_ami=$aws_ami_id
  _set_status_date=$aws_ami_date
  _set_status_name=$instance_name
  echo "Setting Params in Stat File"
  echo "[INFO] AWS_HOSTNAME: ${_set_status_hostname}"
  sed -i "s/AWS_INSTANCE_ID=.*/AWS_INSTANCE_ID=${_set_status_id}/" $HOME/.aws_my_instance 
  sed -i "s/AWS_INSTANCE_HOSTNAME=.*/AWS_INSTANCE_HOSTNAME=${_set_status_hostname}/" $HOME/.aws_my_instance
  sed -i "s/AWS_AMI_ID=.*/AWS_AMI_ID=${_set_status_ami}/" $HOME/.aws_my_instance
  sed -i "s/AWS_AMI_DATE.*/AWS_AMI_DATE=${_set_status_date}/" $HOME/.aws_my_instance
  sed -i "s/AWS_INSTANCE_NAME=.*/AWS_INSTANCE_NAME=${_set_status_name}/" $HOME/.aws_my_instance
}

check_for_existing
check_ami_id
boot_instance
tag_instance $instance_id
check_ssh $instance_hostname 90
set_status $instance_id $instance_hostname $aws_ami_id
