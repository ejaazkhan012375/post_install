#! /bin/sh
#Install Flexera
# Install script for Flexera 13.1.1-1
# Updated Beacon list as of May 15, 2019

# determining which Flexera Beacon to use
SITE=`echo $(hostname) | cut -c 1-4`
case $SITE in
        caac)      BEACON=caacp50017.us.ad.wellpoint.com;;
        in02)      BEACON=in02p50018.us.ad.wellpoint.com;;
        mom9)      BEACON=mom9pwviss432.us.ad.wellpoint.com;;
        ny0m)      BEACON=ny0mp50013.us.ad.wellpoint.com;;
        ny0r)      BEACON=ny0rp50057.us.ad.wellpoint.com;;
	ca47)	   BEACON=ca47pwviss011.caremore.com;;
	sl01)	   BEACON=sl01pwviss001.us.ad.wellpoint.com;;
	mn02)	   BEACON=win7-flexera.decare.com;;
	mn02dmz)	   BEACON=alto.decare.com;;
        va10|va33)      BEACON=va10pwviss542.us.ad.wellpoint.com;;
        *)      BEACON=va10pwviss542.us.ad.wellpoint.com;;
esac
echo "MGSFT_BOOTSTRAP_DOWNLOAD=http://$BEACON/ManageSoftDL/
MGSFT_BOOTSTRAP_UPLOAD=http://$BEACON/ManageSoftRL/" > mgsft_rollout_response.build

echo "Installing Flexera agent..."
#cd /root/Flexera # (or any other location where the Flexera dir is )
#cd /mnt/post_install/new_build/
cp mgsft_rollout_response.build /var/tmp/mgsft_rollout_response
cp managesoft-13.1.1-1.x86_64.rpm /var/tmp
cp tempconfig.ini /var/tmp

cd /var/tmp

rpm --upgrade --oldpackage --verbose managesoft-13.1.1-1.x86_64.rpm

echo "Sleeping 90 seconds..."
sleep 90

#run the scan

echo "Running Flexera scan..."
/opt/managesoft/bin/mgsconfig -i /var/tmp/tempconfig.ini
/opt/managesoft/bin/ndtrack -t Machine -o Upload=True 
 
echo "Flexera agent installation complete."
exit 0
