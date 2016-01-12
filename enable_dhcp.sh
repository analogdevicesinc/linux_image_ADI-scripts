#!/bin/bash
#
# Re-enable the default DHCP-based NetworkManager support. Use to revert the
# static IP configuration performed by the enable_static_ip.sh script.
#
# Example usage:
# enable_dhcp.sh
#
# WARNING: Do not use this script if there is a custom network configuration
# set up in /etc/network/interfaces as it will be overwritten.

set -e

if [[ ${UID} -ne 0 ]]; then
	echo "This script must be run as root!"
	exit 1
fi

echo "Re-enabling DHCP via NetworkManager for all network interfaces"

cat <<-EOF > /etc/network/interfaces
	# interfaces(5) file used by ifup(8) and ifdown(8)
	# Include files from /etc/network/interfaces.d:
	source-directory /etc/network/interfaces.d
EOF

# enable DHCP via NetworkManager (assumes the config file hasn't been touched much)
sed -i 's/^managed=true/managed=false/' /etc/NetworkManager/NetworkManager.conf

service network-manager restart
