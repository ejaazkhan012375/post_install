#!/bin/bash

# script to install and setup dnsmasq
# 10/05/2021 - created RH8 script to install dnsmasq via local package - Jason
# 06/30/2020 - updated to add chmod 644 for the config files
# 06/02/2020 - updated to be used from current dir structure - Jason
# 08/20/2018 - created by Jason - initial script

# install dnsmasq package
rpm -ivh dnsmasq-2.79-15.el8.x86_64.rpm

# enable service in startup
systemctl enable dnsmasq

# update config file
cp /etc/dnsmasq.conf /etc/dnsmasq.conf.prednsmasq
cp dnsmasq.conf /etc/dnsmasq.conf
chmod 644 /etc/dnsmasq.conf

# create runtime folder
mkdir /var/run/dnsmasq

# update resolv.dnsmasq file
cp /etc/resolv.dnsmasq /etc/resolv.dnsmasq.prednsmasq
cp resolv.dnsmasq /etc/resolv.dnsmasq
chmod 644 /etc/resolv.dnsmasq

# update resolv.conf to add localhost
LOCAL=`grep "^nameserver 127.0.0.1" /etc/resolv.conf`
if [ "X$LOCAL" == "X" ]; then
echo "Updating resolv.conf..."
cp /etc/resolv.conf /etc/resolv.conf.prednsmasq
sed -e '
/^search/ a\
nameserver 127.0.0.1' \
< /etc/resolv.conf.prednsmasq > /etc/resolv.conf
fi
chmod 644 /etc/resolv.conf

# start service
systemctl stop dnsmasq
systemctl start dnsmasq
systemctl status dnsmasq

# test a dns lookup
dig A download.mongodb.com
dig A download.mongodb.com

