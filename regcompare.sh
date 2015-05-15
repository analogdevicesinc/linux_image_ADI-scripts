#!/bin/bash
#
# Wraps the regdump.sh script allowing for snapshot comparisons between device
# register states. It can be passed the same device name and number of register
# values that regdump.sh accepts since it just passes all arguments on to
# regdump.sh to handle.
#
# If register values change between the two states, a side-by-side diff is
# shown between the previous and current values. Note that the diff currently
# uses static spacing for the columns so make sure the terminal sized properly
# to view the differences without linewraps. If no values change, a message
# relating that no changes occurred is returned instead.
#
# To exit the script at anytime, hit Ctrl-C and the temporary files used to
# store the register value states will be removed.

trap cleanup SIGINT

cleanup() {
	rm -f "${PREVIOUS}" "${CURRENT}"
	echo
	exit
}

echoerr() { echo "$@" 1>&2; }

if [[ ${UID} -ne 0 ]]; then
	echoerr "This script must be run as root!"
	exit 1
fi

if [[ ! -x $(type -P regdump.sh) ]]; then
	echoerr "Can't find the regdump.sh script!"
	exit 1
fi

PREVIOUS=$(mktemp)
CURRENT=$(mktemp)

regdump.sh $@ > "${PREVIOUS}"

while true; do
	read -p "Hit enter to diff registers (and Ctrl-C to quit)"
	regdump.sh $@ > "${CURRENT}"
	CHANGES=$(diff --suppress-common-lines -y "${PREVIOUS}" "${CURRENT}")
	if [[ -z ${CHANGES} ]]; then
		echo "No register value changes"
	else
		printf "%-62s%s\n" "===========" "=========="
		printf "%-62s%s\n" "Previous" "Current"
		printf "%-62s%s\n" "-----------" "----------"
		echo "${CHANGES}"
		printf "%-62s%s\n" "===========" "=========="
	fi
	cp "${CURRENT}" "${PREVIOUS}"
done
