#!/bin/bash

# script to install Tanium agent
# 20211104 - created by Jason 

# determine if the server is in DMZ
DMZ=no
IP=`/sbin/ifconfig eth0 | grep -w inet | awk '{print $2}' | awk -F. '{print $1}'`
case $IP in
        2|22)   DMZ=yes;;
        *)      DMZ=no;;
esac

# determine if Tanium is already installed and what version
INSTALLED=no
INSTALLED=`rpm -qa | grep -i TaniumClient`
VERSION=`echo $INSTALLED | awk -F- '{print $2}'`
if [ "$VERSION" == "7.4.5.1225" ]; then
   echo "Tanium already installed...skipping."
else
   if [ "$INSTALLED" != "no" ]; then
      # remove old version
      rpm -e $INSTALLED
   fi
   # install latest version
   rpm -i TaniumClient-7.4.5.1225-1.rhe7.x86_64.rpm
fi

cp tanium-init.dat  /opt/Tanium/TaniumClient/

if [ "$DMZ" == "yes" ]; then
   /opt/Tanium/TaniumClient/TaniumClient config set ServerNameList tvz.anthem.com,tmz.anthem.com
else
   /opt/Tanium/TaniumClient/TaniumClient config set ServerNameList taa.anthem.com,tva.anthem.com,tcz1.anthem.com,taez.anthem.com
fi
/opt/Tanium/TaniumClient/TaniumClient config set LogVerbosityLevel 1

systemctl start taniumclient
