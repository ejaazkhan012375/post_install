#! /bin/ksh

############################################################################
##                                                                        ##
##    This program is property of IBM! It is intended for use on          ##
##    IBM supported machines only. All use of this program must be        ##
##    approved by an IBM UNIX Support person. All use of this             ##
##    program, copying of this program, or sharing of this program        ##
##    is forbidden except with the permission of an IBM UNIX support      ##
##    person.                                                             ##
##                                                                        ##
############################################################################
## $Id: EP2_Driver_V2.0.8.sh, v 2.0.8 17/11/2013 10:00:00  debaspal Exp $ ##
############################################################################
##                                                                         #
## EP2_Driver_V1.0.sh - Created 11/21/2012 Debasmita (debaspal@in.ibm.com) #
##                                                                         #
##                                                                         #
##    Description: This script drives the collector and analyzer scripts   #
##                sequentially.                                            #
##                The driver script serves as the control point for        #
##                - handling flags and arguments for global execution,     # 
##                collector and driver.                                    #
##                - handling kill signals and provide for cleanup if       #
##                cancelled.                                               #
##                - the identification of local filesystems to inspect.    #
##                - the sequential execution of the 2 components.          #
##                The driver script accepts user command line input to     #
##                control EP2 execution and options. By default, it        #
##                identifies all locally-mounted filesystems and all       #
##                exported filesystems and then discards non-local         #
##                filesystems and read-only filesystems (eg CDROMs), adds  #
##                any filesystems with always_check entries in the override#
##                file even if non-local or read-only. Finally it discards #
##                any filesystems with never_check entries in the override #
##                file. The identified final list of file systems are      #
##                passed to collector one by one. It performs a check to   #
##                ensure adequate space is available in the output         #
##                directory before calling the collector.It calls the      #
##                Analyzer script with the consolidated output of collector#
##                For any exported filesystems identified,it places the    #
##                starting directory names passed to the analyzer into a   #
##                separate work file.                                      #
##                                                                         #
############################################################################
##                                                                         #
##  CHANGE LOG:                                                            #
##  1.00   debaspal    Initial Release                                     #
##  1.1    debaspal    Fixed problem with code "sed" for OS like AIX       #
##  1.2    debaspal    Changed the wordings in show_use function           #
##  1.3    debaspal    Fixed issue with export for Solaris. Removed $.     #
##  1.4    debaspal    New flag "r" to disable filtering of collector and  #
##                     to enable safe record check in collector added.     #
##                     Basename error is resolved,linked /bin/basename with#
##                     /usr/bin/basename. Handled grep error when file is  #
##                     missing.                                            #
##                     Modified code to read compression program from      #
##                     config file parameter "EP2_COMPRESSION_PGM"         #
##                     Handled removal of temporary analyzer output file.  #
##                     Added mail content ,for a file system without viola-#
##                     tion, "No deviations were found" and for the file   #
##                     system with violation, the path of deviation report #
##                     is mailed.                                          #
## 1.5    debaspal     Fixed bug for empty collector output. It was exiting#
##                     previously for same condition, but now it is continu#
##                     -ing for next filesystem if any.                    #
##
## 1.6    debaspal     Introduced new config parameter "EP2_SKIP_CSVZIP" and#
##                     exported.                                           #
##                     Empty collector output indicates clean file system. #
##                     Added this message to logfile and debug statement.  #
##                     Capturing OS level information in debug mode.       #
##                     Capturing ls -al of present directory in debug mode.#
##                     If collector/analyzer/estimator script or config file#
##                     does not exist, driver script aborts.               #
##                     Hardcoding of Config file is removed. It will detect#
##                     the latest version from current directory.          #
##                                                                         #
## 1.7    debaspal     Enhancement to email notification : modified subject#
##                     line with short hostname, filesystem, owner of the  #
##                     file system (if not root), with or without violation#
##                     information.                                        #
##                     Fixed issue with root "/" file system parsing.      #
##                     Fixed issue with start time of prime time is greater#
##                     than the end time, logic fails (both for Analyzer   #
##                     and collector).                                     #
##                     EP2_NICEVALUE_COLLECTOR_ANALYZER can take any value #
##                     as specified in config file.                        #
##                     On Solaris, default temporary diectory is changed to#
##                     /var/tmp.                                           #
##                     Fixed issue of picking up "SAMPLE" override, exclusi#
##                     -on file.   #
##                     If any file size is zero, then it is skipped for    #
##                     scanning.                                           #
##                                                                         #
## 1.8    debaspal     Removed many ugly extra \n on the log entries coming#
##                     on many LINUX systems.                              #
##                     Changes are done to set locale related to C as per  #
##                     suggestion.                                         #
##                     In the override files, if filesystems are excluded  #
##                     by using wildcard char, then driver suppports that. #
##                     These filesystems should be spcified without the    #
##                     initial "/", like to match /tmp and /tmpsys entry   #
##                     should be "never_check tmp" in the override files.  #
##                     Removed hardcoded collector and analyzer names.     #
##                     EP2_NICEVALUE_COLLECTOR_ANALYZER value is restricted#
##                     to -19 to 20.                                       #
##                                                                         #
##  2.0 debaspal    EP2_NICEVALUE_COLLECTOR_ANALYZER value can be any value#
##                     between -20 to 19 for AIX, and for other OS the     #
##                     value is restricted -19 to 20.                      #
##                     Fixed the issue of wrong order of command on Soaris #
##                     for detecting final file systems.                   #
##                     Logic is added to detect NAS, ISCSI device on server#
##                     and skip the associated mounted filesystems from    #
##                     scanning.                                           #
##                     Fixed issue IN3871901: ZFS file systems are included#
##                     for scanning.                                       #
##                     Issue IN3854641 resolved; the problem of logfile    #
##                     being overwritten on AIX for clean file systems is  #
##                     resolved.                                           #
##                     Fixed issue IN3808854: Filesystems name containing  #
##                     "nfs" in them were skipped previously, error is     #
##                     rectified.                                          #
##                     Code changes are made to set the current directory  #
##                     as the directory containing the driver and lsmode.pm#
##                     before calling the collector.                       #
##                     All errors and standard output are redirected to the#
##                     existing log.                                       #
##                     Resolved issue IN3875839 related to error           #
##                     "process_filesystems[87]: -: more tokens expected.  #
##                     Added code to check for perl modules (hires.pm,     #
##                     fcntl.pm,uri.pm) in driver before collector/analyzer#
##                     execution to get early warning of missing modules.  #
##                     Code added for the following logic:                 #
##                     if vmstat 30 1 retrunc CPU_IDEL_USAGE as 0 ,then run#
##                     vmstat 60 2 command to get usage in last one minute.#
##                     In few system it was observed that vmstat 30 1      #
##                     always returns 0.                                   #
##                                                                         #
##  2.0.1  debaspal    No functional changes, updated version number to    #
##                     maintain consistency in packaging. The collector and#
##                     the analyzer version is increased.                  #
##                                                                         #
##  2.0.2 debaspal     The exit messages are redirected to both console and#
##                     log file.The parameter "EP2_EXCLUDED_HOME_DIRS" is  #
##                     added to read from configuration file and exported. #
##                                                                         #
##  2.0.3 debaspal     Fix done for zfs file system identification code.   #
##                     If analyzer returns code other than 0, 2,3 and 4, it#
##                     exits with logging error on console and log file.   #
##                     Commented out code that exists if Time::HiRes module#
##                     is not present. Code modified to only log the issue #
##                                                                         #
##  2.0.4 aparmala     URI::Escape is no longer required, commenting out   # 
##                     check for URI module.                               #
##                     Modified output messages to make clear the unit that#
##                     the space estimating is being done is MB.           #
##                                                                         #
##  2.0.5 aparmala     WARNING message is issued instead of ERROR message  #
##                     if HiRes module is unavailable                      #
##                                                                         #
##  2.0.6 aparmala     No changes made to driver code. Version of driver   #
##                     has to be changed as there is new analyzer version  #
##                     (2.0.6).                                            #
##                                                                         #
##  2.0.7 aparmala     No changes made to driver code. Version of driver   #
##                     has to be changed as there is new analyzer version  #
##                     (2.0.7).                                            #
##                                                                         #
##  2.0.8 debaspal     GPFS filesystem is not scanned by default, need to  #
##                     add as always_check entry for scanning in the       #
##                     ep2.overrides.local file.                           #
##                     Added extra output to console related to collector  #
##                     and analyzer run and sleep related information.     #
##                     Downgraded missing Times::Hires modules to Warning. #
##                     It is only shown in debug mode.                     #
##                     With "l" flag Home/Processes checks are skipped.    #
############################################################################
#set -x
trap 'DeleteTempFiles' 0
trap 'trap_interrupt' 1 2 3 6 9 15 

function trap_interrupt {
    if [[ -s $TMP_COL_LOG ]]; then
        cat $TMP_COL_LOG >> $SCRIPTLOG 2>&1
    fi
    if [[ -s $ANALYZER_LOGDIR/EP2_Analyzer_*.LOG* ]]; then
        cat $ANALYZER_LOGDIR/EP2_Analyzer_*.LOG* >> $SCRIPTLOG 2>&1
    fi
    DeleteTempFiles
    rm -rf $ANALYZER_LOGDIR 2>> $SCRIPTLOG 
    echo "`date +'%D_%T'` : Interrupt on driver" | tee -a $SCRIPTLOG
    cat $SCRIPTLOG >> $FINAL_SCRIPTLOG  2>&1
    rm -f $SCRIPTLOG
    exit 1
}

function show_use
{
    echo "Usage : $pn [-cdhlimrpuVjvxa:b:g:o:t:w:]"
    echo "        V                                      Display version."
    echo "        h                                      Display usage screen."
    echo "        d                                      Initiate Debugging messages"
    echo "        c                                      script would display violations,messages related to in-scope customer id's"
    echo "        l                                      To Skip the Home directory and Processes Checking"
    echo "        v                                      VERBOSE mode. Adds EXCEPTION messages as well as VIOLATION/WARNING messages to output CSV file"
    echo "        x                                      EXTRA VERBOSE mode. Adds NOTE/PASS messages to EXCEPTION/VIOLATION/WARNING to output CSV file"
    echo "        m                                      Turns on MERGEMODE.  Removes printing of file info at end of CSV to allow mergining of CSV files"
    echo "        u                                      When specified, all ids are considered as IBMids and these IDs are used for all the checks"
    echo "        g <GECOS TYPE>                         GECOS type. URT (default), ITIM, ORIG (IBM Original gecos layout.  All other GECOS types"
    echo "                                               will process all userids in $PASSWD_FILE"
    echo "        i                                      When specified, Script would display violation, messages related to IBMIDs only"
    echo "        j                                      Perform Original Checks"
    echo "        a <GECOS string for IBM id's>  	 Alternate gecos string for IBM id's"
    echo "        o <output file Main Directory>         Override default output Main Directory name '$OUTDIR'"
    echo "        p                                      When specified, disable the insecure path check for executables." 
    echo "        t <# in meg>	        		 Override the amount of space required for output"
    echo "        b <number of inodes in batch>          A pause after a configurable number of inodes have been gathered (default value 200 inodes, overridden using the batch size flag, (-b) with count)"
    echo "        w <collector sleep_in_usec>            wait time between batches of inodes (# in microseconds)"
    echo "        r                                      To disable filtering of collector and it will result in stat info printed out for all inodes."
	echo ""
    show_version
}

function show_version
{
    echo "$pn: Revision: $version"
    echo "$collectorname: Revision: $collectorversion"
    echo "$analyzername: Revision: $analyzerversion" 
}

###################################################################################
# which_OS : Determines the OS and version/level of the server.  If the server is #
#	     Linux, the proper Linux Distribution is also determined.             #
# 			SuSE Linux Standard Server => SLSS                        #
# 			SuSE Linux Enterprise Server => SLES                      #
#	RETURNS :                                                                 #
#		SunOS: ${OS1} ${REV}(${ARCH} `uname -v`)                          #
#		AIX  : ${OS1} `oslevel` (`oslevel -r`)                            #
#		HP-UX: ${OS1} ${REV} `/bin/model`                                 #
#		Linux: ${OS1} ${DIST} ${REV}(${PSUEDONAME} ${KERNEL} ${MACH})     #
###################################################################################
function which_OS {

        OS1=`uname -s`
        REV=`uname -r`
        MACH=`uname -m`

        GetVersionFromFile()
        {
                VERSION=`cat $1 | tr "\n" ' ' | sed s/.*VERSION.*=\ // `
        }

        if [ "${OS1}" = "SunOS" ] ; then
                OS1=Solaris
                ARCH=`uname -p`
                OSSTR="${OS1} ${REV}(${ARCH} `uname -v`)"
        elif [ "${OS1}" = "AIX" ] ; then
                OSSTR="${OS1} `oslevel` (`oslevel -r`)"
        elif [ "${OS1}" = "HP-UX" ] ; then
                OSSTR="${OS1} ${REV} `/bin/model`"
        elif [ "${OS1}" = "Linux" ] ; then
                KERNEL=`uname -r`
                if [ -f /etc/redhat-release ] ; then
                        DIST='RedHat'
                        PSUEDONAME=`cat /etc/redhat-release | sed s/.*\(// | sed s/\)//`
                        REV=`cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*//`
                elif [ -f /etc/SuSE-release ] ; then
                        SLES=`grep -i Enterprise /etc/SuSE-release`
                        SLSS=`grep -i Standard /etc/SuSE-release`
                        if [[ ! -z $SLES ]]; then
                                PSUEDONAME="SLES"
                        elif [[ ! -z $SLSS ]]; then
                                PSUEDONAME="SLSS"
                        fi
                        DIST=`cat /etc/SuSE-release | tr "\n" ' '| sed s/VERSION.*//`
                        REV=`cat /etc/SuSE-release | tr "\n" ' ' | sed s/.*=\ //`
                elif [ -f /etc/SUSE-release ] ; then
                        SLES=`grep -i Enterprise /etc/SuSE-release`
                        SLSS=`grep -i Standard /etc/SuSE-release`
                        if [[ ! -z $SLES ]]; then
                                PSUEDONAME="SLES"
                        elif [[ ! -z $SLSS ]]; then
                                PSUEDONAME="SLSS"
                        fi
                        DIST=`cat /etc/SUSE-release | tr "\n" ' '| sed s/VERSION.*//`
                        REV=`cat /etc/SUSE-release | tr "\n" ' ' | sed s/.*=\ //`
                elif [ -f /etc/lsb-release ] ; then
                        DIST=`cat /etc/lsb-release | tr "\n" ' '|sed -e 's/.*DESCRIPTION=//' | sed -e 's/"//g'`
                        REV=`cat /etc/lsb-release | tr "\n" ' '|sed -e 's/.*RELEASE=//' | sed -e 's/ .*//'`
                elif [ -f /etc/mandrake-release ] ; then
                        DIST='Mandrake'
                        PSUEDONAME=`cat /etc/mandrake-release | sed s/.*\(// | sed s/\)//`
                        REV=`cat /etc/mandrake-release | sed s/.*release\ // | sed s/\ .*//`
                elif [ -f /etc/debian_version ] ; then
                        DIST="Debian `cat /etc/debian_version`"
                        REV=""
                elif [ -f /etc/UnitedLinux-release ] ; then
                        DIST="[`cat /etc/UnitedLinux-release | tr "\n" ' ' | sed s/VERSION.*//`]"
                fi

                OSSTR="${OS1} ${DIST} ${REV}(${PSUEDONAME} ${KERNEL} ${MACH})"

        fi

        echo ${OSSTR}
}

###############################################################################
# DeleteTempFiles : will delete all the temporary files used in this program. #
#		This function is used in conjunction with the signal interupts        #
#		to ensure that all temporary files are cleaned up regardless          #
#		of how the script terminates.                                         #
###############################################################################
function DeleteTempFiles {

    if [[ $DEBUG = 1 ]]; then
	echo ""
	echo "`date +'%D_%T'` :Deleting Temporary Files..."
	echo ""
    fi
    rm -f $TMP_COL_LIST > /dev/null 2>&1				# list of all world-writeable dirs without a sticky bit
    rm -f $COLL_FILE_LIST > /dev/null  2>&1				# list of all executable world-writeable files
    rm -f $TMPFILE > /dev/null  2>&1 			                # command list
    rm -f $EXP_FILE > /dev/null  2>&1					# sorted unique command list
    rm -f $COLL_FILE_LIST_WIP > /dev/null  2>&1
    rm -f $TMP_COL_LOG  > /dev/null  2>&1
    if [[ ! -z $PIDLIST ]]; then
	if [[ $DEBUG = 1 ]]; then
            echo ""
	    echo "`date +'%D_%T'` :Kill remaining child processes: $PIDLIST"
	fi
	kill $PIDLIST
	wait
    fi
}

function svm_iscsi_check
{
   pkginfo -q SUNWmdr
   if [[ $? -eq 0 ]]; then

      echo "Checking Sun Volume Manager (SVM) configuration for ISCSI disks" \
         >> $SCRIPTLOG

      # Solaris Volume Manager is at least installed
      metastat_out=
      metastat_out=`metastat -p 2>>$SCRIPTLOG`
      if [[ $? -ne 0 ]]; then
         echo "ERROR: failed to get output from 'metastat -p'" >> $SCRIPTLOG
         return 1
      fi

      if [[ -z "$metastat_out" ]]; then
         echo "WARNING: metatstat returned no results" >> $SCRIPTLOG
         return 1
      fi

      # parse metastat output for ISCSI disks
      svm_iscsi_disks=`for iscsi_disk in $ISCSI_DEV_LIST; do \
         echo "$metastat_out" \
            | egrep -i " ${iscsi_disk}s[0-7]*($| )" \
            | cut -d' ' -f1; \
      done`

      if [[ $DEBUG = 1 ]] ; then
         for svm_iscsi_disk in $svm_iscsi_disks; do
            echo "DEBUG: found iscsi SVM disk: [$svm_iscsi_disk]" >> $SCRIPTLOG
         done
      fi

      if [[ ! -z "$svm_iscsi_disks" ]]; then
         # parse for sub-disks of the iscsi disk
         svm_iscsi_subdisks=`for meta_device in $svm_iscsi_disks; do \
            echo "$metastat_out" \
               | egrep -i " $meta_device " \
               | cut -d' ' -f1; \
         done | sort -u`

         if [[ $DEBUG = 1 ]] ; then
            for svm_iscsi_subdisk in $svm_iscsi_subdisks; do
               echo "DEBUG: found iscsi SVM sub-disk: [$svm_iscsi_subdisk]" >> $SCRIPTLOG
            done
         fi
      fi

      # get list of mounted file systems
      mount_out=`mount 2>>$SCRIPTLOG`

      if [ -z "$mount_out" ]; then
         echo "Mount command failed to return any output" >> $SCRIPTLOG
         return 1
      fi

      ISCSI_FS_LIST=`(echo "$ISCSI_FS_LIST"; \
         for meta_dev in $svm_iscsi_disks $svm_iscsi_subdisks; do \
            echo "$mount_out" | awk '/\/'$meta_dev' /{print $1}'
         done ) | sort -u`
   fi

   return
}

#----------------------------------------

function vxvm_iscsi_check
{
   pkginfo -q VRTSvxvm
   if [[ $? -eq 1 ]]; then
      echo "WARNING: Symantec / Veritas volume manager software not" \
         "installed" >> $SCRIPTLOG
      return
   fi

   vxdisk_list=`vxdisk list 2>/dev/null \
      | sed -e '/^DEVICE/d' \
            -e 's/ [ ]*/:/g' \
            -e 's/^://' \
            -e 's/:$//'`

   if [[ $DEBUG = 1 ]]; then
      for i in $vxdisk_list; do echo "i: [$i] >> $SCRIPTLOG "; done
   fi

   if [[ -z "$vxdisk_list" ]]; then
      echo "WARNING: 'vxdisk list' returned no results" >> $SCRIPTLOG
      return
   fi

   for vxvm_device in `echo "$vxdisk_list" | cut -d':' -f1`; do
      vxdisk_detail=`vxdisk list $vxvm_device 2>/dev/null`
      dg_name=`echo "$vxdisk_detail" \
         | sed -e '/group:/!d' \
               -e 's/^.*name=//' \
               -e 's/[   ].*//'`
      os_devs=`echo "$vxdisk_detail" \
         | sed -e '/state=/!d' \
               -e 's/[   ].*//'`
      dg_to_os_names=`(echo "$dg_to_os_names"; \
         for os_device in $os_devs; do \
            echo "$vxvm_device:$dg_name:$os_device"; \
         done) | sort`
   done

   if [[ -z "$dg_to_os_names" ]]; then
      echo "ERROR: failed to map VxVM devices to OS devices" >> $SCRIPTLOG
      return 1
   fi

   # get disk group name ... so we can then get volume name
   iscsi_dg_list=`for iscsi_dev in $ISCSI_DEV_LIST; do
         echo "$dg_to_os_names" \
            | egrep -i ":$iscsi_dev$" \
            | cut -d':' -f2
      done | sort -u`

   if [[ $DEBUG = 1 ]]; then
      for dg in $iscsi_dg_list; do echo "dg: [$dg]"; done
   fi

   # get volume names
   dg_vols=`for dg in $iscsi_dg_list; do
      vxprint -g $dg -v 2>/dev/null \
         | awk '/^v / {print $2}'
   done | sort -u`

   if [[ -z "$dg_vols" ]]; then
      echo "Failed to get list of volumes for ISCSI disk groups" >> $SCRIPTLOG
      return 1
   fi

   mount_out=`mount 2>/dev/null | cut -d' ' -f1,3`

   ISCSI_FS_LIST=`(echo "$ISCSI_FS_LIST"; \
      for dg_vol in $dg_vols; do \
         echo "$mount_out" \
            | awk '/\/'$dg_vol'$/ {print $1}'; \
      done) | sort -u`

   return
}

##########################################################################
# Function Detect_iscsi : It detects the iscsi devices on the server and #
# the corresponding file systems so that they can be skipped from scan.  #
##########################################################################

function Detect_iscsi {

    DETAIL_OS=`which_OS`
    PLATFORM_RHEL4=`echo $DETAIL_OS | grep "RedHat 4" `
    PLATFORM_RHEL3=`echo $DETAIL_OS | grep "RedHat 3" `
    PLATFORM_RHEL5=`echo $DETAIL_OS | grep "RedHat 5" `
    PLATFORM_RHEL6=`echo $DETAIL_OS | grep "RedHat 6" `
    PLATFORM_SOLARIS=`echo $DETAIL_OS | grep "Solaris" `
    PLATFORM_AIX=`echo $DETAIL_OS | grep "AIX" `
    PLATFORM_HPUX=`echo $DETAIL_OS | grep "HP-UX" `
    ISCSI_FS_LIST=""
    if [[ $DEBUG = 1 ]]; then
        echo "Before Checking for iscsi.. "
	echo "ISCSI_FS_LIST= $ISCSI_FS_LIST"
	echo "IS_ISCSI= $IS_ISCSI"
    fi
    echo " `date +'%D_%T'` :Before Checking for iscsi; ISCSI_FS_LIST= $ISCSI_FS_LIST ; IS_ISCSI= $IS_ISCSI" >> $SCRIPTLOG
    if [[ ! -z $PLATFORM_RHEL4 ]] || [[ ! -z $PLATFORM_RHEL3 ]]; then
        RPM_QRY=`rpm -qa | grep iscsi`
        if [[ ! -z $RPM_QRY ]]; then
            pvs_out=`pvs -o pv_name,vg_name`
            rm -f $TMPFILE
            for iscsi_dev in `iscsi-ls -l | sed -n -e '/Device:/s|^.*/||p'`; do
                echo "$pvs_out" | egrep -i "/$iscsi_dev[0-9]" | awk '{print $2}' >> $TMPFILE
            done
            if [[ -f $TMPFILE ]]; then
              vg_names=`cat $TMPFILE | sort -u`
              mount_out=`mount`
              rm -f $TMPFILE
              rm -f $TMPFILE2
              for vg_name in $vg_names ; do
                for lv_name in `lvs -o vg_name,lv_name | awk '/ '$vg_name' /{print $2}'`; do
                    echo "$mount_out" | awk '/\-'$lv_name' /{print $3}' >> $TMPFILE2 
                done
              done 
              if [[ -f $TMPFILE2 ]]; then
                ISCSI_FS_LIST=`cat $TMPFILE2 | sort | grep "^/"`
                if [[ ! -z $ISCSI_FS_LIST ]]; then
                    IS_ISCSI="TRUE"
                fi
                rm -f $TMPFILE2
              else
                IS_ISCSI="FALSE"
              fi
            else
              IS_ISCSI="FALSE"
            fi
        else
            IS_ISCSI="FALSE"
        fi
    elif [[ ! -z $PLATFORM_RHEL5 ]] || [[ ! -z $PLATFORM_RHEL6 ]]; then
        pvs_out=`pvs -o pv_name,vg_name`
        RPM_QRY=`rpm -qa | grep iscsi`
        if [[ ! -z $RPM_QRY ]]; then
          iscsi_cmd=`which iscsiadm 2>&1 | egrep -ci 'no iscsiadm '`
          if [[ $iscsi_cmd = 0 ]]; then
            ISCSI_DEV=`iscsiadm -m session -P 3  | grep "Attached scsi disk"`
            if [[ ! -z $ISCSI_DEV ]]; then
                if [[ ! -z $pvs_out ]]; then
                    rm -f $TMPFILE
                    for iscsi_dev in `iscsiadm -m session -P 3 | grep "Attached scsi disk" | awk '{print $4}'`; do
                        echo "$pvs_out" | egrep -i "/$iscsi_dev([0-9]+| )" | awk '{print $2}' | egrep -v '^$' >> $TMPFILE
                    done
                    if [ ! -s "$TMPFILE" ]; then
                        echo "WARNING: iscsi software installed but no iscsi devices found" >> $SCRIPTLOG 2>&1
                    else
                        vg_names=`cat $TMPFILE | sort -u`
                        mount_out=`mount`
                        rm -f $TMPFILE2
                        if [[ ! -z $vg_names ]]; then
                            for vg_name in $vg_names ; do
                                for lv_name in `lvs -o vg_name,lv_name | awk '/ '$vg_name' /{print $2}'`; do
                                    echo "$mount_out" | awk '/\-'$lv_name' /{print $3}' >> $TMPFILE2
                                done
                            done
                        fi
                        if [ ! -s "$TMPFILE2" ]; then
                            echo "WARNING: iscsi volume group(s) exist, but no iscsi logical volumes found" >> $SCRIPTLOG 2>&1
                        else
                            ISCSI_FS_LIST=`cat $TMPFILE2 | sort`
                            IS_ISCSI=TRUE
                        fi
                        rm -f $TMPFILE2
                    fi
               fi
            fi
          fi
        else
            IS_ISCSI=FALSE
        fi
    elif [[ ! -z $PLATFORM_SOLARIS ]]; then
        format_output=`echo | format 2>/dev/null`
        if [[ -z "$format_output" ]]; then
            echo "ERROR: format command returned no results" >> $SCRIPTLOG
        else
            ISCSI_DEV_LIST=`echo "$format_output" \
            | sed -n -e 's/^ [ ]*//' \
            -e 's/ [ ]*$//' \
            -e '/^[0-9]*\. / {
            s/^[0-9]*\. \([^ ]*\).*/\1/
            h
            n
            }
            /iscsi/ {
            x
            p
            }'`
            if [ -z "$ISCSI_DEV_LIST" ]; then
                echo "No ISCSI"  >> $SCRIPTLOG
            else
                IS_ISCSI=TRUE
                if svm_iscsi_check ; then
                    echo "Successful return from SVM ISCSI check"  >> $SCRIPTLOG
                    if vxvm_iscsi_check ; then
                        echo "Successful return from Symantec/Veritas ISCSI check" >> $SCRIPTLOG
                        if [[ $DEBUG = 1 ]]; then
                            echo "ISCSI_FS_LIST="  >> $SCRIPTLOG
                            for iscsi_fs in $ISCSI_FS_LIST; do echo "   $iscsi_fs" >> $SCRIPTLOG ; done
                        fi
                    else
                        echo "VxVM ISCSI check had non-zero return" >> $SCRIPTLOG
                    fi
                else
                    echo "SVM ISCSI check had non-zero return" >> $SCRIPTLOG
                fi
            fi
        fi
    elif [[ ! -z $PLATFORM_HPUX ]]; then
	HW_PATHS=`ioscan -kC iscsi | awk '/iscsi/{print $1}'`
	if [[ ! -z $HW_PATHS ]]; then
   #       IS_ISCSI="TRUE"
          for HW_PATH in $HW_PATHS; do  
	    rm -f $TMPFILE
            iscsi_disks=`ioscan -kfnH $HW_PATH  | sed -n -e 's/^ [ ]*//' -e 's/ [ ]*$//g' \
            -e 's/ [ ]*/ /g' -e 's|/dev/dsk/||' -e 's|/dev/rdsk/.*||' -e 's|/dev/disk/||' \
            -e 's|/dev/rdisk/.*||' -e '/^c/p' -e '/^disk[0-9a-z]/p'`
            vg_disp_out=`vgdisplay -v | awk '/^VG Name/{vg_name=$3} /PV Name/{print vg_name":"$3}' | sed -e 's|/dev/||' -e 's|/dev/dsk/||' -e 's|/dev/disk/||'`
            for iscsi_dev in $iscsi_disks; do
                iscsi_vg=''
                iscsi_vg=`echo "$vg_disp_out" | egrep -i ":$iscsi_dev$" | cut -d: -f1`
                if [ -z "$iscsi_vg" ]; then 
                    echo "$iscsi_dev not used in VG" >>$SCRIPTLOG
                else
                    echo $iscsi_vg >> $TMPFILE
                fi
            done
            sorted_vg=`cat $TMPFILE | sort | uniq `
            if [[ ! -z $sorted_vg ]]; then
                VG_LIST=`echo $sorted_vg | sed 's/\ /|/g'`
            fi
            ISCSI_FS_LIST=`mount | egrep -i "$VG_LIST" | awk '{print $1}' | grep "^/" `
            if [[ ! -z $ISCSI_FS_LIST ]]; then
                IS_ISCSI="TRUE"
            fi
            rm -f $TMPFILE
          done
	else
	    IS_ISCSI="FALSE"
	fi
    else
        if [[ ! -z $PLATFORM_AIX ]]; then
            iscsi_devs=`for iscsi_int in \`lsiscsi | cut -d' ' -f1\`; do lsdev -p $iscsi_int | sed -e 's/ .*//' -e "s/^/$iscsi_int:/"; done`
            lspv_out=`lspv | sed -e 's/ [ ]*/:/g' -e 's/:$//'`
            if [[ ! -z $iscsi_devs ]]; then
                iscsi_vgs=`for iscsi_disk in \`echo "$iscsi_devs" | cut -d':' -f2\`; do echo "$lspv_out" | awk -F: '/^'$iscsi_disk':/ {print $3}'; done | sort -u`
                if [[ ! -z $iscsi_vgs ]]; then
                    ISCSI_FS_LIST=`for iscsi_vg in $iscsi_vgs; do lsvg -l $iscsi_vg | awk '$NF ~ /^\// {print $NF}'; done`
                    if [[ ! -z $ISCSI_FS_LIST ]]; then
                        IS_ISCSI="TRUE"
                    fi
                fi
            fi

        fi			
    fi
    if [[ $DEBUG = 1 ]]; then
        echo "After Checking for iscsi.. "
	echo "ISCSI_FS_LIST= $ISCSI_FS_LIST"
	echo "IS_ISCSI= $IS_ISCSI"
    fi
    echo " `date +'%D_%T'` :After Checking for iscsi.." >> $SCRIPTLOG
    echo " `date +'%D_%T'` :ISCSI_FS_LIST= $ISCSI_FS_LIST " >> $SCRIPTLOG
    echo " `date +'%D_%T'` :IS_ISCSI= $IS_ISCSI" >> $SCRIPTLOG	
}

#####################################################################
# Checking for the Usage of /tmp and OUTDIR directory. If the       #
# available space of TMPDIR or OUTDIR is less than estimated space ,then exit.#
#####################################################################
function check_space
{
    case $OS in
    Linux) if [[ $TMPDIR != "$OUTDIR" ]]; then
               out_avl=`df -Pm $OUTDIR | tail -n 1 | awk '{print $4}'` 
           else
               tmp_avl=`df -Pm $TMPDIR | tail -n 1 | awk '{print $4}'`
           fi
	   ;;
    AIX)   if [[ $TMPDIR != "$OUTDIR" ]]; then
               out_avl=`df -Pm $OUTDIR | tail -1 | awk '{print $4}'`
           else
               tmp_avl=`df -Pm $TMPDIR | tail -1 | awk '{print $4}'`
           fi
	   ;;
    SunOS) if [[ $TMPDIR != "$OUTDIR" ]]; then
               out_avl=`df -k $OUTDIR | tail -1| awk '{print $4/1024}'| awk '{printf("%d\n",$1)}'`
           else
               tmp_avl=`df -k $TMPDIR | tail -1| awk '{print $4/1024}'| awk '{printf("%d\n",$1)}'`
           fi
	   ;;
    HP-UX) if [[ $TMPDIR != "$OUTDIR" ]]; then
               out_avl=`df -Pk $OUTDIR | tail -1 |  awk '{print $4/1024}' | awk '{printf("%d\n",$1)}'`
           else
               tmp_avl=`df -Pk $TMPDIR | tail -1 |  awk '{print $4/1024}' | awk '{printf("%d\n",$1)}'`
           fi
           ;;
    esac

    if [[ $TMPDIR != "$OUTDIR" ]]; then
        if [[ $out_avl -lt $SPACE ]]; then 
            if [[ $DEBUG = 1 ]];then
                echo "$OUTDIR does not have sufficient space to execute the program. Quitting.."
            fi
            echo "`date +'%D_%T'` :ERROR: $OUTDIR does not have required $SPACE MB space : Exiting.." | tee -a $SCRIPTLOG
            cat $SCRIPTLOG >> $FINAL_SCRIPTLOG 2>&1 
            rm -f $SCRIPTLOG
	    DeleteTempFiles
            exit 2
        fi
    else
        if [[ $tmp_avl -lt $SPACE ]]; then
            if [[ $DEBUG = 1 ]];then
                echo "$TMPDIR does not have sufficient space to execute the program. Quitting.."
            fi
            echo "`date +'%D_%T'` :ERROR: $TMPDIR does not have required $SPACE MB space : Exiting.." | tee -a $SCRIPTLOG
	    cat $SCRIPTLOG >> $FINAL_SCRIPTLOG 2>&1
            rm -f $SCRIPTLOG
            DeleteTempFiles
            exit 2
        fi
    fi
    if [[ $DEBUG = 1 ]];then
        if [[ $TMPDIR != "$OUTDIR" ]]; then
            echo "Space in the $OUTDIR checked. Progressing... "   
        else
            echo "Space in the $TMPDIR checked. Progressing... "
        fi
    fi
    echo "`date +'%D_%T'` :INFORMATION: SPACE checked for temporary and working directory." >> $SCRIPTLOG
    
}


###########################################################################
# Check those filesystems that must always be checked           #
###########################################################################
function checkAlsFiles {
    rm -f $TMPFILE2
    for CHECK_FILE in $OVERRIDE_FILES; do
        if [[  -s $CHECK_FILE ]]; then
            if [[ $DEBUG = 1 ]]; then
                echo ""
           	echo "`date +'%D_%T'` :Listing the filesystems for always check from override file $CHECK_FILE"
		echo ""
            fi
            grep "always_check" $CHECK_FILE |grep -v "^#" | awk '{print $2}' >> $TMPFILE2
	    fi
    done 
    if [[ ! -z $TMPFILE2 ]]; then
    # remove any duplicate names
        AFLIST=`cat $TMPFILE2 2>>$SCRIPTLOG | sort | uniq`
        if [[ ! -z $AFLIST ]]; then
            echo "`date +'%D_%T'` :Information: File systems always to be checked : " >> $SCRIPTLOG
            echo "$AFLIST" >> $SCRIPTLOG
	    if [[ $DEBUG = 1 ]]; then
                echo "`date +'%D_%T'` :ALWAYS CHECK - $AFLIST"
	    fi
        else
            echo "`date +'%D_%T'` :Information: No File systems for always check" >> $SCRIPTLOG
            if [[ $DEBUG = 1 ]]; then
                echo "No filesystem specified for ALWAYS_CHECK"
            fi
        fi
    else
        echo "`date +'%D_%T'` :Information: No File systems for always check" >> $SCRIPTLOG
        if [[ $DEBUG = 1 ]]; then
            echo "No filesystem specified for ALWAYS_CHECK"
        fi
    fi
    
    rm -f $TMPFILE2
}

###########################################################################
# Check those filesystems that must never be checked           #
###########################################################################
function checkNevFiles {    
    rm -f $TMPFILE3
    for CHECK_FILE in $OVERRIDE_FILES; do
        if [[  -s $CHECK_FILE ]]; then
            if [[ $DEBUG = 1 ]]; then
           	echo "`date +'%D_%T'` :Listing the filesystems for never check from override file $CHECK_FILE"
		echo ""
            fi
            grep "never_check" $CHECK_FILE |grep -v "^#" |awk '{print $2}' >> $TMPFILE3
        fi
    done 
    
    if [[ ! -z $TMPFILE3 ]]; then
        # remove any duplicate names
        NLST=`cat $TMPFILE3 2>>$SCRIPTLOG | sort | uniq`
        NFLIST=`cat $TMPFILE3 2>> $SCRIPTLOG | sort | uniq | grep "/" | sed 's/^/\^/g' | sed 's/$/\$/g'`
        PATTERN=`cat $TMPFILE3 2>> $SCRIPTLOG | sort | uniq |grep -v "/"`
        NFLIST="$NFLIST $PATTERN"
        if [[ ! -z $NLST ]]; then
            echo "`date +'%D_%T'` :Information: File systems never to be checked :" >> $SCRIPTLOG
            echo "$NLST" >> $SCRIPTLOG
            if [[ $DEBUG = 1 ]]; then
                echo "`date +'%D_%T'` :NEVER CHECK  $NLST"
	    fi
        else
            echo "`date +'%D_%T'` :Information: No File systems for never check" >> $SCRIPTLOG
            if [[ $DEBUG = 1 ]]; then
                echo "No filesystem specified for NEVER_CHECK"
            fi
        fi
    else
        echo "`date +'%D_%T'` :Information: No File systems for never check" >> $SCRIPTLOG
	if [[ $DEBUG = 1 ]]; then
	    echo "No filesystem specified for NEVER_CHECK"
   	fi
    fi
    rm -f $TMPFILE3
}

###################################################################################
# Parse Configuration parameter; Set default value if not set already in the file #
###################################################################################

function parse_config {
  if [[ -s $CONFIG_FILE ]]; then
    EP2_NICEVALUE_COLLECTOR_ANALYZER=`grep -v '^$' $CONFIG_FILE | grep -v '^#' | grep "EP2_NICEVALUE_COLLECTOR_ANALYZER" | awk -F'=' '{print $2}'`
    EP2_ANALYZER_PAUSE_COUNT=`grep -v '^$' $CONFIG_FILE | grep -v '^#' | grep "EP2_ANALYZER_PAUSE_COUNT" | awk -F'=' '{print $2}'`
    EP2_ANALYZER_PAUSE_TIME=`grep -v '^$' $CONFIG_FILE | grep -v '^#' |grep "EP2_ANALYZER_PAUSE_TIME" | awk -F'=' '{print $2}'`
    EP2_PERCENT_OF_FILES_DIRTY=`grep -v '^$' $CONFIG_FILE | grep -v '^#' | grep "EP2_PERCENT_OF_FILES_DIRTY" | awk -F'=' '{print $2}'`
    EARLIEST_COLLECTOR_START=`grep -v '^$' $CONFIG_FILE | grep -v '^#' |grep "EARLIEST_COLLECTOR_START" | awk -F'=' '{print $2}'`
    LATEST_COLLECTOR_START=`grep -v '^$' $CONFIG_FILE | grep -v '^#' |grep "LATEST_COLLECTOR_START" | awk -F'=' '{print $2}'`
    EARLIEST_ANALYZER_START=`grep -v '^$' $CONFIG_FILE | grep -v '^#' |grep "EARLIEST_ANALYZER_START" | awk -F'=' '{print $2}'`
    LATEST_ANALYZER_START=`grep -v '^$' $CONFIG_FILE | grep -v '^#' |grep "LATEST_ANALYZER_START" | awk -F'=' '{print $2}'`
    RECIPIENT=`grep -v '^$' $CONFIG_FILE | grep -v '^#' |grep "RECIPIENT" | awk -F'=' '{print $2}'`
    CPU_IDLE_MIN=`grep -v '^$' $CONFIG_FILE | grep -v '^#' |grep "CPU_IDLE_MIN" | awk -F'=' '{print $2}'`
    EP2_ANALYZER_PERREC_SLEEP=`grep -v '^$' $CONFIG_FILE | grep -v '^#' |grep "EP2_ANALYZER_PERREC_SLEEP" | awk -F'=' '{print $2}'`
    EP2_COMPRESSION_PGM=`grep -v '^$' $CONFIG_FILE | grep -v '^#' |grep "EP2_COMPRESSION_PGM" | awk -F'=' '{print $2}'`
    EP2_SKIP_CSVZIP=`grep -v '^$' $CONFIG_FILE | grep -v '^#' |grep "EP2_SKIP_CSVZIP" | awk -F'=' '{print $2}'`
    EP2_EXCLUDED_HOME_DIRS=`grep -v '^$' $CONFIG_FILE | grep -v '^#' |grep "EP2_EXCLUDED_HOME_DIRS" | awk -F'=' '{print $2}'`

    if [[ $OS = "AIX" ]];then
        if [[ -z $EP2_NICEVALUE_COLLECTOR_ANALYZER ]] || [[ $EP2_NICEVALUE_COLLECTOR_ANALYZER -gt 19 ]] || [[ $EP2_NICEVALUE_COLLECTOR_ANALYZER -lt -20 ]] ; then
            EP2_NICEVALUE_COLLECTOR_ANALYZER=10
        fi
    else
        if [[ -z $EP2_NICEVALUE_COLLECTOR_ANALYZER ]] || [[ $EP2_NICEVALUE_COLLECTOR_ANALYZER -gt 20 ]] || [[ $EP2_NICEVALUE_COLLECTOR_ANALYZER -lt -19 ]] ; then
            EP2_NICEVALUE_COLLECTOR_ANALYZER=10
        fi
    fi
    if [[ -z $EP2_ANALYZER_PAUSE_COUNT ]]; then
        EP2_ANALYZER_PAUSE_COUNT=0
    fi
    if [[ -z $EP2_ANALYZER_PAUSE_TIME ]]; then
        EP2_ANALYZER_PAUSE_TIME=0
    fi
    if [[ -z $EP2_PERCENT_OF_FILES_DIRTY ]]; then
        if [[ $VERBOSE = 1 ]]; then
            EP2_PERCENT_OF_FILES_DIRTY=7
        else
            EP2_PERCENT_OF_FILES_DIRTY=5
        fi
    fi
    if [[ -z $EARLIEST_COLLECTOR_START  ]]; then
        EARLIEST_COLLECTOR_START=0
    fi
    if [[ -z $LATEST_COLLECTOR_START   ]]; then
        LATEST_COLLECTOR_START=0
    fi
    if [[ -z $EARLIEST_ANALYZER_START  ]]; then
        EARLIEST_ANALYZER_START=0
    fi
    if [[ -z $LATEST_ANALYZER_START ]]; then
        LATEST_ANALYZER_START=0
    fi
    if [[ -z $RECIPIENT ]]; then
        RECIPIENT="root@localhost"
    fi
    if [[ -z $CPU_IDLE_MIN ]]; then
        CPU_IDLE_MIN=30
    fi
    if [[ -z $EP2_ANALYZER_PERREC_SLEEP ]]; then
        EP2_ANALYZER_PERREC_SLEEP=500000
    fi
    if [[ -z $EP2_COMPRESSION_PGM  ]]; then
        EP2_COMPRESSION_PGM="/bin/compress"
    fi
    if [[ -z $EP2_SKIP_CSVZIP ]]; then
        EP2_SKIP_CSVZIP="FALSE"
    fi
    echo "`date +'%D_%T'` :EP2_NICEVALUE_COLLECTOR_ANALYZER=$EP2_NICEVALUE_COLLECTOR_ANALYZER " >> $SCRIPTLOG
    echo "`date +'%D_%T'` :EP2_ANALYZER_PAUSE_COUNT=$EP2_ANALYZER_PAUSE_COUNT " >> $SCRIPTLOG
    echo "`date +'%D_%T'` :EP2_ANALYZER_PAUSE_TIME=$EP2_ANALYZER_PAUSE_TIME " >> $SCRIPTLOG
    echo "`date +'%D_%T'` :EP2_PERCENT_OF_FILES_DIRTY=$EP2_PERCENT_OF_FILES_DIRTY " >> $SCRIPTLOG
    echo "`date +'%D_%T'` :EARLIEST_COLLECTOR_START=$EARLIEST_COLLECTOR_START " >> $SCRIPTLOG
    echo "`date +'%D_%T'` :LATEST_COLLECTOR_START=$LATEST_COLLECTOR_START " >> $SCRIPTLOG
    echo "`date +'%D_%T'` :EARLIEST_ANALYZER_START=$EARLIEST_ANALYZER_START " >> $SCRIPTLOG
    echo "`date +'%D_%T'` :LATEST_ANALYZER_START=$LATEST_ANALYZER_START " >> $SCRIPTLOG
    echo "`date +'%D_%T'` :RECIPIENT=$RECIPIENT " >> $SCRIPTLOG
    echo "`date +'%D_%T'` :CPU_IDLE_MIN=$CPU_IDLE_MIN " >> $SCRIPTLOG
    echo "`date +'%D_%T'` :EP2_ANALYZER_PERREC_SLEEP=$EP2_ANALYZER_PERREC_SLEEP " >> $SCRIPTLOG
    echo "`date +'%D_%T'` :EP2_COMPRESSION_PGM=$EP2_COMPRESSION_PGM  " >> $SCRIPTLOG
    echo "`date +'%D_%T'` :EP2_SKIP_CSVZIP=$EP2_SKIP_CSVZIP " >> $SCRIPTLOG
    echo "`date +'%D_%T'` :EP2_EXCLUDED_HOME_DIRS=$EP2_EXCLUDED_HOME_DIRS " >> $SCRIPTLOG
    if [[ $DEBUG = 1 ]]; then
        echo "EP2_NICEVALUE_COLLECTOR_ANALYZER=$EP2_NICEVALUE_COLLECTOR_ANALYZER "
        echo "EP2_ANALYZER_PAUSE_COUNT=$EP2_ANALYZER_PAUSE_COUNT "
        echo "EP2_ANALYZER_PAUSE_TIME=$EP2_ANALYZER_PAUSE_TIME " 
        echo "EP2_PERCENT_OF_FILES_DIRTY=$EP2_PERCENT_OF_FILES_DIRTY " 
        echo "EARLIEST_COLLECTOR_START=$EARLIEST_COLLECTOR_START "
        echo "LATEST_COLLECTOR_START=$LATEST_COLLECTOR_START "
        echo "EARLIEST_ANALYZER_START=$EARLIEST_ANALYZER_START "
        echo "LATEST_ANALYZER_START=$LATEST_ANALYZER_START "
        echo "RECIPIENT=$RECIPIENT "
        echo "CPU_IDLE_MIN=$CPU_IDLE_MIN "
        echo "EP2_ANALYZER_PERREC_SLEEP=$EP2_ANALYZER_PERREC_SLEEP "
        echo "EP2_COMPRESSION_PGM=$EP2_COMPRESSION_PGM "
        echo "EP2_SKIP_CSVZIP=$EP2_SKIP_CSVZIP "
        echo "EP2_EXCLUDED_HOME_DIRS=$EP2_EXCLUDED_HOME_DIRS "
    fi
  else
    echo "`date +'%D_%T'` :Configuration file $CONFIG_FILE does not exist. " >> $SCRIPTLOG
    if [[ $DEBUG = 1 ]]; then
        echo "Configuration file $CONFIG_FILE does not exist. "
    fi
  fi
}

###########################################################################################################
# Identify each filesystems to be processed, pass them through estimator script to check space requirement#
# If space available, pass each file system to collector and analyzer respectively, handle error if any.  #
###########################################################################################################

function process_filesystems {
    rm -f $TMPFILE
    EXCLUDE=""
	if [[ -f $MOUNT_POINT ]]; then 
    # skip non-local filesystems - NFS/tmpfs/proc/swap entries , skip read-only file systems - cdroms etc.(media) 
        case $OS in
	    AIX) EXCLUDE=`grep -p -v '^*' $MOUNT_POINT | grep -p -w -E "nfs|proc|swap|tmpfs|media|afs|autofs|gpfs" | grep : | tr -d ":" 2>> $SCRIPTLOG`
                 GPFS_FS=`grep -p -v '^*' $MOUNT_POINT | grep -p -w -E "gpfs" | grep : | tr -d ":" 2>> $SCRIPTLOG`
                ;;
	    Linux) EXCLUDE=`grep -v '^#' $MOUNT_POINT| grep -v '^$' | grep -w -E 'nfs|proc|swap|tmpfs|media|afs|autofs|gpfs'| awk '{print $2}' 2>>$SCRIPTLOG`
                   GPFS_FS=`grep -v '^#' $MOUNT_POINT| grep -v '^$' | grep -w -E 'gpfs'| awk '{print $2}' 2>>$SCRIPTLOG`
                   ;;
            SunOS) EXCLUDE=`grep -v '^#' $MOUNT_POINT| grep -v '^$' |egrep -e 'nfs|proc|swap|tmpfs|media|afs|autofs|gpfs' | nawk '{print $3}' | grep '^/' 2>>$SCRIPTLOG`
                   GPFS_FS=`grep -v '^#' $MOUNT_POINT| grep -v '^$' |egrep -e 'gpfs' | nawk '{print $3}' | grep '^/' 2>>$SCRIPTLOG`
                   ;;
           # HP-UX)EXCLUDE=`grep -v '^#' $MOUNT_POINT| grep -v '^$' | grep -w -E 'nfs|proc|swap|tmpfs|media|afs|autofs'| awk '{print $2}' 2>>$SCRIPTLOG`
             HP-UX)EXCLUDE=`egrep -vi '^$|^#| (nfs|proc|swap|tmpfs|media|afs|autofs|gpfs) ' $MOUNT_POINT 2>>$SCRIPTLOG | awk '{print $2}' 2>>$SCRIPTLOG`
                   GPFS_FS=`egrep -vi '^$|^#| (gpfs) ' $MOUNT_POINT 2>>$SCRIPTLOG | awk '{print $2}' 2>>$SCRIPTLOG`
                   ;;
            *) EXCLUDE=`grep -v '^#' $MOUNT_POINT| grep -v '^$' | grep -w -E 'nfs|proc|swap|tmpfs|media|afs|autofs|gpfs'| awk '{print $2}' 2>>$SCRIPTLOG`
               GPFS_FS=`grep -v '^#' $MOUNT_POINT| grep -v '^$' | grep -w -E 'gpfs'| awk '{print $2}' 2>>$SCRIPTLOG`
                   ;;
        esac
        if [[ ! -z $EXCLUDE ]]; then 
            echo "`date +'%D_%T'` :Information: File systems to be excluded :" >> $SCRIPTLOG
            echo "$EXCLUDE" >> $SCRIPTLOG 
	    if [[ $DEBUG = 1 ]]; then
       	        echo "File systems to be excluded : $EXCLUDE"
    	    fi
        fi
        # GPFS file system handling # Ticket IN4401142 
        if [[ ! -z $GPFS_FS ]]; then
            echo "`date +'%D_%T'` :Warning: GPFS filesystem $GPFS_FS has been excluded from scanning. An always_check statement must be added to the ep2.overrides.local file on the server to scan this filesystem." | tee -a $SCRIPTLOG
            if [[ $DEBUG = 1 ]]; then
                echo "Warning: GPFS filesystem $GPFS_FS has been excluded from scanning. An always_check statement must be added to the ep2.overrides.local file on the server to scan this filesystem."
            fi
        fi

	if [[ $DEBUG = 1 ]]; then
            echo "Selecting file systems to be parsed by the collector, local and exported filesystems..."
        fi
        case $OS in
            AIX)SEL_FILESYS=`grep -p -v '^*' $MOUNT_POINT | grep -p -v -w -E "nfs|proc|swap|tmpfs|media|afs|autofs|gpfs" | grep ':' | tr -d ':' 2>>$SCRIPTLOG`
                ;;
            Linux) SEL_FILESYS=`grep -v '^#' $MOUNT_POINT| grep -v '^$' | grep -v ':' | grep -v -w -E 'nfs|proc|swap|tmpfs|media|afs|autofs|gpfs'| awk '{print $2}' | grep '^/' 2>>$SCRIPTLOG`
                  ;;
            SunOS) SEL_FILESYS=`grep -v '^#' $MOUNT_POINT| grep -v '^$' | grep -v ':' | grep -v 'nfs' | grep -v 'proc' | grep -v 'swap' | grep -v 'tmpfs' | grep -v 'media' | grep -v 'afs' | grep -v 'autofs' | grep -v 'gpfs' | nawk '{print $3}' | grep '^/' 2>>$SCRIPTLOG`
                   ;;
            HP-UX) SEL_FILESYS=`grep -v '^#' $MOUNT_POINT| grep -v '^$'  | grep -v ':' | grep -v -w -E 'nfs|proc|swap|tmpfs|media|afs|autofs|gpfs'| awk '{print $2}' | grep '^/' 2>>$SCRIPTLOG`
                   ;;
            *) SEL_FILESYS=`grep -v '^#' $MOUNT_POINT| grep -v '^$'  | grep -v ':' | grep -v -w -E 'nfs|proc|swap|tmpfs|media|afs|autofs|gpfs'| awk '{print $2}' | grep '^/' 2>>$SCRIPTLOG`
                   ;;
        esac
        SEL_FILESYS=`echo $SEL_FILESYS | tr " " '\n' | sed 's/^\/$/ep2slash_fs/g' | sed 's/\/$//g' | sed 's/ep2slash_fs/\//g'`
        # Check if zfs filesystem is there by mount command.
        if [[ $OS = "SunOS" ]];then
            ZFS_FS=`mount -p | grep -i 'zfs' | awk '{print $3}' | grep "^/" `
        else
            ZFS_FS=`mount| grep -i 'zfs' | awk '{print $1}' | grep "^/" `
        fi
        if [[ ! -z $ZFS_FS ]]; then
            echo "`date +'%D_%T'` :ZFS file systems are included for scanning:" >> $SCRIPTLOG
            echo "$ZFS_FS" >> $SCRIPTLOG
            if [[ $DEBUG = 1 ]]; then
                echo "ZFS file systems are included for scanning: $ZFS_FILESYS"
            fi
            SEL_FILESYS="$SEL_FILESYS $ZFS_FS"
            SEL_FILESYS=`echo $SEL_FILESYS | tr " " '\n' | sed 's/^\/$/ep2slash_fs/g' | sed 's/\/$//g' | sed 's/ep2slash_fs/\//g'`
        else
            #which zfs >> $SCRIPTLOG 2>&1
            zfs_check=`which zfs 2>&1 | egrep -ci 'no zfs '`
            if [[ $zfs_check = 0 ]]; then
                RES_LIST=`zfs list | grep -i "no datasets available" `
                if [[ -z $RES_LIST ]]; then
                    ZFS_FILESYS=`zfs list |  awk '{print $5}' | grep '^/'`
                    if [[ ! -z $ZFS_FILESYS  ]]; then
                        echo "`date +'%D_%T'` :ZFS file systems are included for scanning:" >> $SCRIPTLOG
                        echo "$ZFS_FILESYS" >> $SCRIPTLOG
                        if [[ $DEBUG = 1 ]]; then
                            echo "ZFS file systems are included for scanning: $ZFS_FILESYS"
                        fi
                        SEL_FILESYS="$SEL_FILESYS $ZFS_FILESYS"
                        SEL_FILESYS=`echo $SEL_FILESYS | tr " " '\n' | sed 's/^\/$/ep2slash_fs/g' | sed 's/\/$//g' | sed 's/ep2slash_fs/\//g'`
                    else
                        echo "`date +'%D_%T'` :No zfs filesystem." >> $SCRIPTLOG
                        if [[ $DEBUG = 1 ]]; then
                            echo "No zfs filesystem."
                        fi
                    fi
               else
                   echo "`date +'%D_%T'` :No datasets available for ZFS." >> $SCRIPTLOG
                   if [[ $DEBUG = 1 ]]; then
                       echo "No datasets available for ZFS."
                  fi
               fi
           else
               echo "`date +'%D_%T'` :No zfs command exists." >> $SCRIPTLOG
               if [[ $DEBUG = 1 ]]; then
                   echo "No zfs command exists."
               fi
           fi
        fi 
        rm -f $EXP_FILE	
	#exportfs |grep ^/ | awk -F"/" '{print $2}'| sed 's/^/\//g' | awk '{print $1}' >> $EXP_FILE 2>>$SCRIPTLOG
        #EXP_FS=`cat $EXP_FILE 2>>$SCRIPTLOG | sort | uniq`
        EXP_FS=`exportfs 2>>$SCRIPTLOG | sed -e '/^\//!d' -e 's/ .*//'  -e 's|^\(\/[^/]*\).*|\1|' | sort -u 2>>$SCRIPTLOG`
	EXP_FS=`echo $EXP_FS | tr " " '\n' |sed 's/^\/$/ep2slash_fs/g' | sed 's/\/$//g' | sed 's/ep2slash_fs/\//g'`
	if [[ $DEBUG = 1 ]]; then
    	    echo "Selected FILE SYSTEMS without considering ALWAYS and NEVER check : $SEL_FILESYS"
        fi
        echo "`date +'%D_%T'` :Selected FILE SYSTEMS without considering ALWAYS and NEVER check :" >> $SCRIPTLOG 
        echo "$SEL_FILESYS" >> $SCRIPTLOG		
	SF_ALF="$SEL_FILESYS $AFLIST $EXP_FS"
        SF_ALF=`echo $SF_ALF | tr " " '\n' |sed 's/^\/$/ep2slash_fs/g' | sed 's/\/$//g' | sed 's/ep2slash_fs/\//g'`
	echo $SF_ALF | tr " " "\n" >> $TMPFILE 2>>$SCRIPTLOG
	FS_AL=`cat $TMPFILE 2>>$SCRIPTLOG | sort | uniq`
        FS_AL=`echo $FS_AL | tr " " '\n' | sed 's/^\/$/ep2slash_fs/g' | sed 's/\/$//g' | sed 's/ep2slash_fs/\//g'`
        echo "`date +'%D_%T'` :Selected filesystems with always check and exported filesystems list:" >>  $SCRIPTLOG 
        echo "$FS_AL" >>  $SCRIPTLOG
        NFLIST=`echo $NFLIST | tr " " '\n' | sed 's/^\/$/ep2slash_fs/g' | sed 's/\/$//g' | sed 's/ep2slash_fs/\//g'`
        if [[ ! -z $NFLIST ]]; then
             NVR_FS=`echo $NFLIST|sed 's/\ /|/g'`
        fi
        if [[ $OS = "SunOS" ]];then
          if [[ ! -z $NVR_FS  ]]; then
	    FINAL_FS=`echo $FS_AL| tr " " '\n' | egrep -v -e "$NVR_FS"`
          else
            FINAL_FS=`echo $FS_AL| tr " " '\n'`
          fi
        else
          if [[ ! -z $NVR_FS  ]]; then
            FINAL_FS=`echo $FS_AL| tr " " '\n' | grep -v -E "$NVR_FS"`
          else
            FINAL_FS=`echo $FS_AL| tr " " '\n'`
          fi
        fi
        FINAL_FS=`echo $FINAL_FS | tr " " '\n' | sed 's/^\/$/ep2slash_fs/g' | sed 's/\/$//g' | sed 's/ep2slash_fs/\//g'`
	rm -f $TMPFILE
		if [[ $DEBUG = 1 ]]; then
    	    echo "Selected FILE SYSTEMS after considering ALWAYS and NEVER check : $FINAL_FS"
        fi	
        echo "`date +'%D_%T'` :Selected FILE SYSTEMS after considering ALWAYS and NEVER check :" >> $SCRIPTLOG
        echo "$FINAL_FS" >> $SCRIPTLOG
		# If there is any iscsi device then the corresponding file systems need to be excluded.
		if [[ $IS_ISCSI = "TRUE" ]] ; then
		    if [[ ! -z $ISCSI_FS_LIST ]] ; then
			    ISCSI_FS_LIST=`echo $ISCSI_FS_LIST | tr " " '\n' | sed 's/^\/$/ep2slash_fs/g' | sed 's/\/$//g' | sed 's/ep2slash_fs/\//g'`
			    ISCSI_FS=`echo $ISCSI_FS_LIST | sed 's/\ /|/g'`
				if [[ $OS = "SunOS" ]];then
				    FINAL_FS=`echo $FINAL_FS | tr " " '\n' | egrep -v -e "$ISCSI_FS"`
				else
				    FINAL_FS=`echo $FINAL_FS | tr " " '\n' | grep -v -E "$ISCSI_FS"`
				fi
			fi
		fi
		FINAL_FS=`echo $FINAL_FS | tr " " '\n' | sed 's/^\/$/ep2slash_fs/g' | sed 's/\/$//g' | sed 's/ep2slash_fs/\//g'`
		if [[ $DEBUG = 1 ]]; then
    	    echo "Selected FILE SYSTEMS after considering iscsi check : $FINAL_FS"
        fi	
        echo "`date +'%D_%T'` :Selected FILE SYSTEMS after considering iscsi check :" >> $SCRIPTLOG
        echo "$FINAL_FS" >> $SCRIPTLOG		
        # Check if any of the file systems is/are with 0k space, then skip form checking.
        FS_ZERO=""
        for FS_FN in $FINAL_FS; do
            case $OS in
            Linux)  SIZE_FS=`df -Pk $FS_FN | tail -n 1 | awk '{print $2}'` ;;
            AIX)    SIZE_FS=`df -Pk $FS_FN | tail -1 | awk '{print $2}'` ;;
            SunOS)  SIZE_FS=`df -k $FS_FN | tail -1 | awk '{print $2}'` ;;
            HP-UX)  SIZE_FS=`df -Pk $FS_FN | tail -1 | awk '{print $2}'` ;;
            esac
            echo $SIZE_FS | grep "-" >> $SCRIPTLOG
            if [[ $? -eq 0 ]]; then
                FS_ZERO="$FS_ZERO $FS_FN"
            else
                if [[ $SIZE_FS -eq 0 ]]; then
                    FS_ZERO="$FS_ZERO $FS_FN"
                fi
            fi
        done
        if [[ ! -z $FS_ZERO ]]; then
          if [[ $DEBUG = 1 ]]; then
            echo "Skipping the zero sized file systems : $FS_ZERO "
          fi
          echo "`date +'%D_%T'` :Skipping the zero sized file systems :" >> $SCRIPTLOG
          echo "$FS_ZERO " >> $SCRIPTLOG
          FS_ZERO=`echo $FS_ZERO|sed 's/\ /|/g'`
          if [[ ! -z $FS_ZERO ]]; then
            if [[ $OS = "SunOS" ]];then
              FINAL_FS=`echo $FINAL_FS |tr " " '\n'| egrep -v -e "$FS_ZERO"`
            else
              FINAL_FS=`echo $FINAL_FS |tr " " '\n'| grep -v -E "$FS_ZERO"`
            fi
          fi
        fi
        if [[ $DEBUG = 1 ]]; then
            echo "Checking the space.. " 
        fi
        echo "`date +'%D_%T'` :Checking the space.. " >> $SCRIPTLOG
        rm -f $TMPFILE
        rm -f $TMPFILE2
        TOT_SP=0
        $ESTIMATOR_SCRIPT -m $ESTIMATOR_INODE_MULTIPLIER -t >> $TMPFILE
        if [[  -s $TMPFILE ]]; then
            TMP_SPACE=`grep -v "#" $TMPFILE | awk -F',' '{print $2}'`
        fi
        for FSYS in $FINAL_FS; do
            rm -f $TMPFILE
            if [[ $DEBUG = 1 ]]; then
                echo "File system $FSYS is being checked for space"
            fi
            $ESTIMATOR_SCRIPT -m $ESTIMATOR_INODE_MULTIPLIER -s $FSYS -t >> $TMPFILE
            if [[  -s $TMPFILE ]]; then
                FS_SPACE=`grep -v "#" $TMPFILE | awk -F',' '{print $3}'`
            fi
            TOT_SP=`echo "scale=6 ; ${FS_SPACE:=0} + ${TOT_SP:=0}" | bc`
            echo "`date +'%D_%T'` :FILE System $FSYS : required space $FS_SPACE MB" >> $SCRIPTLOG
            echo "$FS_SPACE $FSYS" >> $TMPFILE2 
            echo "`date +'%D_%T'` :Total space requirement : $TOT_SP MB" >> $SCRIPTLOG
            if [[ $DEBUG = 1 ]]; then
                echo "FILE System $FSYS : required space $FS_SPACE MB"
                echo "Total space requirement : $TOT_SP MB"
            fi
        done  
        if [[  -s $TMPFILE2 ]]; then      
            FINAL_FS=`cat $TMPFILE2|  sort -n | awk '{print $2}' `
        fi
        echo "`date +'%D_%T'` :Sorted FILE SYSTEMS according to the size : $FINAL_FS" >> $SCRIPTLOG
        if [[ $DEBUG = 1 ]]; then
            echo "Sorted FILE SYSTEMS according to the size : $FINAL_FS"
        fi
        rm -f $TMPFILE
        rm -f $TMPFILE2
        factor=$EP2_PERCENT_OF_FILES_DIRTY
        factor=`echo "scale=2 ; 1 + ${factor:=1} / 100" | bc`
        SPACE=`echo "scale=2 ; $TOT_SP * $factor" | bc`
        echo "`date +'%D_%T'` :EP2_PERCENT_OF_FILES_DIRTY = $EP2_PERCENT_OF_FILES_DIRTY " >> $SCRIPTLOG
        echo "`date +'%D_%T'` :factor = $factor " >> $SCRIPTLOG
        echo "`date +'%D_%T'` :Space requirement considering EP2_PERCENT_OF_FILES_DIRTY : $SPACE MB" >> $SCRIPTLOG
        if [[ $DEBUG = 1 ]]; then
            echo "EP2_PERCENT_OF_FILES_DIRTY = $EP2_PERCENT_OF_FILES_DIRTY "
            echo "factor = $factor "
            echo "Space requirement considering EP2_PERCENT_OF_FILES_DIRTY : $SPACE MB"
        fi
        SPACE=`echo "scale=0; $SPACE / 1" | bc`
        echo "`date +'%D_%T'` :Rounding off the SPACE required for comparison : $SPACE MB" >> $SCRIPTLOG
        if [[ $DEBUG = 1 ]]; then
            echo "Rounding off the SPACE required for comparison : $SPACE MB"
        fi
#        TMP_SPACE=`echo "scale=2 ; $TMP_SPACE * $factor" | bc`
        check_space
        if [[ $OS = "SunOS" ]] ; then
            EP2_NICEVALUE_COLLECTOR_ANALYZER=$EP2_NICEVALUE_COLLECTOR_ANALYZER; export EP2_NICEVALUE_COLLECTOR_ANALYZER  #v1.3
            EP2_ANALYZER_PAUSE_COUNT=$EP2_ANALYZER_PAUSE_COUNT;export EP2_ANALYZER_PAUSE_COUNT   #v1.3
            EP2_ANALYZER_PAUSE_TIME=$EP2_ANALYZER_PAUSE_TIME;export EP2_ANALYZER_PAUSE_TIME      #v1.3
            EP2_PERCENT_OF_FILES_DIRTY=$EP2_PERCENT_OF_FILES_DIRTY; export EP2_PERCENT_OF_FILES_DIRTY   #v1.3
	    EP2_ANALYZER_PERREC_SLEEP=$EP2_ANALYZER_PERREC_SLEEP; export EP2_ANALYZER_PERREC_SLEEP    #v1.3
            EP2_COMPRESSION_PGM=$EP2_COMPRESSION_PGM; export EP2_COMPRESSION_PGM
            EARLIEST_COLLECTOR_START=$EARLIEST_COLLECTOR_START; export EARLIEST_COLLECTOR_START
            LATEST_COLLECTOR_START=$LATEST_COLLECTOR_START; export LATEST_COLLECTOR_START
            EARLIEST_ANALYZER_START=$EARLIEST_ANALYZER_START; export EARLIEST_ANALYZER_START
            LATEST_ANALYZER_START=$LATEST_ANALYZER_START;  export LATEST_ANALYZER_START
            RECIPIENT=$RECIPIENT;  export RECIPIENT
            CPU_IDLE_MIN=$CPU_IDLE_MIN; export CPU_IDLE_MIN
            EP2_SKIP_CSVZIP=$EP2_SKIP_CSVZIP; export EP2_SKIP_CSVZIP
            EP2_EXCLUDED_HOME_DIRS=$EP2_EXCLUDED_HOME_DIRS; export EP2_EXCLUDED_HOME_DIRS
        else
            export EP2_NICEVALUE_COLLECTOR_ANALYZER=$EP2_NICEVALUE_COLLECTOR_ANALYZER
            export EP2_ANALYZER_PAUSE_COUNT=$EP2_ANALYZER_PAUSE_COUNT
            export EP2_ANALYZER_PAUSE_TIME=$EP2_ANALYZER_PAUSE_TIME
            export EP2_PERCENT_OF_FILES_DIRTY=$EP2_PERCENT_OF_FILES_DIRTY
	    export EP2_ANALYZER_PERREC_SLEEP=$EP2_ANALYZER_PERREC_SLEEP
            export EP2_COMPRESSION_PGM=$EP2_COMPRESSION_PGM
            export EARLIEST_COLLECTOR_START=$EARLIEST_COLLECTOR_START
            export LATEST_COLLECTOR_START=$LATEST_COLLECTOR_START
            export EARLIEST_ANALYZER_START=$EARLIEST_ANALYZER_START
            export LATEST_ANALYZER_START=$LATEST_ANALYZER_START
            export RECIPIENT=$RECIPIENT
            export CPU_IDLE_MIN=$CPU_IDLE_MIN
            export EP2_SKIP_CSVZIP=$EP2_SKIP_CSVZIP
            export EP2_EXCLUDED_HOME_DIRS=$EP2_EXCLUDED_HOME_DIRS
        fi
        echo "`date +'%D_%T'` :Following are the details of environmental variables after exporting.. " >> $SCRIPTLOG
        echo "`env`" >> $SCRIPTLOG
        CNT_AN=0
        cd $PWD_SCRIPT
	for FSYS in $FINAL_FS; do
         collector_run="false"
         analyzer_run="false"
         T_EARLIEST_COLLECTOR_START="$EARLIEST_COLLECTOR_START"
         T_LATEST_COLLECTOR_START="$LATEST_COLLECTOR_START"
         T_EARLIEST_ANALYZER_START="$EARLIEST_ANALYZER_START"
         T_LATEST_ANALYZER_START="$LATEST_ANALYZER_START"
         CHANGE_COLLECTOR_CUR_TIME="FALSE"
         if [[ $T_EARLIEST_COLLECTOR_START -gt $T_LATEST_COLLECTOR_START  ]]; then
             if [[ $T_EARLIEST_COLLECTOR_START -gt 1200 ]]; then
                 T_ORIG_LATEST_COLLECTOR_START=$T_LATEST_COLLECTOR_START
                 T_LATEST_COLLECTOR_START=`expr $T_LATEST_COLLECTOR_START + 2400`
                 CHANGE_COLLECTOR_CUR_TIME="TRUE"
             fi
         fi
         while [[ $collector_run = "false" ]]; do
           CURRTIME=`date +%H%M`
           if [[ $CURRTIME -ge 0000 ]] && [[ $CURRTIME -lt $T_ORIG_LATEST_COLLECTOR_START ]] && [[ $CHANGE_COLLECTOR_CUR_TIME = "TRUE" ]] ; then
             CURRTIME=`expr $CURRTIME + 2400`
           fi

           if [[ $T_EARLIEST_COLLECTOR_START -gt 0 ]] && [[ T_LATEST_COLLECTOR_START -gt 0 ]]; then
		if [[ $CURRTIME -ge $T_EARLIEST_COLLECTOR_START ]] && [[ $CURRTIME -lt $T_LATEST_COLLECTOR_START ]]; then
            		collector_run="true"
		else	
            		echo "`date +'%D_%T'` :Collector in sleep mode for 15 min" | tee -a  $SCRIPTLOG
            		sleep 900
            		echo "`date +'%D_%T'` :Collector sleep over" | tee -a  $SCRIPTLOG
                        collector_run="false"
            		continue
		fi
           else
            	collector_run="true"
           fi
	  done
          if [[ $DEBUG = 1 ]]; then
               echo "File system $FSYS is being passed to the collector"
	  fi
          ## Calling Collector
          RPTTIME=`date +%H%M%S`
          RPTDATE=`date +%Y%m%d`
          echo "=======================================================================" | tee -a  $SCRIPTLOG
          echo "Started: Collector $collectorname on $RPTDATE at $RPTTIME" | tee -a  $SCRIPTLOG
          echo "=======================================================================" | tee -a  $SCRIPTLOG
          echo "`date +'%D_%T'` :File system $FSYS is being passed to the collector" | tee -a  $SCRIPTLOG 
	  rm -rf $TMP_COL_LIST
          rm -rf $COLL_FILE_LIST_WIP
	  ## Calling collector for each file systems identified.
	  CMD_COLLECTOR="nice -n $EP2_NICEVALUE_COLLECTOR_ANALYZER $COLLECTOR_SCRIPT -n $INODE_SIZE -s $WAIT_TIME -o $TMPLOGS -t $FSYS"
	  if [[ $DEBUG = 1 ]]; then
	      CMD_COLLECTOR="$CMD_COLLECTOR -d "
	  fi				
	  if [[ $VERBOSE = 1 ]]; then 
	      CMD_COLLECTOR="$CMD_COLLECTOR -v"
	  fi
          if [[ $SAFE_RECORD_CHECK = 1 ]]; then
              CMD_COLLECTOR="$CMD_COLLECTOR -nofilter"
              echo "`date +'%D_%T'` :Collector execution chosen with nofilter mode" | tee -a $SCRIPTLOG
          fi
         # echo "Command Collector -> $CMD_COLLECTOR"
          echo "`date +'%D_%T'` :Command Collector -> $CMD_COLLECTOR" | tee -a  $SCRIPTLOG
          if [[ -f $COLLECTOR_SCRIPT ]]; then 
	    $CMD_COLLECTOR
            PIDLIST=$!
            RETCD_COLLECTOR=$?
            echo "`date +'%D_%T'` : Collector Returns $RETCD_COLLECTOR" | tee -a  $SCRIPTLOG
	    if [[ $RETCD_COLLECTOR = 0 ]]; then
              echo "`date +'%D_%T'` : Collector completes collecting information for $FSYS" | tee -a  $SCRIPTLOG
              if [[  -s $TMP_COL_LIST ]]; then
                if [[ $OS = "SunOS" ]] ; then
                  egrep -e '^d|^-' $TMP_COL_LIST | grep -v 'DEAD_BEEF' > $COLL_FILE_LIST_WIP 2>> $SCRIPTLOG
                else
              	  grep -E '^d|^-' $TMP_COL_LIST | grep -v 'DEAD_BEEF' > $COLL_FILE_LIST_WIP  2>> $SCRIPTLOG
                fi
              fi
              if [[  -s $TMP_COL_LOG ]]; then
                  cat $TMP_COL_LOG >> $SCRIPTLOG 2>&1 
              fi
	      rm -rf $TMP_COL_LIST
              rm -rf $TMP_COL_LOG
	    elif [[ $RETCD_COLLECTOR = -1 ]]; then
	      if [[ $DEBUG = 1 ]]; then
              	  echo "Received INT or ABRT or TERM signal while executing collector.. exiting"
	      fi
              echo "Received INT or ABRT or TERM signal while executing collector.. exiting" | tee -a $SCRIPTLOG
	      cat $SCRIPTLOG >> $FINAL_SCRIPTLOG 2>&1
              rm -f $SCRIPTLOG
      	      DeleteTempFiles
              exit -1			
            else
	      cat $SCRIPTLOG >> $FINAL_SCRIPTLOG 2>&1
              rm -f $SCRIPTLOG
              DeleteTempFiles
              exit 1
	    fi
          else
            echo "`date +'%D_%T'` : Collector script missing." | tee -a  $SCRIPTLOG
            exit 1
          fi
          RPTDATE=`date +%Y%m%d`
          RPTTIME=`date +%H%M%S`
          echo "================================================================================" | tee -a  $SCRIPTLOG
          echo "Ended: Collector $collectorname ended for $FSYS on $RPTDATE at $RPTTIME" | tee -a  $SCRIPTLOG
          echo "================================================================================" | tee -a  $SCRIPTLOG
          CHANGE_ANALYZER_CUR_TIME="FALSE"

          if [[ $T_EARLIEST_ANALYZER_START -gt $T_LATEST_ANALYZER_START  ]]; then
              if [[ $T_EARLIEST_ANALYZER_START -gt 1200 ]]; then
                  T_ORIG_LATEST_ANALYZER_START=$T_LATEST_ANALYZER_START
                  T_LATEST_ANALYZER_START=`expr $T_LATEST_ANALYZER_START + 2400`
                  CHANGE_ANALYZER_CUR_TIME="TRUE"
              fi
          fi

          while [[ $analyzer_run = "false" ]] ; do
             CURRTIME=`date +%H%M`
             if [[ $CURRTIME -ge 0000 ]] && [[ $CURRTIME -lt $T_ORIG_LATEST_ANALYZER_START ]] && [[ $CHANGE_ANALYZER_CUR_TIME = "TRUE" ]] ; then
                 CURRTIME=`expr $CURRTIME + 2400`
             fi

             if [[ $T_EARLIEST_ANALYZER_START -gt 0 ]] && [[ T_LATEST_ANALYZER_START -gt 0 ]]; then
           	if [[ $CURRTIME -ge $T_EARLIEST_ANALYZER_START ]] && [[ $CURRTIME -lt $T_LATEST_ANALYZER_START ]]; then
            		analyzer_run="true"
           	else
            		#echo "Analyzer in sleep mode for 15 min."
            		echo "`date +'%D_%T'` : Analyzer in sleep mode for 15 min." | tee -a  $SCRIPTLOG
            		sleep 900
            		#echo "Sleep over"
            		echo "`date +'%D_%T'` : Analyzer sleep over" | tee -a  $SCRIPTLOG
            		analyzer_run="false"
            		continue
		fi
	      else
		analyzer_run="true"
              fi
	
          done
          analyzer_run="false"
          while [[ $analyzer_run = "false" ]] ; do
	    	IDFLDPOS=`vmstat 30 1 | tail -2 | head -1 | awk '{ for(i=NF;i>0;i--){ if ($i == "id") print i; }}'`
		if [[ -z $IDFLDPOS ]]; then
            		case $OS in
              			AIX) CPU_USE_MIN=`vmstat 30 1 | tail -1 | awk '{print $16}'`
                   		;;
              			Linux) CPU_USE_MIN=`vmstat 30 1 | tail -1 | awk '{print $15}'`
                     		;;
              			SunOS) CPU_USE_MIN=`vmstat 30 1 | tail -1 | awk '{print $22}'`
                     		;;
              			HP-UX) CPU_USE_MIN=`vmstat 30 1 | tail -1 | awk '{print $18}'`
                     		;;
              			*) CPU_USE_MIN=`vmstat 30 1 | tail -1 | awk '{print $15}'`
                     		;;
            		esac
		else
			CPU_USE_MIN=`vmstat 30 1 | tail -1 |  awk '{ print $FLDPOS;}' FLDPOS=$IDFLDPOS`
		fi

		if [[ $CPU_USE_MIN = 0 ]]; then

			if [[ $DEBUG = 1 ]]; then
				echo "CPU_USE_MIN = $CPU_USE_MIN, check CPU usage with vmstat 60 2"
			fi

                	IDFLDPOS=`vmstat 60 2 | tail -3 | head -1 | awk '{ for(i=NF;i>0;i--){ if ($i == "id") print i; }}'`
			if [[ -z $IDFLDPOS ]]; then
        	    		case $OS in
              				AIX) CPU_USE_MIN=`vmstat 60 2 | tail -1 | awk '{print $16}'`
                   			;;
              				Linux) CPU_USE_MIN=`vmstat 60 2 | tail -1 | awk '{print $15}'`
                     			;;
              				SunOS) CPU_USE_MIN=`vmstat 60 2 | tail -1 | awk '{print $22}'`
                     			;;
              				HP-UX) CPU_USE_MIN=`vmstat 60 2 | tail -1 | awk '{print $18}'`
                     			;;
              				*) CPU_USE_MIN=`vmstat 60 2 | tail -1 | awk '{print $16}'`
                     			;;
            			esac
			else
                            	CPU_USE_MIN=`vmstat 60 2 | tail -1 |  awk '{ print $FLDPOS;}' FLDPOS=$IDFLDPOS`
                        fi
		fi

		if [[ $DEBUG = 1 ]]; then
			echo "IDFLDPOS=$IDFLDPOS"
			echo "CPU_USE_MIN=$CPU_USE_MIN"
			echo "CPU_IDLE_MIN=$CPU_IDLE_MIN";
		fi

            if [[ $CPU_USE_MIN -lt $CPU_IDLE_MIN ]]; then
               # echo "Analyzer in sleep mode for 30 min."
                echo "`date +'%D_%T'` : CPU_IDLE_MIN =  $CPU_IDLE_MIN and CPU USAGE VALUE = $CPU_USE_MIN ." | tee -a  $SCRIPTLOG
                echo "`date +'%D_%T'` : Analyzer in sleep mode for 30 min." | tee -a  $SCRIPTLOG
                sleep 1800
                #echo "Sleep over"
                echo "`date +'%D_%T'` : Analyzer sleep over" | tee -a  $SCRIPTLOG
                analyzer_run="false"
                continue
            else
                analyzer_run="true"
            fi
          done 
	    if [[ -f $COLL_FILE_LIST_WIP ]] ; then 
                CURRTIME=`date +%H%M`
                #echo "CURRTIME=$CURRTIME"
                ## Calling Analyzer
                if [[ $CNT_AN -gt 0 ]]; then
  	            CMD_ANALYZER="nice -n $EP2_NICEVALUE_COLLECTOR_ANALYZER $ANALYZER_SCRIPT -f $COLL_FILE_LIST_WIP -o $TMPLOGS -l"
                else
                  if [[ $SKIPCHECK = 1 ]]; then
                    CMD_ANALYZER="nice -n $EP2_NICEVALUE_COLLECTOR_ANALYZER $ANALYZER_SCRIPT -f $COLL_FILE_LIST_WIP -o $TMPLOGS -l"
                  else
                    CMD_ANALYZER="nice -n $EP2_NICEVALUE_COLLECTOR_ANALYZER $ANALYZER_SCRIPT -f $COLL_FILE_LIST_WIP -o $TMPLOGS "
                  fi
                fi
                CNT_AN=`expr $CNT_AN + 1`
            else
                echo "`date +'%D_%T'` :File System is clean. Continuing for next file system if any." | tee -a  $SCRIPTLOG
                cat $SCRIPTLOG >> $FINAL_SCRIPTLOG 2>&1
                rm -f $SCRIPTLOG
                DeleteTempFiles
                if [[ $DEBUG = 1 ]]; then
                    echo "File System is clean. Continuing for next file system if any."
                fi
                continue
            fi
            if [[ $DEBUG = 1 ]]; then
	        echo "Calling Analyzer to process the filelist generated by the Collector"
	        CMD_ANALYZER="$CMD_ANALYZER -d "
            fi				
            if [[ $ORIGCHECK = 1 ]]; then
                CMD_ANALYZER="$CMD_ANALYZER -j "
            fi
	    if [[ $EXTRAVERBOSE = 1 ]]; then
	        CMD_ANALYZER="$CMD_ANALYZER -x "
            fi
	    if [[ $VERBOSE = 1 ]]; then 
	        CMD_ANALYZER="$CMD_ANALYZER -v "
	    fi
	    if [[ $ALTERNATE_GECO != "" ]]; then 
	        CMD_ANALYZER="$CMD_ANALYZER -a $ALTERNATE_GECO "
	    fi
	    if [[ $CHECK_CUSTOMERID = 1 ]]; then
	        CMD_ANALYZER="$CMD_ANALYZER -c "
	    fi
            if [[ -s $EXP_FILE  ]]; then
	        CMD_ANALYZER="$CMD_ANALYZER -e $EXP_FILE "
            else
                rm -f $EXP_FILE >> $FINAL_SCRIPTLOG 2>&1
            fi
	    if [[ $GECOS_TYPE != "" ]]; then
	        CMD_ANALYZER="$CMD_ANALYZER -g $GECOS_TYPE "
	    fi
            if [[ $IBM_STR = 1 ]] ; then
	        CMD_ANALYZER="$CMD_ANALYZER -i "
	    fi
            if [[ $MERGEMODE = 1 ]] ; then
	        CMD_ANALYZER="$CMD_ANALYZER -m "
	    fi
            if [[ $LIKE_IBM_ID = 1 ]]; then
	        CMD_ANALYZER="$CMD_ANALYZER -u "
	    fi
	    if [[ $DISABLE_INSECURE_PATH = 1 ]]; then
	        CMD_ANALYZER="$CMD_ANALYZER -p "
	    fi
	    if [[ $SH_VERSION = 1 ]]; then
	        CMD_ANALYZER="$CMD_ANALYZER -V"
	    fi
            RPTDATE=`date +%Y%m%d`
            RPTTIME=`date +%H%M%S`
            echo "=======================================================================" | tee -a  $SCRIPTLOG
            echo "Started: Analyzer $analyzername for $FSYS on $RPTDATE at $RPTTIME" | tee -a  $SCRIPTLOG
            echo "=======================================================================" | tee -a  $SCRIPTLOG
            ## Run the Analyzer		
            if [[ $DEBUG = 1 ]]; then
                echo "Command Analyzer ->  $CMD_ANALYZER"
            fi
            echo "`date +'%D_%T'` :Command Analyzer ->  $CMD_ANALYZER" | tee -a  $SCRIPTLOG 
            if [[ -f $ANALYZER_SCRIPT ]];then 
              $CMD_ANALYZER 
              RETCD_ANALYZER=$?
              # echo "PIDLIST of analyzer $PIDLIST" 
              PIDLIST=$!
              rm -rf $EXP_FILE
              echo "`date +'%D_%T'` :Return Code for ANALYZER $RETCD_ANALYZER " >> $SCRIPTLOG     
              if [[ $DEBUG = 1 ]]; then
                echo "Return Code for ANALYZER $RETCD_ANALYZER "
              fi
              RPTDATE=`date +%Y%m%d`
              RPTTIME=`date +%H%M%S`
              FILESYS=$FSYS
              MAIL_CNT=""
              CLN_RUN=""
	      ## Handling of error code for Analyzer execution goes here
	      if [[ $RETCD_ANALYZER = 0 ]]; then
	        echo "`date +'%D_%T'` :Analyzer successfully executed" | tee -a  $SCRIPTLOG
                rm -rf $ANALYZER_LOGDIR/EP2_Analyzer_*.ep2tmp*
                cat $ANALYZER_LOGDIR/EP2_Analyzer_*.LOG >> $SCRIPTLOG  2>&1
                if [[ $? = 0 ]]; then
                    rm -rf $ANALYZER_LOGDIR/EP2_Analyzer_*.LOG
                fi
                FSYS=`echo $FSYS| sed 's/\//_/g'`
                FSYS=`echo $FSYS| sed 's/ /_/g'`
                ANALYZER_OP=`ls $ANALYZER_LOGDIR/EP2_Analyzer_*|awk -F'/' '{print $NF}' `
                mv $ANALYZER_LOGDIR/EP2_Analyzer_* $ANALYZER_LOGDIR/"$FSYS"_"$ANALYZER_OP"
                CLN_RUN=`grep "CONGRATULATIONS! CLEAN RUN" $ANALYZER_LOGDIR/* 2>>$SCRIPTLOG`
                mv $ANALYZER_LOGDIR/* $TMPLOGS/. 2>>$SCRIPTLOG
                if [[ $? = 0 ]]; then
                    rm -rf $ANALYZER_LOGDIR 2>>$SCRIPTLOG
                fi
                if [[ ! -z $CLN_RUN ]]; then
                    MAIL_CNT="No deviations were found for filesystem $FILESYS."
                else
                    RESULT_CSV=`ls $TMPLOGS/*CSV* | grep "$FSYS"_"EP2" `
                    MAIL_CNT="The deviation report for filesystem $FILESYS is located in $RESULT_CSV "
                fi
              fi
              if [[ $RETCD_ANALYZER = 2 ]]; then
                if [[ $DEBUG = 1 ]]; then
                    echo "Exported filesystem list file is missing by the Analyzer"
                fi
                cat $ANALYZER_LOGDIR/EP2_Analyzer_*.LOG* >> $SCRIPTLOG 2>&1
                MAIL_CNT="Exported filesystem list file is missing by the Analyzer."
              fi
	      if [[ $RETCD_ANALYZER = 3 ]]; then
                if [[ $DEBUG = 1 ]]; then
                    echo "Missing file generated by collector"
                fi
                echo "`date +'%D_%T'` :Missing file generated by collector" >> $SCRIPTLOG
                cat $ANALYZER_LOGDIR/EP2_Analyzer_*.LOG* >> $SCRIPTLOG 2>&1
                MAIL_CNT="Missing file generated by collector"
              fi
	      if [[ $RETCD_ANALYZER = 4 ]]; then
                if [[ $DEBUG = 1 ]]; then
	           echo "Invalid option provided to the Analyzer"
                fi
                echo "`date +'%D_%T'` :Invalid option provided to the Analyzer" >> $SCRIPTLOG
                cat $ANALYZER_LOGDIR/EP2_Analyzer_*.LOG* >> $SCRIPTLOG 2>&1
                MAIL_CNT="Invalid option provided to the Analyzer"
              fi
              if [[ $RETCD_ANALYZER != 0 ]] && [[ $RETCD_ANALYZER != 2 ]] && [[ $RETCD_ANALYZER != 3 ]] && [[ $RETCD_ANALYZER != 4 ]]; then
                echo "`date +'%D_%T'` :Unknown error Return Code from analyzer: $RETCD_ANALYZER" | tee -a $SCRIPTLOG
                cat $ANALYZER_LOGDIR/EP2_Analyzer_*.LOG* >> $SCRIPTLOG 2>&1
                rm -rf $ANALYZER_LOGDIR 2>> $SCRIPTLOG
                cat $SCRIPTLOG >> $FINAL_SCRIPTLOG  2>&1
                rm -f $SCRIPTLOG
                DeleteTempFiles
                exit 1
	      fi
              OWNER_FS=`ls -ld $FILESYS | awk '{print $3}'`
              echo "=======================================================================" | tee -a $SCRIPTLOG
              echo "Ended: Analyzer $analyzername for $FILESYS on $RPTDATE at $RPTTIME" | tee -a $SCRIPTLOG
              echo "=======================================================================" | tee -a $SCRIPTLOG
              if [[ ! -z $CLN_RUN ]]; then
                  if [[ $OWNER_FS != "root" ]]; then
                      echo $MAIL_CNT | mail -s "EP2 completed analysis of $FILESYS($OWNER_FS) on $HOST with no violations." $RECIPIENT  2>> $SCRIPTLOG
                  else
                      echo $MAIL_CNT | mail -s "EP2 completed analysis of $FILESYS on $HOST with no violations." $RECIPIENT  2>> $SCRIPTLOG
                  fi
              else
                  if [[ $OWNER_FS != "root" ]]; then
                      echo $MAIL_CNT | mail -s "EP2 completed analysis of $FILESYS($OWNER_FS) on $HOST with violations." $RECIPIENT  2>> $SCRIPTLOG
                  else
                      echo $MAIL_CNT | mail -s "EP2 completed analysis of $FILESYS on $HOST with violations." $RECIPIENT  2>> $SCRIPTLOG
                  fi
              fi
              echo "`date +'%D_%T'` : Mail sent to $RECIPIENT for $FILESYS" >> $SCRIPTLOG
           else
              echo "`date +'%D_%T'` : $ANALYZER_SCRIPT does not exist" | tee -a $SCRIPTLOG
              exit 2
           fi 
	done
    else
        echo "`date +'%D_%T'` :ERROR: Mount point file, '$MOUNT_POINT', does not exist" >> $SCRIPTLOG
        if [[ $DEBUG = 1 ]]; then
            echo "Mount point file, '$MOUNT_POINT', does not exist"
        fi
    fi
}


################
# MAIN PROGRAM #
################

#########################
# Variables Definitions #
#########################
umask 077			# make sure all output files are only editable by the creating id (permissions 700)
ln -s /bin/basename /usr/bin/basename 2>/dev/null
pn=$(/bin/basename $0)
PID="$$"

##Start: Update the following values if versions and scriptnames are changed.

version="V2.0.8"
collectorname="EP2_collector_V2.0.2.pl"
analyzername="EP2_Analyzer_V2.0.8.pl"
collectorversion="V2.0.2"
analyzerversion="V2.0.8"

##End

RPTDATE=`date +%Y%m%d`		# yyyymmdd format
RPTTIME=`date +%H%M%S`

# cannot use hostname -s with solaris so use hostname and remove the additional server specifications if they are there
HOST=`hostname`
HOST=`echo $HOST | awk -F"." '{print $1}' `

GECOS_TYPE="URT"
VALID_GECOS=" URT ITIM ORIG "
ALTERNATE_GECO=""
ESTIMATOR_INODE_MULTIPLIER=""
INODE_SIZE=""
IBM_STR=""
MERGEMODE=""
OS=`uname -s`
OUTNEW=""
if [[ $OS = "SunOS" ]]; then
    OUTDIR="/var/tmp"  # directory for output csv files if not overriden by user with flag "o".
    TMPDIR="/var/tmp"  # directory for temp files
else
    OUTDIR="/tmp"
    TMPDIR="/tmp"
fi		
DISABLE_INSECURE_PATH=""
#WORLD_READ_WARNING=""
NUM_DAY=""
SPACE=""
SH_VERSION=""
LIKE_IBM_ID=""
WAIT_TIME=""
ALWAYS_CHECK_FILE=""
DEBUG=0
VERBOSE=0
#SKIPISCSI=0
SAFE_RECORD_CHECK=0
MERGEMODE=0
ORIGCHECK=0
EXTRAVERBOSE=0
SKIPCHECK=0
PWD_SCRIPT=`dirname $0`

case $OS in 
	Linux) 	MOUNT_POINT="/etc/fstab"
	        ;;

	AIX)	MOUNT_POINT="/etc/filesystems"
	        ;;

	SunOS)	MOUNT_POINT="/etc/vfstab"
	        ;;

	HP-UX)	MOUNT_POINT="/etc/fstab"
	        ;;

	*)	MOUNT_POINT="/etc/fstab"
	    ;;
esac

############################################################################
# Options selection procedure
############################################################################

opt="$1"
while getopts "cdhlimpuVjvxra:b:g:o:t:w:s:" opt; do
        case "$opt" in
        s)  if [[ -z $OPTARG ]]; then
                echo ""
                echo "USAGE ERROR : User defined value of inode multiplier (DEFAULT - 225) must be provided when option 's' is used"
                echo ""
                show_use
                exit 1
            else
                ESTIMATOR_INODE_MULTIPLIER=$OPTARG
            fi
            ;;
        r)  SAFE_RECORD_CHECK=1 ;;
		a)  if [[ -z $OPTARG ]]; then
                echo ""
                echo "USAGE ERROR : Alternate GECOS TYPE must be provided when option 'a' is used"
                echo ""
                show_use
                exit 1
            else
                ALTERNATE_GECO=$OPTARG
            fi
            ;;
			
        b)  if [[ -z $OPTARG ]]; then
		echo ""
                echo "USAGE ERROR : A pause after a configurable number of inodes have been gathered " 
                echo "(default value 200 inodes)must be provided when option 'b' is used"
		echo ""
		show_use
		exit 1
	    else 
	        INODE_SIZE=$OPTARG
            fi
            ;;
			
	c)  CHECK_CUSTOMERID=1 ;; 	
	d)  DEBUG=1 ;;
        l)  SKIPCHECK=1 ;;
        j)  ORIGCHECK=1 ;;
	g)  if [[ -z $OPTARG ]]; then
		echo ""
                echo "USAGE ERROR : GECOS TYPE must be provided when option 'g' is used"
                echo "URT, ITIM, ORIG (Original IBM Gecos layout) will be processed by GECOS customer type"
                echo "All other GECOS specifications will process all ids as customer ids"
                echo ""
                show_use
                exit 1
            else
                GECOS_TYPE=`echo $OPTARG | tr '[:lower:]' '[:upper:]'`
		VALID=`echo "$VALID_GECOS" | grep " $GECOS_TYPE " `
		if [[ -z $VALID ]]; then
	            echo ""
		    echo "USAGE ERROR : INVALID GECOS TYPE '$GECOS_TYPE' provided. Use one of the following or use the -i flag instead"
                    echo " - URT, ITIM, ORIG (Original IBM Gecos layout) will be processed by GECOS customer type"
                    echo " - for all other GECOS specifications, use the -i flag specifying an ibm identifier string instead"
                    echo ""
                    show_use
                    exit 1
		fi
            fi
            ;;
        h)  show_use; exit 0 ;;
	i)  IBM_STR=1  ;;
		 
        m)  MERGEMODE=1 
	    echo "MERGEMODE is ON"
	    ;;
               
	o)  if [[ -z $OPTARG ]]; then
                echo "USAGE ERROR : Script output directory name must be provided when option 'o' is used"
                echo ""
                show_use
                exit 1
            else
                OUTDIR=$OPTARG
		OUT_NEW=1
            fi;;

	p)  DISABLE_INSECURE_PATH=1 ;;
	
	t)  if [[ -z $OPTARG ]]; then
                echo "USAGE ERROR : The amount of space in MB required for output must be provided when option 't' is used"
                echo ""
                show_use
                exit 1
            else
		SPACE=$OPTARG
	    fi ;;

	u)  LIKE_IBM_ID=1
	    ;;

        V)  show_version
	    SH_VERSION=1
	    exit 0 
	    ;;
        v)  VERBOSE=1 
	    echo "VERBOSE is ON"
	    ;;
	w)  if [[ -z $OPTARG ]]; then
                echo $OPTARG - hh
                echo "USAGE ERROR : wait time between batches of inodes must be provided in microseconds when option 'w' is used"
		echo ""
                show_use
                exit 1
            else
		WAIT_TIME=$OPTARG
	    fi
            ;;
			
        x)  EXTRAVERBOSE=1 
	    VERBOSE=1
            echo "VERBOSE is ON"
	    echo "EXTRAVERBOSE is ON"
	    ;;
        ?)  echo "$pn: Option $1 not recognized, aborting command"
            echo ""
            show_use
            exit 1 ;;
        esac
done
echo ""

TMPLOGS="$OUTDIR/$pn.files/$RPTDATE$RPTTIME"
SCRIPTLOG="$TMPLOGS/$pn.$HOST.$RPTDATE$RPTTIME.LOG.WIP"
FINAL_SCRIPTLOG="$TMPLOGS/$pn.$HOST.$RPTDATE$RPTTIME.LOG"
FSYS=""
if [[ ! -d $OUTDIR ]]; then
    mkdir -p $OUTDIR
fi
if [[ ! -d $TMPLOGS ]]; then
    mkdir -p $TMPLOGS
fi

############################################################################
# Start event logging.                                                     #
############################################################################
echo "=======================================================================" >> $SCRIPTLOG
echo "Started: $pn on $RPTDATE at $RPTTIME" >> $SCRIPTLOG
echo "=======================================================================" >> $SCRIPTLOG

LOCAL_OVERRIDE=`ls $PWD_SCRIPT/ep2.overrides.local.V* 2>> $SCRIPTLOG | grep -vi SAMPLE | sort | tail -1`
STANDARD_OVERRIDE=`ls $PWD_SCRIPT/ep2.overrides.standard.V* 2>> $SCRIPTLOG | grep -vi SAMPLE | sort | tail -1`
OVERRIDE_FILES="$LOCAL_OVERRIDE $STANDARD_OVERRIDE"
CONFIG_FILE=`ls $PWD_SCRIPT/EP2.Config.V* 2>> $SCRIPTLOG | sort | tail -1`

####################
# Locale detection #
####################
# Below code will try to detect if there is locale installed for C or any C variant and will set it up in script.
# Systems without locale or with ls not dependant of locale will have unified output either way.

# test if we even have locale command
locale -a >/dev/null  2>&1;
if [ $? -eq 0 ]; then
    LOCALE_TO_SET='';
    # test if generic C is available
    if [[ $(locale -a | grep '^C$') = 'C' ]]; then
	LOCALE_TO_SET='C';
    else
	LOCALE_TO_SET=$(locale -a | grep '^C' | head -n 1);
    fi;
    # check if we even have something
    if [[ "$LOCALE_TO_SET" != '' ]]; then
	if [[ $DEBUG = 1 ]]; then
	    echo "Setting up locale to detected value: $LOCALE_TO_SET";
	fi;
	export LANG=$LOCALE_TO_SET;
	export LC_CTYPE=$LOCALE_TO_SET;
	export LC_NUMERIC=$LOCALE_TO_SET;
	export LC_TIME=$LOCALE_TO_SET;
	export LC_COLLATE=$LOCALE_TO_SET;
	export LC_MONETARY=$LOCALE_TO_SET;
	export LC_MESSAGES=$LOCALE_TO_SET;
	export LC_PAPER=$LOCALE_TO_SET;
	export LC_NAME=$LOCALE_TO_SET;
	export LC_ADDRESS=$LOCALE_TO_SET;
	export LC_TELEPHONE=$LOCALE_TO_SET;
	export LC_MEASUREMENT=$LOCALE_TO_SET;
	export LC_IDENTIFICATION=$LOCALE_TO_SET;
	export LC_ALL=$LOCALE_TO_SET;
    else
	if [[ $DEBUG = 1 ]]; then
	    echo "Could not find correct locale";
	fi;
    fi;
else
    if [[ $DEBUG = 1 ]]; then
	echo "No locale command. Skipping locale detection.";
    fi;
fi;
# temporary files

TMP_COL_LIST="$TMPLOGS/EP2_Collector_Output.txt"
TMP_COL_LOG="$TMPLOGS/EP2_Collector_log.txt"
COLL_FILE_LIST_WIP="$TMPLOGS/$pn.$PID.collectorlist.wip"
COLL_FILE_LIST="$TMPLOGS/$pn.$PID.collectorlist"
TMPFILE="$TMPLOGS/$pn.$PID.tmpfl"
TMPFILE2="$TMPLOGS/$pn.$PID.tmpfl2"
TMPFILE3="$TMPLOGS/$pn.$PID.tmpfl3"
EXP_FILE="$TMPLOGS/$pn.$PID.exportfile"
COLLECTOR_SCRIPT="$PWD_SCRIPT/$collectorname"
ANALYZER_SCRIPT="$PWD_SCRIPT/$analyzername"
ANALYZER_LOGDIR="$TMPLOGS/tempAnalyzer.files"
#ANALYZER_LOGDIR="$TMPLOGS"
AFLIST=""
NFLIST=""
#CONFIG_FILE="$PWD_SCRIPT/EP2.Config.V3.0"
ESTIMATOR_SCRIPT="$PWD_SCRIPT/EP2_space_estimator_V2.1.sh"
EP2_NICEVALUE_COLLECTOR_ANALYZER=""
EP2_ANALYZER_PAUSE_COUNT=""
EP2_ANALYZER_PAUSE_TIME=""
EP2_PERCENT_OF_FILES_DIRTY=""
EARLIEST_COLLECTOR_START=""
LATEST_COLLECTOR_START=""
EARLIEST_ANALYZER_START=""
LATEST_ANALYZER_START=""
CPU_IDLE_MIN=30
EP2_ANALYZER_PERREC_SLEEP=500000
ISCSI_FS_LIST=""
IS_ISCSI="FALSE"
ISCSI_DEV_LIST=""
ISCSI_FS_LIST=""
#####################################################
# Ensuring that the root user is running the script #
#####################################################

if [[ $OS = "SunOS" ]]; then
   PROGPATH="/usr/ucb"
else
   PROGPATH="/usr/bin"
fi

if [[ -x $PROGPATH/whoami ]]; then
    if [[ `$PROGPATH/whoami` != "root" ]]; then
         echo "Must be root to run,  Exiting.." | tee -a $SCRIPTLOG
         cat $SCRIPTLOG >> $FINAL_SCRIPTLOG  2>&1
         rm -f $SCRIPTLOG
         show_version
         exit 1
    fi
fi
if [[ ! -f $COLLECTOR_SCRIPT ]]; then
   echo "Collector Script $COLLECTOR_SCRIPT is missing.. Exiting " | tee -a $SCRIPTLOG
    cat $SCRIPTLOG >> $FINAL_SCRIPTLOG  2>&1
    rm -f $SCRIPTLOG
   exit 1
fi
if [[ ! -f $ANALYZER_SCRIPT ]]; then
   echo "Analyzer Script $ANALYZER_SCRIPT is missing.. Exiting" | tee -a $SCRIPTLOG
    cat $SCRIPTLOG >> $FINAL_SCRIPTLOG  2>&1
    rm -f $SCRIPTLOG
   exit 1
fi
if [[ ! -f $ESTIMATOR_SCRIPT ]]; then
   echo "Estimator Script $ESTIMATOR_SCRIPT is missing.. Exiting" | tee -a $SCRIPTLOG
    cat $SCRIPTLOG >> $FINAL_SCRIPTLOG  2>&1
    rm -f $SCRIPTLOG
   exit 1
fi
if [[ ! -f $CONFIG_FILE ]]; then
   echo "Configuration file $CONFIG_FILE is missing.. Exiting" | tee -a $SCRIPTLOG
    cat $SCRIPTLOG >> $FINAL_SCRIPTLOG  2>&1
    rm -f $SCRIPTLOG
   exit 1
fi

if [[ ! -d $ANALYZER_LOGDIR ]]; then
    mkdir -p $ANALYZER_LOGDIR
fi
# ensure temp files do not exist
rm -f $LOGS
DeleteTempFiles

###############################
# MAIN PROCESSING BEGINS HERE #
###############################
HIRESMOD=$(perl -e 'eval "use Time::HiRes  qw/usleep/;1" ? print "OK" : print "WARNING";' 2>&1)
if [[ $HIRESMOD = "WARNING" ]] ; then
  if [[ $DEBUG = 1 ]]; then
    echo "`date +'%D_%T'` :WARNING: Missing Perl module Time::Hires" | tee -a $SCRIPTLOG
  fi
    #cat $SCRIPTLOG >> $FINAL_SCRIPTLOG  2>&1
    #rm -f $SCRIPTLOG
fi

FCNTLMOD=$(perl -e 'eval "use Fcntl qw(:mode);1" ? print "OK" : print "ERROR";' 2>&1)
if [[ $FCNTLMOD = "ERROR" ]] ; then
    echo "`date +'%D_%T'` :ERROR: Missing Perl module Fcntl ':mode' : Exiting.." | tee -a $SCRIPTLOG
    cat $SCRIPTLOG >> $FINAL_SCRIPTLOG  2>&1
    rm -f $SCRIPTLOG
    exit -1
fi


#URIMOD=$(perl -e 'eval "use URI::Escape;1" ? print "OK" : print "ERROR";' 2>&1)
#if [[ $URIMOD = "ERROR" ]] ; then
#    echo "`date +'%D_%T'` :ERROR: Missing Perl module URI::Escape : Exiting.." | tee -a $SCRIPTLOG
#    cat $SCRIPTLOG >> $FINAL_SCRIPTLOG  2>&1
#    rm -f $SCRIPTLOG
#    exit -1
#fi

if [[ $INODE_SIZE = "" ]] ; then
    echo "`date +'%D_%T'` :Configurable amount of Inode size is not provided after which a pause can be made, using default value 200" >> $SCRIPTLOG
    if [[ $DEBUG = 1 ]]; then
        echo "Configurable amount of Inode size is not provided after which a pause can be made, using default value 200"
    fi
    INODE_SIZE=200
fi
if [[ $ESTIMATOR_INODE_MULTIPLIER = "" ]] ; then
    echo "`date +'%D_%T'` :Inode Multiplier for estimating space requirement is not provided, using default 225" >> $SCRIPTLOG
    if [[ $DEBUG = 1 ]]; then
        echo "Inode Multiplier for estimating space requirement is not provided, using default 225"
    fi
    ESTIMATOR_INODE_MULTIPLIER=225
fi
if [[ $WAIT_TIME = "" ]] ; then
    echo "`date +'%D_%T'` :Wait time between batches of inodes is not provided, using default value 1000000 microseconds" >> $SCRIPTLOG
    if [[ $DEBUG = 1 ]]; then
        echo "Wait time between batches of inodes is not provided, using default value 1000000 microseconds"
    fi
    WAIT_TIME=1000000
fi
if [[ $DEBUG = 1 ]]; then
    echo "DETAILED OS:`which_OS`" 
    echo "Files in the present directory : `ls -al` "
fi
echo "`date +'%D_%T'` : Processing file systems .... " >> $SCRIPTLOG

checkAlsFiles
checkNevFiles

parse_config
# Check for Iscsi device
Detect_iscsi
if [[ $DEBUG = 1 ]]; then
    echo "`date +'%D_%T'` : OVERRIDE_FILES = $OVERRIDE_FILES"
fi
process_filesystems
DeleteTempFiles

############################################################################
# End event logging.                                                     #
############################################################################
echo "=======================================================================" >> $SCRIPTLOG
echo "Ended: $pn on $RPTDATE at $RPTTIME" >> $SCRIPTLOG
echo "=======================================================================" >> $SCRIPTLOG
cat $SCRIPTLOG >> $FINAL_SCRIPTLOG 2>&1
rm -f $SCRIPTLOG
exit 0

