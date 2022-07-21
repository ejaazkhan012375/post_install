#!/bin/bash
rh_version=`cat /etc/redhat-release | cut -f7 -d" " | cut -f1 -d.`
suffix=`date +%F`
case $rh_version in
   4* )
        updated_sudoers=`diff /opt/admin/sudoers.rhel4 /etc/sudoers | tail -n1`
        if [ "$updated_sudoers" != "" ] ; then
          cp /etc/sudoers /opt/admin/sudoers.$suffix
          cp /opt/admin/sudoers.rhel4 /etc/sudoers
          echo installed sudoers.rhel4 >> /var/log/messages
        fi
        ;;
   5* )
        updated_sudoers=`diff /opt/admin/sudoers.rhel5 /etc/sudoers | tail -n1`
        if [ "$updated_sudoers" != "" ] ; then
          cp /etc/sudoers /opt/admin/sudoers.$suffix
          cp /opt/admin/sudoers.rhel5 /etc/sudoers
          echo installed sudoers.rhel5 >> /var/log/messages
        fi
        ;;
   * )
        cp /etc/sudoers /opt/admin/sudoers.$suffix
        host_name=`uname -n`
        echo Red Hat Version $rh_version on $host_name is not supported by preconfigured sudoers >> /var/log/messages
        exit
        ;;
esac

