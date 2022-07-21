#!/bin/bash

# script to install TSM client
# current TSM version is 8.1.12.0
# updated 2/1/22 by Jason - version updated to 8.1.13.3

NFS=/mnt/post_install/new_build

# check if TSM client is installed
if [ ! -f /usr/bin/dsmc ] ; then
   cd $NFS/tsm81133
   /bin/rpm -ivh gskcrypt64-8.0.55.24.linux.x86_64.rpm
   /bin/rpm -ivh gskssl64-8.0.55.24.linux.x86_64.rpm
   /bin/rpm -ivh TIVsm-API64.x86_64.rpm
   /bin/rpm -ivh TIVsm-BA.x86_64.rpm
   cp -p $NFS/dsmcad.service /etc/systemd/system/
   chmod a+x /etc/systemd/system/dsmcad.service
   echo "" >/opt/tivoli/tsm/client/ba/bin/dsm.sys
   echo "" >/opt/tivoli/tsm/client/ba/bin/dsm.opt
   echo " TSM agent installed"
else
   echo " TSM agent is already installed, skipping"
fi


