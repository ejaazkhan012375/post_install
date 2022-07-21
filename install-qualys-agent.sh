#!/bin/bash

# script to install the Qualys Agent
if rpm -qa|grep -i qualys 2>&1 > /dev/null; then
	echo Uninstalling rpm:
        if ls -l /etc/init.d/qualys*; then
		/etc/init.d/qualys* stop	
		rpm -e `rpm -qa|grep qualys`
	elif systemctl list-unit-files|grep -i qual; then
		systemctl stop qualys-cloud-agent.service
		rpm -e `rpm -qa|grep qualys`
	else
		pkill -f qualys-cloud-agent
		rpm -e `rpm -qa|grep qualys`
	fi
else 
	echo rpm not present,can proceed with install
fi
rpm -ivh QualysCloudAgent.rpm
/usr/local/qualys/cloud-agent/bin/qualys-cloud-agent.sh ActivationId=0df48740-3429-4361-bba7-931707b83a6c CustomerId=9c0e25d2-ee8a-5af6-e040-10ac13043f6a
