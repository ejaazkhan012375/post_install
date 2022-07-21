#!/bin/bash
# Create user id as per stack -Sojan
# Date 12/19/2012,02/22/2013
# Modified by Jason for AOC userids
# updated 12/18/14 jasonbur - added cenTRify group
# Updated 1/14/19 jasonbur - removed unused groups, added automata, changed useradd syntax to include all fields
# Updated 1/7/21 jasonbur - added vscan group

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
                [ $? -eq 0 ] && echo "User $A has been added to system!" || echo "Failed to add a user $A !"
        fi
	/usr/bin/chage -M $E $A
   cont=`expr $cont + 1`

done
}
groupadd -g 1001702 staff
/usr/sbin/groupadd -g 375950899 cenTRify
/usr/sbin/groupadd -g 1122584649 srcCClnx
/usr/sbin/groupadd -g 1003701 automata
/usr/sbin/groupadd -g 1704 security
/usr/sbin/groupadd -g 1160 vscan
/usr/sbin/groupadd -g 10629 cportal

adduser aoc.txt

# setup Cyberark ids
usermod -G wheel srccalgn
passwd -n 0 srccaadm
passwd -n 0 srccalgn

# setup Ansible ids
./fix_wlpipat.sh

exit 0
