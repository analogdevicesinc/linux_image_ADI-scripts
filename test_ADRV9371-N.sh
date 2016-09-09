#!/bin/bash

#rsync the files in the background
rsync -azr -e "ssh -i /root/.ssh/id_rsa" /root/osc-logs test_results@romlx1:~/AD9371-N &

OSC_FORCE_PLUGIN=scpi /usr/local/bin/osc -p /usr/local/lib/osc/profiles/ADRV9371_test.ini 2&>1 > osc_run.txt
rc=$?

# save marker logs & pngs
serial=$(find /sys -name eeprom -size 256c | while read eeprom
do
    ser=$(fru-dump "${eeprom}" -b  2>&1 | awk '/^Serial Number/ {print $NF}')
    if [ ! -z {$ser} ] ; then
	echo ${ser}
        break;
    fi
done;)

if [[ ${rc} -eq 0 ]] ; then
    serial=${serial}-PASS
else
    serial=${serial}-FAIL
fi

# Make sure the directory exists
[[ -d /root/osc-logs ]] || mkdir -p /root/osc-logs

#Is this the first time we tested this board?
if [[ -f /root/osc-logs/AD9371-N-"${serial}"-00.tar.gz ]] ; then
    num=$(ls -l /root/osc-logs/AD9371-N-${serial}* | sort -g | sed -n 1p | awk -F "-" '{print $NF}' | awk -F "." '{print $1}')
    new=`printf "%02d" $(expr $num + 1)`
else
    new='00'
fi
serial=${serial}-${new}

#stick everything into a tar file
tar -czf /root/osc-logs/AD9371-N-"${serial}".tar.gz osc_run.txt markers.log ADRV*.png
rm -f markers.log ADRV*.png osc_run.txt


/sbin/shutdown -h now
