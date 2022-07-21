#!/bin/ksh
########################################################################
# © Copyright IBM Corp. 2014
#
# 	Tivoli ITM Unix Monitoring Agent Installation
#
#######################################################################
echo "######################################################################"
echo "# 	Tivoli ITM Unix Monitoring Agent Installation    #"
echo "#                                                                    #"
echo "#####################################################################"
CANDLEHOME=/opt/IBM/ITM

# command line opts
# account ptem stem file
# Note that the config file is sourced to set variable values,
# so the names in the file ('acct', 'ptem' and 'stem') must have
# variables of the same name in this script.
acct=
configFile=
ptem=
stem=
while getopts "a:(acct)(account)f:(file)p:(ptem)s:(stem)" opt
do
    case $opt in
	a) acct=$OPTARG;;
	f) configFile=$OPTARG;;
	p) ptem=$OPTARG;;
	s) stem=$OPTARG;;
	*) exit 1;;
    esac
done
echo cli: acct = $acct
echo cli: configFile = $configFile
echo cli: ptem = $ptem
echo cli: stem = $stem
shift $(($OPTIND -1))
# exit

if [[ -s $configFile ]]
then
	if [[ -r $configFile ]]
	then
		dir=`dirname $configFile`
		if [[ -z $dir ]]
		then 
			dir=.
		. "$dir/$configFile"
		else
		 . $configFile
		fi
		echo file: acct = $acct
		echo file: ptem = $ptem
		echo file: stem = $stem
	else
		echo Cannot read config file $configFile
		echo "Exiting the installation"
		exit 1
	fi
fi
# Get the short hostname and create the agent and other names
shortname=`hostname | cut -d. -f1`

# check required items
if [[ -z "$acct" ]]
then
	tema=$shortname
#	echo "Error: account value is missing"
#	echo "Exiting the installation"
#	exit 1
else
	echo ready: acct = $acct
        tema=$acct\_$shortname
fi
if [[ -z $ptem ]]
then
	if [[ -z $stem ]]
	then
		echo "Error: RTEMS IP address  value is missing"
		echo "Exiting the installation"
		exit 1
	else
		ptem=$stem
		stem=
	fi
fi

echo ready: ptem = $ptem
echo ready: stem = $stem


serveros=`uname -a | awk '{print $1}'`
case $serveros in
	Linux) shortos=lz; osagent=klzagent ;;
	*) shortos=ux; osagent=kuxagent ;;
esac

# Check if root is performing the installation
case $serveros in
	SunOS) yourid=`/usr/xpg4/bin/id -u` ;;
	*) yourid=`id -u` ;;
esac

if (( $yourid != 0 )); then
	echo "Error: Installation must be done with root authority"
	echo "Login as root and restart the installation"
	echo "Exiting the installation"
	exit 1
fi
# Check if CANDLEHOME filesystem exists  and has enough space
if [[ ! -d $CANDLEHOME ]]; then
	echo Error: $CANDLEHOME filesystem does not exist
	echo Error: Create $CANDLEHOME filesystem and then run $0
	echo Error: Make sure there is at least 500 MB space
	echo Exiting the installation
	exit 1
fi
case $serveros in
	HP-UX) dfspace=`df -kP $CANDLEHOME | grep -v Filesystem | awk '{print $3}'` ;;
	*) dfspace=`df -k $CANDLEHOME | grep -v Filesystem | awk '{print $3}'` ;;
esac
if (( $dfspace < 5120 )); then
	echo ERROR: Not enough space in $CANDLEHOME
        echo Error: Make sure there is at least 500 MB space
	echo Exiting the installation
	exit 1
fi
#Check if tivadmn group exists if not then create it
#grep ^tivadmn: /etc/group  > /dev/null 2>&1
#if [[ $? != 0 ]]; then
#case $serveros in
#AIX) mkgroup tivadmn ;;
#*)  groupadd  tivadmn ;;
#esac
#fi

# Verify that lockdown.sh script exists
 if [[ ! -f $PWD/lockdown.sh ]]; then
                echo ERROR: Unable to find $PWD/lockdown.sh
                echo ERROR: Installation Error
                echo Contact the Tivoli Administrator
                exit 1
fi

# write the silent config file

silentConfig=./${acct}_silent_config_RTEMS.txt
# echo silentConfig = $silentConfig
echo "#############################################################################" > $silentConfig
echo "#" >> $silentConfig
echo "# IBM Confidential" >> $silentConfig
echo "# OCO Source Materials" >> $silentConfig
echo "# 5724-C04" >> $silentConfig
echo "#" >> $silentConfig
echo "# Copyright IBM Corp. 2005" >> $silentConfig
echo "# The source code for this program is not published or otherwise" >> $silentConfig
echo "# divested of its trade secrets, irrespective of what has" >> $silentConfig
echo "# been deposited with the U.S. Copyright Office." >> $silentConfig
echo "#" >> $silentConfig
echo "#############################################################################" >> $silentConfig
echo "" >> $silentConfig
echo "# This is a sample silent configuration response file" >> $silentConfig
echo "" >> $silentConfig
echo "# To configure an agent using this silent response file:" >> $silentConfig
echo "#   1) copy this file to another location and modify the necessary parameters" >> $silentConfig
echo "#   2) run 'CandleConfig -A -p <silent_response_file> <pc>'" >> $silentConfig
echo "#      - give an absolute path for the silent_response_file" >> $silentConfig
echo "#      - pc is the two character product code of the agent to be configured" >> $silentConfig
echo "" >> $silentConfig
echo "# Syntax rules:" >> $silentConfig
echo "# - Comment lines begin with '#'" >> $silentConfig
echo "# - Blank lines are ignored" >> $silentConfig
echo "# - Parameter lines are PARAMETER=value (do not put space before the PARAMETER)" >> $silentConfig
echo "# - Space before or after an equal sign is OK" >> $silentConfig
echo "# - Parameter values should NOT contain the following characters $, =, or |" >> $silentConfig
echo "" >> $silentConfig
echo "################## PRIMARY TEMS CONFIGURATION ##################" >> $silentConfig
echo "" >> $silentConfig
echo "# Will this agent connect to a Tivoli Enterprise Monitoring Server (TEMS)?" >> $silentConfig
echo "# This parameter is required." >> $silentConfig
echo "# Valid values are: YES and NO" >> $silentConfig
echo "CMSCONNECT=YES" >> $silentConfig
echo "" >> $silentConfig
echo "# What is the hostname of the TEMS to connect to?" >> $silentConfig
echo "# This parameter is NOT required.  (default is the local system hostname)" >> $silentConfig
echo "HOSTNAME=$ptem" >> $silentConfig
echo "" >> $silentConfig
echo "# Will this agent connect to the TEMS through a firewall?" >> $silentConfig
echo "# This parameter is NOT required.  (default is NO)" >> $silentConfig
echo "# Valid values are: YES and NO" >> $silentConfig
echo "#   - If set to YES the NETWORKPROTOCOL must be ip.pipe" >> $silentConfig
echo "FIREWALL=YES" >> $silentConfig
echo "" >> $silentConfig
echo "# What network protocol is used when connecting to the TEMS?" >> $silentConfig
echo "# This parameter is required." >> $silentConfig
echo "# Valid values are: ip, sna, ip.pipe, or ip.spipe" >> $silentConfig
echo "NETWORKPROTOCOL=ip.spipe" >> $silentConfig
echo "" >> $silentConfig
echo "# What is the first backup network protocol used for connecting to the TEMS?" >> $silentConfig
echo "# This parameter is NOT required. (default is none)" >> $silentConfig
echo "# Valid values are: ip, sna, ip.pipe, ip.spipe, or none" >> $silentConfig
echo "#BK1NETWORKPROTOCOL=none" >> $silentConfig
echo "" >> $silentConfig
echo "# What is the second backup network protocol used for connecting to the TEMS?" >> $silentConfig
echo "# This parameter is NOT required. (default is none)" >> $silentConfig
echo "# Valid values are: ip, sna, ip.pipe, ip.spipe or none" >> $silentConfig
echo "#BK2NETWORKPROTOCOL=none" >> $silentConfig
echo "" >> $silentConfig
echo "# If ip.pipe is one of the three protocols what is the IP pipe port number?" >> $silentConfig
echo "# This parameter is NOT required. (default is 1918)" >> $silentConfig
echo "#IPPIPEPORTNUMBER=1918" >> $silentConfig
echo "" >> $silentConfig
echo "# If ip.pipe is one of the three protocol what is the IP pipe partition name?" >> $silentConfig
echo "# This parameter is NOT required. (default is null)" >> $silentConfig
echo "#KDC_PARTITIONNAME=null" >> $silentConfig
echo "" >> $silentConfig
echo "# If ip.pipe is one of the three protocols what is the KDC partition file?" >> $silentConfig
echo "# This parameter is NOT required. (default is null)" >> $silentConfig
echo "#KDC_PARTITIONFILE=null" >> $silentConfig
echo "" >> $silentConfig
echo "# If ip.spipe is one of the three protocols what is the IP pipe port number?" >> $silentConfig
echo "# This parameter is NOT required. (default is 3660)" >> $silentConfig
echo "IPSPIPEPORTNUMBER=3660" >> $silentConfig
echo "" >> $silentConfig
echo "# If ip is one of the three protocols what is the IP port number?" >> $silentConfig
echo "# This parameter is NOT required. (default is 1918)" >> $silentConfig
echo "# A port number and or one or more pools of port numbers can be given." >> $silentConfig
echo "# The format for a pool is #-# with no embedded blanks." >> $silentConfig
echo "#PORTNUMBER=1918" >> $silentConfig
echo "" >> $silentConfig
echo "# If sna is one of the three protocols what is the SNA net name?" >> $silentConfig
echo "# This parameter is NOT required. (default is CANDLE)" >> $silentConfig
echo "#NETNAME=CANDLE" >> $silentConfig
echo "" >> $silentConfig
echo "# If sna is one of the three protocols what is the SNA LU name?" >> $silentConfig
echo "# This parameter is NOT required. (default is LUNAME)" >> $silentConfig
echo "#LUNAME=LUNAME" >> $silentConfig
echo "" >> $silentConfig
echo "# If sna is one of the three protocols what is the SNA log mode?" >> $silentConfig
echo "# This parameter is NOT required. (default is LOGMODE)" >> $silentConfig
echo "#LOGMODE=LOGMODE" >> $silentConfig
echo "" >> $silentConfig
echo "################## SECONDARY TEMS CONFIGURATION ##################" >> $silentConfig
echo "" >> $silentConfig
echo "# Would you like to configure a connection for a secondary TEMS?" >> $silentConfig
echo "# This parameter is NOT required. (default is NO)" >> $silentConfig
echo "# Valid values are: YES and NO" >> $silentConfig
if [[ -z $stem ]]; then
	echo "#FTO=NO" >> $silentConfig
else
	echo "FTO=YES" >> $silentConfig
fi
echo "" >> $silentConfig
echo "# If configuring a connection for a secondary TEMS, what is the hostname of the secondary TEMS?" >> $silentConfig
echo "# This parameter is required if FTO=YES" >> $silentConfig
if [[ -z $stem ]]; then
	echo "#MIRROR=somehost.somewhere.com" >> $silentConfig
else
	echo "MIRROR=$stem" >> $silentConfig
fi
echo "" >> $silentConfig
echo "# Will the agent connect to the secondary TEMS through a firewall?" >> $silentConfig
echo "# This parameter is NOT required. (default is NO)" >> $silentConfig
echo "# Valid values are: YES and NO" >> $silentConfig
if [[ -z $stem ]]; then
	echo "#FIREWALL2=NO" >> $silentConfig
else
	echo "FIREWALL2=YES" >> $silentConfig
fi
echo "" >> $silentConfig
echo "# What network protocol is used when connecting to the secondary TEMS?" >> $silentConfig
echo "# This parameter is required when FTO=YES and FIREWALL2 is NO" >> $silentConfig
echo "# Valid values are: ip, sna, or ip.pipe" >> $silentConfig
if [[ -z $stem ]]; then
	echo "#HSNETWORKPROTOCOL=ip.spipe" >> $silentConfig
else
	echo "HSNETWORKPROTOCOL=ip.spipe" >> $silentConfig
fi
echo "" >> $silentConfig
echo "# What is the first backup network protocol used for connecting to the secondary TEMS?" >> $silentConfig
echo "# This parameter is NOT required. (default is none)" >> $silentConfig
echo "# Valid values are: ip, sna, ip.pipe, or none" >> $silentConfig
echo "#BK1HSNETWORKPROTOCOL=none" >> $silentConfig
echo "" >> $silentConfig
echo "# What is the second backup network protocol used for connecting to the secondary TEMS?" >> $silentConfig
echo "# This parameter is NOT required. (default is none)" >> $silentConfig
echo "# Valid values are: ip, sna, ip.pipe, or none" >> $silentConfig
echo "#BK2HSNETWORKPROTOCOL=none" >> $silentConfig
echo "" >> $silentConfig
echo "# If ip.spipe is one of the three secondary TEMS protocols what is the IP pipe port number?" >> $silentConfig
echo "# This parameter is NOT required. (default is 3660)" >> $silentConfig
if [[ -z $stem ]]; then
	echo "#HSIPPIPEPORTNUMBER=3660" >> $silentConfig
else
	echo "HSIPPIPEPORTNUMBER=3660" >> $silentConfig
fi
echo "" >> $silentConfig
echo "# If ip is one of the three secondary TEMS protocols what is the IP port number?" >> $silentConfig
echo "# This parameter is NOT required. (default is 1918)" >> $silentConfig
echo "# A port number and or one or more pools of port numbers can be given." >> $silentConfig
echo "# The format for a pool is #-# with no embedded blanks." >> $silentConfig
echo "#HSPORTNUMBER=1918" >> $silentConfig
echo "" >> $silentConfig
echo "# If sna is one of the three secondary TEMS protocols what is the SNA net name?" >> $silentConfig
echo "# This parameter is NOT required. (default is CANDLE)" >> $silentConfig
echo "#HSNETNAME=CANDLE" >> $silentConfig
echo "" >> $silentConfig
echo "# If sna is one of the three secondary TEMS protocols what is the SNA LU name?" >> $silentConfig
echo "# This parameter is NOT required. (default is LUNAME)" >> $silentConfig
echo "#HSLUNAME=LUNAME" >> $silentConfig
echo "" >> $silentConfig
echo "# If sna is one of the three secondary TEMS protocols what is the SNA log mode?" >> $silentConfig
echo "# This parameter is NOT required. (default is LOGMODE)" >> $silentConfig
echo "#HSLOGMODE=LOGMODE" >> $silentConfig
echo "" >> $silentConfig
echo "################## OPTIONAL PRIMARY NETWORK NAME CONFIGURATION ##################" >> $silentConfig
echo "" >> $silentConfig
echo "# If the system is equipped with dual network host adapter cards you can designate" >> $silentConfig
echo "# another network name.  What is the network name?" >> $silentConfig
echo "# This parameter is NOT required. (default is none)" >> $silentConfig
echo "#PRIMARYIP=none" >> $silentConfig

echo Created $silentConfig


# Verify silentInstall.sh file exists
 if [[ ! -f $PWD/silentInstall.sh ]]; then
                echo "ERROR: Unable to find silentInstall.sh"
                echo "ERROR: Installation Error"
                echo "Contact the Tivoli Administrator"
                exit 1
fi

# Start the installation of the agent	     
           $PWD/silentInstall.sh
	   if (( $? != 0 )) ; then
		echo "ERROR: silentInstall.sh returned an error"
	        echo "Contact the Tivoli Administrator"
		exit 1
	   fi
# Verify $CANDLEHOME/bin/CandleConfig file exists
	     if [[ ! -f $CANDLEHOME/bin/CandleConfig ]]; then
	    	echo "ERROR: Unable to find $CANDLEHOME/bin/CandleConfig"
		echo "ERROR: Installation Error"
	        echo "Contact the Tivoli Administrator"
		exit 1
	     fi

# Start the configuration of the agent
           $CANDLEHOME/bin/CandleConfig -A -p $PWD/$silentConfig $shortos
	   if (( $? != 0 )) ; then
		echo "ERROR: Unix agent configuration returned an error"
	        echo "Contact the Tivoli Administrator"
		exit 1
	   fi

#Make a backup of the ini files
echo "Adding CTIRA_HOSTNAME, CTIRA_SYSTEM_NAME and CTIRA_SUBSYSTEM_ID"
echo "Making a backup of the ini files"

if [[ ! -f $CANDLEHOME/config/$shortos.ini ]];then
        echo "Error: Unable to find $CANDLEHOME/config/$shortos.ini file"
        echo "Contact the Tivoli Administrator"
        exit 1
fi

cp $CANDLEHOME/config/$shortos.ini $CANDLEHOME/config/$shortos.ini.org
cat $CANDLEHOME/config/$shortos.ini | grep -v CTIRA_HOSTNAME | grep -v CTIRA_SYSTEM_NAME > /tmp/$shortos.ini
echo "CTIRA_HOSTNAME=$tema" >> /tmp/$shortos.ini
echo "CTIRA_SYSTEM_NAME=$tema" >> /tmp/$shortos.ini
echo "CTIRA_SUBSYSTEM_ID=" >> /tmp/$shortos.ini
#echo "KDC_FAMILIES=$NETWORKPROTOCOL$ EPHEMERAL:Y HTTP_CONSOLE:N HTTP_SERVER:N HTTP:0" >> /tmp/$shortos.ini
#echo "GSK_PROTOCOL_SSLV2=OFF" >> /tmp/$shortos.ini
#echo "GSK_PROTOCOL_SSLV3=ON" >> /tmp/$shortos.ini
#echo "GSK_V3_CIPHER_SPECS=352F0A" >> /tmp/$shortos.ini
cp /tmp/$shortos.ini $CANDLEHOME/config/$shortos.ini

rm /tmp/$shortos.ini

# Create $CANDLEHOME/smitools directories
#mkdir $CANDLEHOME/smitools; mkdir $CANDLEHOME/smitools/scripts
#mkdir $CANDLEHOME/smitools/config; mkdir $CANDLEHOME/smitools/tmp
#mkdir $CANDLEHOME/smitools/ini; mkdir $CANDLEHOME/smitools/logs
#chown -R root:tivadmn $CANDLEHOME/smitools
#chmod -R 711 $CANDLEHOME/smitools
#chmod -R 755 $CANDLEHOME/smitool/tmp


#Create the  Environment file to the proper OS and populate it.
logfile=/tmp/fix_HTTP_ITM.log
if [[ -f $CANDLEHOME/config/$serveros.env ]];
then
        echo "`date` - The env file already exist" >> $logfile
        PID=$$
        echo "`date` - Backuping the env file.... $serveros.env.$PID" >> $logfile
        cp $CANDLEHOME/config/$serveros.env $CANDLEHOME/config/$serveros.env.$PID
        echo "`date` - Creating a new env file..." >> $logfile
        >$CANDLEHOME/config/$serveros.env
        echo "export KDC_FAMILIES=\"EPHEMERAL:Y HTTP_CONSOLE:N HTTP_SERVER:N HTTP:0 \${KDC_FAMILIES}\"" >> $CANDLEHOME/config/$serveros.env
        echo "GSK_PROTOCOL_SSLV2=OFF" >> $CANDLEHOME/config/$serveros.env
        echo "GSK_PROTOCOL_SSLV3=ON" >> $CANDLEHOME/config/$serveros.env
        echo "GSK_V3_CIPHER_SPECS=352F0A" >> $CANDLEHOME/config/$serveros.env
else
        touch $CANDLEHOME/config/$serveros.env
        echo "export KDC_FAMILIES=\"EPHEMERAL:Y HTTP_CONSOLE:N HTTP_SERVER:N HTTP:0 \${KDC_FAMILIES}\"" >> $CANDLEHOME/config/$serveros.env
        echo "GSK_PROTOCOL_SSLV2=OFF" >> $CANDLEHOME/config/$serveros.env
        echo "GSK_PROTOCOL_SSLV3=ON" >> $CANDLEHOME/config/$serveros.env
        echo "GSK_V3_CIPHER_SPECS=352F0A" >> $CANDLEHOME/config/$serveros.env
fi
# Adding the line to ini file to call the $CANDLEHOME/config/$serveros.env
echo "Adding $serveros.env to the $shortos.ini file"
echo ". \$CANDLEHOME\$/config/$serveros.env" >> $CANDLEHOME/config/$shortos.ini

# Adding itmcmd audit and secureMain
#Backup crontab and add audit and secureMain
crontab -l > /tmp/crontab-before-ITM-install
grep lockdown.sh /tmp/crontab-before-ITM-install > /dev/null 2>&1
if [[ $? != 0 ]]; then
	crontab -l > /tmp/crontab-l
	echo "# ITM6 Tivoli Clean Up old log files" >> /tmp/crontab-l
	echo "30 08 1 * * $CANDLEHOME/bin/itmcmd audit -h $CANDLEHOME -l both >> /tmp/ITM_logs_clean.err 2>&1" >> /tmp/crontab-l
	#echo "# Run SecureMain weekly" >> /tmp/crontab-l
	#echo "0 2 * * 1 $CANDLEHOME/bin/secureMain -h $CANDLEHOME -g tivadmn lock > /dev/null 2>&1" >> /tmp/crontab-l
	echo "# Run lockdown script weekly" >> /tmp/crontab-l
	echo "0 2 * * 1 $CANDLEHOME/smitools/scripts/lockdown.sh" >> /tmp/crontab-l
	echo "0 3 * * 1 find $CANDLEHOME -type f -perm -002 -print > $CANDLEHOME/smitools/tmp/ITM-world-writeable-files" >> /tmp/crontab-l
	crontab /tmp/crontab-l
	rm /tmp/crontab-l
fi

# Run SecureMain
#$CANDLEHOME/bin/secureMain -h $CANDLEHOME -g tivadmn lock > /dev/null 2>&1
#if (( $? != 0 )) ; then
#        echo "ERROR: SecureMain failed"
#        echo "Contact the Tivoli Administrator"
#        exit 1
#fi

# Run lockdown.sh  script and then
# copy lockdown.sh script to $CANDLEHOME/smitools/scripts
if [[ -f $PWD/lockdown.sh ]]; then
	chmod 755 $PWD/lockdown.sh
	$PWD/lockdown.sh > /tmp/lockdown.log 2>&1
	cp $PWD/lockdown.sh $CANDLEHOME/smitools/scripts
	if [[ $? != 0 ]]; then
		echo "Error: unable to copy to $CANDLEHOME/smitools/scripts/lockdown.sh"
		echo "Error: Exiting the Installation"
		exit 1
	fi
	chmod 755 $CANDLEHOME/smitools/scripts/lockdown.sh
else
	echo "Error: $PWD/lockdown.sh file is missing"
	echo "Error: Exiting the Installation"
	exit 1
fi

# Starting the agents
$CANDLEHOME/bin/itmcmd agent start $shortos
ps -ef | grep $osagent | grep -v grep > /dev/null 2>&1
if (( $? != 0 )) ; then
	echo "ERROR: Unix agent did NOT start"
        echo "Contact the Tivoli Administrator"
	exit 1
fi

echo "Installation is complete"
echo "Contact the Tivoli Administrator to check if the server connected to the"
echo "Tivoli Monitoring Server"
