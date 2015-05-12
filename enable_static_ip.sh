#!/bin/bash
#
# Enable a static IP for eth0 (or another interface) on Ubuntu-based setups.
# Note that the wanted IP address should be specified as the first argument;
# otherwise, it defaults to 192.168.0.101. Also, the interface can be specified
# as the second argument if the default (eth0) isn't wanted.
#
# Example usage:
# enable_static_ip.sh [10.66.99.101] [eth1]

set -e

IP_ADDR=${1:-192.168.0.101}
ETH_DEV=${2:-eth0}

if [[ ${UID} -ne 0 ]]; then
	echo "This script must be run as root!"
	exit 1
fi

# disable NetworkManager (assumes the config file hasn't been touched much)
sed -i 's/^managed=false/managed=true/' /etc/NetworkManager/NetworkManager.conf

# set up loopback and add static IP config for ${ETH_DEV} (defaults to eth0)
cat <<-EOF > /etc/network/interfaces
	auto lo
	iface lo inet loopback

	auto ${ETH_DEV}
	iface ${ETH_DEV} inet static
	address ${IP_ADDR}
	netmask 255.255.255.0
EOF

service network-manager restart
