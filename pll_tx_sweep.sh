#!/bin/sh

# find the TX LO generator
for i in $(find /sys -name name)
do
  if [ "`cat $i`" = "adf4351-tx-lpc" ] ; then
     tx_lo_path=$(echo $i | sed 's:/name$::')
  fi
done

if [ -z $tx_lo_path ] ; then
  echo "Can't find adf4351-tx-lpc"
  exit 1
fi

start=$1
end=$2
inc=$3
pause=$4

if [ -z $start ] ; then
  start=400
fi

if [ -z $end ] ; then
  end=4000
fi

if [ -z $inc ] ; then
  inc=5
fi

if [ -z $pause ] ; then
  pause=1
fi

freq_tx() {
  echo $1 > $tx_lo_path/out_altvoltage0_frequency
}

for i in `seq $start $inc $end`;
do
  echo $i
  freq_tx `expr $i \\* 1000000`
  sleep $pause
done
