# script to install Illumio agent
rm -fr /opt/illumio_ven_data/tmp
mkdir -p /opt/illumio_ven_data/tmp
curl "https://illumio.internal.das:8443/api/v6/software/ven/image?pair_script=pair.sh&profile_id=2" -o /opt/illumio_ven_data/tmp/pair.sh --insecure
chmod +x /opt/illumio_ven_data/tmp/pair.sh
/opt/illumio_ven_data/tmp/pair.sh --management-server illumio.internal.das:8443 --activation-code 1322f1b3dd6259a1d50d17062866124398f2aa796439a311077696f3e6f3d2161896deecdba312d11 --insecure
