#!/bin/bash
#
# Re-enable the default DHCP-based NetworkManager support. Use to revert the
# static IP configuration performed by the enable_static_ip.sh script.
#
# Example usage:
# enable_dhcp.sh

set -e

if [[ ${UID} -ne 0 ]]; then
	echo "This script must be run as root!"
	exit 1
fi

# revert to original file
if [[ -f /etc/network/interfaces.orig ]]; then
	mv /etc/network/interfaces.orig /etc/network/interfaces
else
	echo "Not enabling DHCP, custom network settings or DHCP configuration already enabled."
	exit 1
fi

# enable DHCP via NetworkManager (assumes the config file hasn't been touched much)
sed -i 's/^managed=true/managed=false/' /etc/NetworkManager/NetworkManager.conf

service network-manager restart
