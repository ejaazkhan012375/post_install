
# Author: Ziqiang Guan
# Date Created: 03/09/2016
# Date Changed: 31/12/2018 Roy Oldaker to account for zLinux IMS Connect thrashing of thousands of connections per minute.
# Date Changed: 06/02/2019 Stephanie Spinetti to fix backup file behavior
# Date Changed: 17/05/2019 Roy Oldaker increased buffer sizes for large transfers - and no TW options
# Date Changed: 20/05/2019 Roy increased message_burst, buffer sizes and removed bash shell (the "diff -wq" commands commented out")
#               20/06/2019 Roy turned off tcp_autocorking for MongoDB replication (Nagle) and increased message_burst to 60
#               05/05/2021 Roy added tcp_low_latency = 1 to turn off tcp delays
# Anthem Inc. APDS SSPE Linux TCP/IP Performance Tuning for RedHat Enterprise Linux 6.x

#############################################################################################
# Instructions
#
# 1. Review Variables and Settings sections to make sure conf files paths and things are set
#	 correctly for the specific server. These settings should be the same across most servers
#	 with the exception of active NIC interface,
# 2. Run "sudo bash path/to/redhat_linux_persistent_tuning_6.x.sh" to execute the script,
  
# Note:
#	- If script is throwing "/bin/bash^M: bad interpreter: No such file or directory" error,
#	  please run "%s/^M//g" command in vi to get rid of the ^M. To get "^m" in the command,
#	  press ctrl+v then ctrl+m,
#
#
#############################################################################################

#############################################################################################
# Variables and Settings
#

# Location of sysctl.conf and limits.conf
readonly CONF_FILE="/etc/sysctl.conf"
readonly CONF_FILE_BACKUP="/etc/sysctl.conf.backup"
# readonly LIMITS_FILE="/etc/security/limits.conf"
# readonly LIMITS_FILE_BACKUP="/etc/security/limits.conf.backup"

# Active NIC interface
# Run ifconfig -a to identify
# readonly NIC=eth0

# Set whether to run the tuning portion of the script, in case someone only wants to know
# whether the tuning is put in,
# set to 0 to implement the tunings,
# set to 1 to get readouts of current parameters only,
readonly TUNING=0

#
#############################################################################################

#############################################################################################
# SSPE recommended values
#

# Ulimit -n 8192 for web, app, and MQ servers
# higher value for database servers
# readonly ULIMIT=8192

# LINUX 6 or higher
readonly TCP_MAX_ORPHANS=1024
readonly TCP_ORPHAN_RETRIES=2
readonly TCP_TIMESTAMPS=2
readonly TCP_KEEPALIVE_INTVL=15
readonly TCP_KEEPALIVE_PROBES=5
# 20 June 2019 Roy changed from 360 to 120 to match MongoDB requirement
readonly TCP_KEEPALIVE_TIME=120
readonly TCP_SYNCOOKIES=0
readonly TCP_RETRIES1=15
readonly TCP_REORDERING=15
readonly TCP_FIN_TIMEOUT=30
#readonly TCP_RMEM='16384 87380 1024000'
#readonly TCP_RMEM='65536 87380 6291456'
#readonly TCP_WMEM='16384 65536 1024000'
#7 Mar 2019 Roy Oldaker increased for larger Oracle SDU value of 128 KB
readonly TCP_RMEM='16384 131072 6291456'
readonly TCP_WMEM='16384 131072 1024000'
readonly TCP_MEM='8388608 8388608 8388608'
#readonly TCP_MODERATE_RCVBUF=0
readonly TCP_MODERATE_RCVBUF=1 # 20 May 2021 - 1 = better auto-tuning of the rcv buffers - maybe the send buffers also 
readonly GC_ELASTICITY=8
readonly MIN_PMTU=1448
# Roy - this needs tested before it's added but it is probably good to have - I just haven't seen related errors - 20 June 2019
#readonly TCP_MTU_PROBING=2
readonly TCP_BASE_MSS=1448
readonly TCP_SLOW_START_AFTER_IDLE=0
# TCP_TW options cause problems with NAT servers
#readonly TCP_TW_RECYCLE=5
#readonly TCP_TW_REUSE=5
readonly NETDEV_MAX_BACKLOG=1000
readonly SOMAXCONN=1000
# number of packets handled in a small time period - increase this as net gets faster and host gets busier
readonly MESSAGE_BURST=60
readonly RMEM_MAX=8388608
readonly WMEM_MAX=8388608
readonly OPTMEM_MAX=65536
readonly TCP_AUTOCORKING=0
readonly TCP_LOW_LATENCY=1  # turn off delay acks
#
#
#############################################################################################

#############################################################################################
# Reading current values
#

# Reading current settings
tcp_max_orphans=$(cat /proc/sys/net/ipv4/tcp_max_orphans)
echo "tcp_max_orphans current set to $tcp_max_orphans, recommended value is $TCP_MAX_ORPHANS"

tcp_orphan_retries=$(cat /proc/sys/net/ipv4/tcp_orphan_retries)
echo "tcp_orphan_retries current set to $tcp_orphan_retries, recommended value is $TCP_ORPHAN_RETRIES"

tcp_timestamps=$(cat /proc/sys/net/ipv4/tcp_timestamps)
echo "tcp_timestamps current set to $tcp_timestamps, recommended value is $TCP_TIMESTAMPS"

tcp_keepalive_intvl=$(cat /proc/sys/net/ipv4/tcp_keepalive_intvl)
echo "tcp_keepalive_intvl current set to $tcp_keepalive_intvl, recommended value is $TCP_KEEPALIVE_INTVL"

tcp_keepalive_probes=$(cat /proc/sys/net/ipv4/tcp_keepalive_probes)
echo "tcp_keepalive_probes current set to $tcp_keepalive_probes, recommended value is $TCP_KEEPALIVE_PROBES"

tcp_keepalive_time=$(cat /proc/sys/net/ipv4/tcp_keepalive_time)
echo "tcp_keepalive_time current set to $tcp_keepalive_time, recommended value is $TCP_KEEPALIVE_TIME"

tcp_syncookies=$(cat /proc/sys/net/ipv4/tcp_syncookies)
echo "tcp_syncookies current set to $tcp_syncookies, recommended value is $TCP_SYNCOOKIES"

tcp_retries1=$(cat /proc/sys/net/ipv4/tcp_retries1)
echo "tcp_retries1 current set to $tcp_retries1, recommended value is $TCP_RETRIES1"

tcp_reordering=$(cat /proc/sys/net/ipv4/tcp_reordering)
echo "tcp_reordering current set to $tcp_reordering, recommended value is $TCP_REORDERING"

tcp_fin_timeout=$(cat /proc/sys/net/ipv4/tcp_fin_timeout)
echo "tcp_fin_timeout current set to $tcp_fin_timeout, recommended value is $TCP_FIN_TIMEOUT"

tcp_rmem=$(cat /proc/sys/net/ipv4/tcp_rmem)
echo "tcp_rmem current set to $tcp_rmem, recommended value is $TCP_RMEM"

tcp_wmem=$(cat /proc/sys/net/ipv4/tcp_wmem)
echo "tcp_wmem current set to $tcp_wmem, recommended value is $TCP_WMEM"

tcp_mem=$(cat /proc/sys/net/ipv4/tcp_mem)
echo "tcp_mem current set to $tcp_mem, recommended value is $TCP_MEM"

tcp_moderate_rcvbuf=$(cat /proc/sys/net/ipv4/tcp_moderate_rcvbuf)
echo "tcp_moderate_rcvbuf current set to $tcp_moderate_rcvbuf, recommended value is $TCP_MODERATE_RCVBUF"

gc_elasticity=$(cat /proc/sys/net/ipv4/route/gc_elasticity)
echo "gc_elasticity current set to $gc_elasticity, recommended value is $GC_ELASTICITY"

min_pmtu=$(cat /proc/sys/net/ipv4/route/min_pmtu)
echo "min_pmtu current set to $min_pmtu, recommended value is $MIN_PMTU"

tcp_base_mss=$(cat /proc/sys/net/ipv4/tcp_base_mss)
echo "tcp_base_mss current set to $tcp_base_mss, recommended value is $TCP_BASE_MSS"

tcp_slow_start_after_idle=$(cat /proc/sys/net/ipv4/tcp_slow_start_after_idle)
echo "tcp_slow_start_after_idle current set to $tcp_slow_start_after_idle, recommended value is $TCP_SLOW_START_AFTER_IDLE"

# Roy added autocorking - a Nagle relative
tcp_autocorking=$(cat /proc/sys/net/ipv4/tcp_autocorking)
echo "tcp_autocorking current set to $tcp_autocorking, recommended value is $TCP_AUTOCORKING"

# 31 Dec 2018 Roy Oldaker added changes for zlinux IMS Connect sockets - not pooled - live for 30 ms 
#tcp_tw_recycle=$(cat /proc/sys/net/ipv4/tcp_tw_recycle)
#echo "tcp_tw_recycle current set to $tcp_tw_recycle, recommended value is $TCP_TW_RECYCLE"
# 31 Dec 2018 Roy Oldaker added changes for zlinux IMS Connect sockets - not pooled - live for 30 ms 
#tcp_tw_reuse=$(cat /proc/sys/net/ipv4/tcp_tw_reuse)
#echo "tcp_tw_reuse current set to $tcp_tw_reuse, recommended value is $TCP_TW_REUSE"


netdev_max_backlog=$(cat /proc/sys/net/core/netdev_max_backlog)
echo "netdev_max_backlog current set to $netdev_max_backlog, recommended value is $NETDEV_MAX_BACKLOG"

somaxconn=$(cat /proc/sys/net/core/somaxconn)
echo "somaxconn current set to $somaxconn, recommended value is $SOMAXCONN"

message_burst=$(cat /proc/sys/net/core/message_burst)
echo "message_burst current set to $message_burst, recommended value is $MESSAGE_BURST"

rmem_max=$(cat /proc/sys/net/core/rmem_max)
echo "rmem_max current set to $rmem_max, recommended value is $RMEM_MAX"

wmem_max=$(cat /proc/sys/net/core/wmem_max)
echo "wmem_max current set to $wmem_max, recommended value is $WMEM_MAX"

optmem_max=$(cat /proc/sys/net/core/optmem_max)
echo "optmem_max current set to $optmem_max, recommended value is $OPTMEM_MAX"

tcp_low_latency=$(cat /proc/sys/net/ipv4/tcp_low_latency)
echo "tcp_low_latency current set to $tcp_low_latency, recommended value is $TCP_LOW_LATENCY"

#############################################################################################
# Implementing tuning
#

if [ "$TUNING" -eq "0" ]; then

# Backing up original file
# create a backup file

# CONF_FILE
echo "Creating a backup file for sysctl.conf"
cp "$CONF_FILE" "$CONF_FILE_BACKUP"


# Today's date
readonly TODAY=$(date +'%m/%d/%Y')

echo -e "\n\n\n#######################################################" >> "$CONF_FILE"
echo "# SSPE Linux TCP/IP Performance Tuning | $TODAY" >> "$CONF_FILE"
echo "#######################################################" >> "$CONF_FILE"

if [ "$tcp_max_orphans" -ne "$TCP_MAX_ORPHANS" ]; then
  echo "Setting tcp_max_orphans to $TCP_MAX_ORPHANS"
  echo -e "\n# Maximum number of TCP sockets not attached to any user file handle" >> "$CONF_FILE"
  echo "net.ipv4.tcp_max_orphans=$TCP_MAX_ORPHANS" >> "$CONF_FILE"
else
  echo "tcp_max_orphans already set to $TCP_MAX_ORPHANS, skipping..."
fi

if [ "$tcp_orphan_retries" -ne "$TCP_ORPHAN_RETRIES" ]; then
  echo "Setting tcp_orphan_retries to $TCP_ORPHAN_RETRIES"
  echo -e "\n# How many times to retry before killing a TCP connection" >> "$CONF_FILE"
  echo "net.ipv4.tcp_orphan_retries=$TCP_ORPHAN_RETRIES" >> "$CONF_FILE"
else
  echo "tcp_orphan_retries already set to $TCP_ORPHAN_RETRIES, skipping..."
fi

if [ "$tcp_timestamps" -ne "$TCP_TIMESTAMPS" ]; then
  echo "Setting tcp_timestamps to $TCP_TIMESTAMPS"
  echo -e "\n# Enables timestamps to protect against wrapping sequence number" >> "$CONF_FILE"
  echo "net.ipv4.tcp_timestamps=$TCP_TIMESTAMPS" >> "$CONF_FILE"
else
  echo "tcp_orphan_retries already set to $TCP_TIMESTAMPS, skipping..."
fi

if [ "$tcp_keepalive_intvl" -ne "$TCP_KEEPALIVE_INTVL" ]; then
  echo "Setting tcp_keepalive_intvl to $TCP_KEEPALIVE_INTVL"
  echo -e "\n# Interval between keepalive probes" >> "$CONF_FILE"
  echo "net.ipv4.tcp_keepalive_intvl=$TCP_KEEPALIVE_INTVL" >> "$CONF_FILE"
else
  echo "tcp_keepalive_intvl already set to $TCP_KEEPALIVE_INTVL, skipping..."
fi

if [ "$tcp_keepalive_probes" -ne "$TCP_KEEPALIVE_PROBES" ]; then
  echo "Setting tcp_keepalive_probes to $TCP_KEEPALIVE_PROBES"
  echo -e "\n# Number of unacknowledged probes to send before considering a connection dead" >> "$CONF_FILE"
  echo "net.ipv4.tcp_keepalive_probes=$TCP_KEEPALIVE_PROBES" >> "$CONF_FILE"
else
  echo "tcp_keepalive_probes already set to $TCP_KEEPALIVE_PROBES, skipping..."
fi

if [ "$tcp_keepalive_time" -ne "$TCP_KEEPALIVE_TIME" ]; then
  echo "Setting tcp_keepalive_time to $TCP_KEEPALIVE_TIME"
  echo -e "\n# Interval in seconds between the last data packet sent and the first keepalive probe" >> "$CONF_FILE"
  echo "net.ipv4.tcp_keepalive_time=$TCP_KEEPALIVE_TIME" >> "$CONF_FILE"
else
  echo "tcp_keepalive_time already set to $TCP_KEEPALIVE_TIME, skipping..."
fi

if [ "$tcp_syncookies" -ne "$TCP_SYNCOOKIES" ]; then
  echo "Setting tcp_syncookies to $TCP_SYNCOOKIES"
  echo -e "\n# Used to thwart DoS attack, not necessary for non-external facing servers" >> "$CONF_FILE"
  echo "net.ipv4.tcp_syncookies=$TCP_SYNCOOKIES" >> "$CONF_FILE"
else
  echo "tcp_syncookies already set to $TCP_SYNCOOKIES, skipping..."
fi

if [ "$tcp_retries1" -lt "$TCP_RETRIES1" ]; then  # allow greater values
  echo "Setting tcp_retries1 to $TCP_RETRIES1"
  echo -e "\n# How many times to retry for TCP connection before deciding there is an issue" >> "$CONF_FILE"
  echo "net.ipv4.tcp_retries1=$TCP_RETRIES1" >> "$CONF_FILE"
else
  echo "tcp_retries1 already to $TCP_RETRIES1, skipping..."
fi

if [ "$tcp_reordering" -lt "$TCP_REORDERING" ]; then  # allow greater values
  echo "Setting tcp_reordering to $TCP_REORDERING"
  echo -e "\n# How much a TCP packet may be reordered without assuming that the packet was lost" >> "$CONF_FILE"
  echo "net.ipv4.tcp_reordering=$TCP_REORDERING" >> "$CONF_FILE"
else
  echo "tcp_reordering set to $TCP_REORDERING, skipping..."
fi

if [ "$tcp_fin_timeout" -ne "$TCP_FIN_TIMEOUT" ]; then
  echo "Setting tcp_fin_timeout to $TCP_FIN_TIMEOUT"
  echo -e "\n# How long in seconds to keep sockets in FIN-WAIT-2 state." >> "$CONF_FILE"
  echo "net.ipv4.tcp_fin_timeout=$TCP_FIN_TIMEOUT" >> "$CONF_FILE"
else
  echo "tcp_fin_timeout already set to $TCP_FIN_TIMEOUT, skipping..."
fi

#diff -wq <(echo "$tcp_rmem") <(echo "$TCP_RMEM")
#if [[ "$?" == "0" ]]; then
#  echo "tcp_rmem already set to $TCP_RMEM, skipping..."
#else
  echo "Setting tcp_rmem to $TCP_RMEM"
  echo -e "\n# Size of receive buffer in bytes for each socket" >> "$CONF_FILE"
  echo "net.ipv4.tcp_rmem=$TCP_RMEM" >> "$CONF_FILE"
#fi

#diff -wq <(echo "$tcp_wmem") <(echo "$TCP_WMEM")
#if [[ "$?" == "0" ]]; then
#  echo "tcp_wmem already set to $TCP_WMEM, skipping..."
#else
  echo "Setting tcp_wmem to $TCP_WMEM"
  echo -e "\n# Size of send buffer in bytes for each socket" >> "$CONF_FILE"
  echo "net.ipv4.tcp_wmem=$TCP_WMEM" >> "$CONF_FILE"
#fi

#diff -wq <(echo "$tcp_mem") <(echo "$TCP_MEM")
#if [[ "$?" == "0" ]]; then
#  echo "tcp_mem already set to $TCP_MEM, skipping..."
#else
  echo "Setting tcp_mem to $TCP_MEM"
  echo -e "\n# Size of total buffer in bytes for sockets" >> "$CONF_FILE"
  echo "net.ipv4.tcp_mem=$TCP_MEM" >> "$CONF_FILE"
#fi

if [ "$tcp_moderate_rcvbuf" -ne "$TCP_MODERATE_RCVBUF" ]; then
  echo "Setting tcp_moderate_rcvbuf to $TCP_MODERATE_RCVBUF"
  echo -e "\n# Turn on auto buffer size tuning - improve ramp up to big buffers when needed for large WAN transfers (send and rcv)" >> "$CONF_FILE"
  echo "net.ipv4.tcp_moderate_rcvbuf=$TCP_MODERATE_RCVBUF" >> "$CONF_FILE"
else
  echo "tcp_moderate_rcvbuf already set to $TCP_MODERATE_RCVBUF, skipping..."
fi

if [ "$gc_elasticity" -ne "$GC_ELASTICITY" ]; then
  echo "Setting gc_elasticity to $GC_ELASTICITY"
  echo -e "\n# Value to control the frequency and behavior of the garbage collection algorithm for the routing cache" >> "$CONF_FILE"
  echo "net.ipv4.route.gc_elasticity=$GC_ELASTICITY" >> "$CONF_FILE"
else
  echo "gc_elasticity already set to $GC_ELASTICITY, skipping..."
fi

if [ "$min_pmtu" -ne "$MIN_PMTU" ]; then
  echo "Setting min_pmtu to $MIN_PMTU"
  echo -e "\n# Minimum size for MTU (Maximum Transmission Unit)" >> "$CONF_FILE"
  echo "net.ipv4.route.min_pmtu=$MIN_PMTU" >> "$CONF_FILE"
else
  echo "min_pmtu already set to $MIN_PMTU, skipping..."
fi

if [ "$tcp_base_mss" -ne "$TCP_BASE_MSS" ]; then
  echo "Setting tcp_base_mss to $TCP_BASE_MSS"
  echo -e "\n# Initial MSS used by the connection MTU probing is enabled" >> "$CONF_FILE"
  echo "net.ipv4.tcp_base_mss=$TCP_BASE_MSS" >> "$CONF_FILE"
else
  echo "tcp_base_mss already set to $TCP_BASE_MSS, skipping..."
fi

if [ "$tcp_slow_start_after_idle" -ne "$TCP_SLOW_START_AFTER_IDLE" ]; then
  echo "Setting tcp_slow_start_after_idle to $TCP_SLOW_START_AFTER_IDLE"
  echo -e "\n# Provides slow start behavior after a connection has been idle" >> "$CONF_FILE"
  echo "net.ipv4.tcp_slow_start_after_idle=$TCP_SLOW_START_AFTER_IDLE" >> "$CONF_FILE"
else
  echo "tcp_slow_start_after_idle already set to $TCP_SLOW_START_AFTER_IDLE, skipping..."
fi
# Roy added tcp_autocorking 20 June 2019
if [ "$tcp_autocorking" -ne "$TCP_AUTOCORKING" ]; then
  echo "Setting tcp_autocorking to $TCP_AUTOCORKING"
  echo -e "\n# Disable Nagle packet coallescing behavior" >> "$CONF_FILE"
  echo "net.ipv4.tcp_autocorking=$TCP_AUTOCORKING" >> "$CONF_FILE"
else
  echo "tcp_autocorking already set to $TCP_AUTOCORKING or it is non-existent, skipping..."
fi
# Roy added tcp_low_latency 5 May 2021 - remove Delay ACKs
if [ "$tcp_low_latency" -ne "$TCP_LOW_LATENCY" ]; then
  echo "Setting tcp_low_latency to $TCP_LOW_LATENCY"
  echo -e "\n# Disable Delay ACKs behavior" >> "$CONF_FILE"
  echo "net.ipv4.tcp_low_latency=$TCP_LOW_LATENCY" >> "$CONF_FILE"
else
  echo "tcp_low_latency already set to $TCP_LOW_LATENCY, skipping..."
fi

#if [ "$tcp_tw_recycle" -ne "$TCP_TW_RECYCLE" ]; then
#  echo "Setting tcp_tw_recycle to $TCP_TW_RECYCLE"
#  echo -e "\n# Causes packet drops with TCP_TIMESTAMPS when interacting with clients behind NAT" >> "$CONF_FILE"
#  echo "net.ipv4.tcp_tw_recycle=$TCP_TW_RECYCLE" >> "$CONF_FILE"
#else
#  echo "tcp_tw_recycle already set to $TCP_TW_RECYCLE, skipping..."
#fi
# 31 Dec 2018 Roy Oldaker added changes for zlinux IMS Connect sockets - not pooled - live for 30 ms 
#if [ "$tcp_tw_reuse" -ne "$TCP_TW_REUSE" ]; then
#  echo "Setting tcp_tw_reuse to $TCP_TW_REUSE"
#  echo -e "\n# Causes packet drops with TCP_TIMESTAMPS when interacting with clients behind NAT" >> "$CONF_FILE"
#  echo "net.ipv4.tcp_tw_reuse=$TCP_TW_REUSE" >> "$CONF_FILE"
#else
#  echo "tcp_tw_reuse already set to $TCP_TW_REUSE, skipping..."
#fi


if [ "$netdev_max_backlog" -ne "$NETDEV_MAX_BACKLOG" ]; then
  echo "Setting netdev_max_backlog to $NETDEV_MAX_BACKLOG"
  echo -e "\n# Size of receiving queue." >> "$CONF_FILE"
  echo "net.core.netdev_max_backlog=$NETDEV_MAX_BACKLOG" >> "$CONF_FILE"
else
  echo "netdev_max_backlog already set to $NETDEV_MAX_BACKLOG, skipping..."
fi

if [ "$somaxconn" -ne "$SOMAXCONN" ]; then
  echo "Setting somaxconn to $SOMAXCONN"
  echo -e "\n# Size of the listening queue for connection requests" >> "$CONF_FILE"
  echo "net.core.somaxconn=$SOMAXCONN" >> "$CONF_FILE"
else
  echo "somaxconn already set to $SOMAXCONN, skipping..."
fi

if [ "$message_burst" -ne "$MESSAGE_BURST" ]; then
  echo "Setting message_burst to $MESSAGE_BURST"
  echo -e "\n# Limits the rate at which packets gave be processed from the backlog" >> "$CONF_FILE"
  echo "net.core.message_burst=$MESSAGE_BURST" >> "$CONF_FILE"
else
  echo "message_burst already set to $MESSAGE_BURST, skipping..."
fi

#diff -wq <(echo "$rmem_max") <(echo "$RMEM_MAX")
#if [[ "$?" == "0" ]]; then
#  echo "rmem_max already set to $RMEM_MAX, skipping..."
#else
  echo "Setting rmem_max to $RMEM_MAX"
  echo -e "\n# Size of receive buffer in bytes for sockets" >> "$CONF_FILE"
  echo "net.core.rmem_max=$RMEM_MAX" >> "$CONF_FILE"
#fi

#diff -wq <(echo "$wmem_max") <(echo "$WMEM_MAX")
#if [[ "$?" == "0" ]]; then
#  echo "wmem_max already set to $WMEM_MAX, skipping..."
#else
  echo "Setting wmem_max to $WMEM_MAX"
  echo -e "\n# Size of send buffer in bytes for sockets" >> "$CONF_FILE"
  echo "net.core.wmem_max=$WMEM_MAX" >> "$CONF_FILE"
#fi

#diff -wq <(echo "$optmem_max") <(echo "$OPTMEM_MAX")
#if [[ "$?" == "0" ]]; then
#  echo "optmem_max already set to $OPTMEM_MAX, skipping..."
#else
  echo "Setting optmem_max to $OPTMEM_MAX"
  echo -e "\n# Size of control buffer in bytes for sockets" >> "$CONF_FILE"
  echo "net.core.optmem_max=$OPTMEM_MAX" >> "$CONF_FILE"
#fi


echo -e "\n#######################################################" >> "$CONF_FILE"
echo "# END SSPE Linux TCP/IP Performance Tuning | $TODAY" >> "$CONF_FILE"
echo "#######################################################" >> "$CONF_FILE"

echo "Changes have been written to sysctl.conf file"
echo "Running 'sysctl -p' to refresh config file"
sysctl -p

echo "Changes implemented!"
echo "***programs need to be restarted in order for network changes to take effect***"

else
  echo "Tunings not implemented. To implement the tunings, change the TUNING variable in Variables and Settings to 0."
fi

#
#
#############################################################################################

#exit 0
