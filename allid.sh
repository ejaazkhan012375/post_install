#!/bin/bash
# Create user id as per stack -Sojan
# Date 12/19/2012,02/22/2013

# updated 1/14/19 bu jasonbur:
# - added all 5 fields to useradd command
# - renumbered some GIDs 
# - removed some groups that are in AD now
# updated 10/7/14 by Jason:
# - added automata group for dynamic automantion ids
# updated 9/10/14 by Jason:
# - added mqmutil group for MQ
# Updated 7/28/14 by Jason:
# - commented out control until they get an approved QMX doc
# Updated by Jason 07/16/14:
# - add mqmauth group 
# - removed the password set for SrcVScan userid

adduser() {
# Function to add users to Linux system
file=$1

lines=`grep -v '^#' $file|wc -l`
cont=1
while [ $cont -le $lines ]
do
   i=`cat $file |grep -v '^#'| head -$cont | tail -1`
   A=`echo $i|awk -F, '{print $1}'`
   B=`echo $i|awk -F, '{print $2}'`
   C=`echo $i|awk -F, '{print $3}'`
   D=`echo $i|awk -F, '{print $4}'`
   E=`echo $i|awk -F, '{print $5}'`

        egrep "^$A" /etc/passwd >/dev/null
        if [ $? -eq 0 ]; then
                echo "$A exists!"
        else
		/usr/sbin/useradd  -u $D -c "$B" -g $C -m $A
                #/usr/sbin/useradd  -c "$B" -g staff -G $C -m $A
                [ $? -eq 0 ] && echo "User $A has been added to system!" || echo "Failed to add a user $A !"
        fi
	chage -M $E $A
   cont=`expr $cont + 1`

done
}
groupadd -g 1001702 staff
groupadd -g 1001703 satuser
groupadd -g 1122607196 sshdeny
groupadd -g 10646 ibmutil

STK=$(ls -1 /root |grep -wE 'was|ihs|wmq')

case $STK in 
	was|ihs)
	  /usr/sbin/groupadd -g 2700 wsadm
	  adduser websphere.txt
	  usermod -g wsadm -G staff,sshdeny wsadmin
	  ;;
	wmq)
	  groupadd -g 1002701 mqm			
	  groupadd -g 1002702 mqmauth
	  groupadd -g 1002703 mqmutil
	  adduser mq.txt
	  ;;
esac

adduser linuxsa.txt
adduser tsmadmin.txt

exit 0

