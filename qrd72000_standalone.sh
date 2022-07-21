#!/bin/sh

# ###VARS###
pkgAssetTagFile=/var/.SWDist_Sig/OSPESDAssetTag.pkg
assetTagFile=/var/.SWDist_Sig/OSPESDAssetTag
esdSigFileName=esd.qrd72000_us_0-csplin.exe
swdProduct=qrd72000
swdLang=us
swdCust=csp
swdPkgLvl=0
swdOS=lin
esdStdVer=13
instType=install
iplType=iplno
swdWorkDirMain=/esd/sdwork
swdWorkDir=/esd/sdwork/qrd72000/us/0
swdWorkDirProd=/esd/sdwork/qrd72000
swdDistDir=/esd/swd
imgDir=$swdDistDir/$swdProduct/img/$swdLang
rspDir=$swdDistDir/$swdProduct/rsp/$swdLang
pkgDir=$swdDistDir/$swdProduct/pkg/$swdLang/$swdPkgLvl
swdRebootAfter=n
swdUninstall=n
swdIncludeImg=y
swdBundle=n
swdCleanup=y
swdSpcChk=all
swdOSVerChk=all
swdVerifyChk=all
swdCurVerChk=all
# ###END_VARS###

numargs=$#
stndalnSource=""
if [[ $numargs > 0 ]]
then
   while [[ $1 = * ]] && [[ $1 != "" ]]; do
        param=$1
        param="$(echo "$param" |tr 'a-z' 'A-Z')"
   case $param in
   -K) swdCleanup=n ;;
   -V) swdVerifyChk=y
         swdSpcChk=n
         swdOSVerChk=n
         swdCurVerChk=n ;;
   -R) swdRebootAfter=y ;;
   -U) swdUninstall=y ;;
   -C) swdVerifyChk=n
         swdSpcChk=n
         swdOSVerChk=n
         swdCurVerChk=y ;;
   -S) stndalnSource=$2
         shift ;;
   * ) echo " "
         echo Usage\: $0 \[\-r \| \-u \| \-k \| \-v \| \-c \] \[\-s \<SOURCE DIR\>\]
         echo -r Reboots the machine.
         echo -u Uninstalls the package.
         echo -k Keeps all of the files after installation, does NOT cleanup.
         echo "-v Verification installation check. (Utils package only)"
         echo "-c Current version installation check. (Utils package only)"
         echo -s Source location of unpacked .tar if NOT unpacked in \.
         echo " "
         exit 5
   1 ;;
   esac
   shift
   done
fi
if [[ $stndalnSource != "" ]]; then
   if [[ -d $stndalnSource ]]; then
      swdWorkDirMain=$stndalnSource/esd/sdwork
      swdWorkDir=$stndalnSource/esd/sdwork/$swdProduct/$swdLang/$swdPkgLvl
      swdWorkDirProd=$stndalnSource/esd/sdwork/$swdProduct
      swdDistDir=$stndalnSource/esd/swd
      imgDir=$swdDistDir/$swdProduct/img/$swdLang
      rspDir=$swdDistDir/$swdProduct/rsp/$swdLang
      pkgDir=$swdDistDir/$swdProduct/pkg/$swdLang/$swdPkgLvl
   else
      echo $stndalnSource does NOT exist on the system!
      exit 5
   fi
fi

translation_date=`date +%D`
translation_time=`date +%T`
translation_target=`hostname`

mkdir -p -m 755 /var/.SWDist_Sig 2>&1
cp $pkgDir/$esdSigFileName /var/.SWDist_Sig/$esdSigFileName 2>&1
chmod 775 /var/.SWDist_Sig/$esdSigFileName 2>&1

echo qrd72000_us_0.csplin.install_iplno.spb^^^$translation_target^^^$translation_date^^^$translation_time>> $assetTagFile

if [[ -s $pkgAssetTagFile ]]
then
   rm $pkgAssetTagFile 2>&1
fi


rm $swdWorkDir/$swdProduct*.log >/dev/null 2>&1


if [[ "$instType" = "utils" ]] && [[ "$swdUninstall" = "y" ]]
then
echo ""
echo "ERROR: Utility (utils) packages can only be used for verification purposes, uninstallations are NOT allowed."
exit 5
fi

echo "Invoking package installation script for IBM QRadar DSM V7.2, please wait..."
echo ""
$swdWorkDir/standalone_cscript.sh $swdWorkDir/$swdProduct.env $swdWorkDir $swdDistDir $imgDir $rspDir $pkgDir $instType $swdRebootAfter $swdUninstall esdStdVer^^^$esdStdVer swdSpcChk^^^$swdSpcChk swdOSVerChk^^^$swdOSVerChk swdVerifyChk^^^$swdVerifyChk swdCurVerChk^^^$swdCurVerChk swdBundle^^^$swdBundle swdCleanup^^^$swdCleanup

status=$?

standaloneCWD=`pwd`
echo "RC = $status"

cp $swdWorkDir/$swdProduct*.log $swdWorkDirMain/.
cd $swdWorkDirMain
echo "Local logfile location: $swdWorkDirMain"
if [[ "$status" != 5 ]]
  then
  if [[ "$swdCleanup" != "n" ]]
    then
    rm -r $swdWorkDirProd
  fi
fi
cd $standaloneCWD
exit $status
