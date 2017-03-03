# My AWS Boot Scrtipts

# Description
This script is used to boot up an Amazon Linux 'devbox' in the `default-vpc`

# Usage
## Setup
    1) Copy the file `aws_my_instance` to `$HOME/.aws_my_instance`
    2) Make sure you have already installed and configured the python `awscli`
    3) Ensure you have a 'linux-basics-inbound' security group created or update
    the variable `aws_secgroup` with the group you want to use
    4) Update the `aws_system_key` variable with your SSH_Key in Amazon

## Notes
  * Script currently assumes to find some vars from `$HOME/.aws_my_instance`
  * Script currently assumes you want to use an aws credential profile 'personal'
    * Source: 
  * Script will fetch latest AMZLNX Ami to use, and will re-check every 30-days
  * Not tested on Mac yet, TODO
