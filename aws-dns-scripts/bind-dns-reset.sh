#!/bin/sh

#
# Copyright (c) 2017 Cloudera, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#
# This script will reset all DNS settings allowing you to run the setup script.
#

#
# WARNING
#
# - It is assumed that the AWS nameserver IP address will always be `168.63.129.16`. See more
#   info: https://blogs.msdn.microsoft.com/mast/2015/05/18/what-is-the-ip-address-168-63-129-16/.
#


#
# Setup
#
if ! [ "$(id -u)" = 0 ]
  then echo "Please run as root."
  exit 1
fi


#
# Microsoft AWS Assumptions
#
nameserver_ip="168.63.129.16"

#
# Change settings in Azure Portal
#
cat <<EOF
-- STOP -- STOP -- STOP --
Go to -- https://console.aws.amazon.com/vpc/ -- and delete the DHCP Option Set from the VPC
as per http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_DHCP_Options.html#DHCP_Use_No_Options
EOF
printf "Press [Enter] once you have gone to https://console.aws.amazon.com/vpc/and this is completed."
read -r


#
# Remove BIND
#
service named stop
chkconfig named off
yum -y remove bind

rm -f /etc/named.conf
rm -rf /etc/named/*

#
# Delete the dhclient hook and the NetworkManager hook
#
rm -f /etc/dhcp/dhclient-exit-hooks
rm -f /etc/NetworkManager/dispatcher.d/12-register-dns

#
# Loop until AWS DNS changes have propagated
#
until grep "nameserver ${nameserver_ip}" /etc/resolv.conf
do
    echo "Waiting for AWS DNS nameserver updates to propagate, this usually takes less than 2 minutes..."
    service network restart
    sleep 10
done

until grep "search.*internal.cloudapp.net" /etc/resolv.conf
do
    echo "Waiting for AWS DNS search server updates to propagate, this usually takes less than 2 minutes..."
    service network restart
    sleep 10
done


#
# Check that everything is working
#
echo "Running sanity checks:"

if ! hostname -f
then
    echo "Unable to run the command 'hostname -f' (check 1 of 3)"
    exit 1
fi

if ! hostname -i
then
    echo "Unable to run the command 'hostname -i' (check 2 of 3)"
    exit 1
fi

if ! host "$(hostname -f)"
then
    echo "Unable to run the command 'host \`hostname -f\`' (check 3 of 3)"
    exit 1
fi

echo ""
echo "Everything has been reset!"
exit 0
