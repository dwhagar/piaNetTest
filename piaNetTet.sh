#/bin/bash
set -eo pipefail
# Make changes to VPN connection based on network status.

# TODO:  This script currently only cares about WiFi, should put effort into
#        making it work for a wired network as well, just not sure how.

# As a side-nite this script isn't really designed for having no trusted
# networks and thus this could introduce a bug, it has not been tested.

# How do we tell we are online?
PINGTARGET=8.8.8.8
PINGCMD="/sbin/ping -c 1 $PINGTARGET"
INTERFACE=en0

# How do we control PIA?
PIACMD=/usr/local/bin/piactl
PIAREGION=auto

# How do we tell what we're connected to?
AIRPORTCMD=/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport

# Read last network state.
if [[ -f "piaNetTest.data" ]]; then
	LASTNET=$(<piaNetTest.data)
else
	# If the file doesn't exist, create the empty variable.
	LASTNET=""
fi

# A list of networks where PIA is not required.
# This file is required!  It is in the format of one network name per line
# space in network names are not (yet) supported.
if [[ -f piaNetTest.trusted ]]; then
	TRUSTEDNETS=($(cat piaNetTest.trusted|xargs))
else
	echo $(/bin/date)
	echo "WARNING:  Must have a list of trusted networks provided in the file"
	echo "          piaNetTest.trusted or all networks will be untrusted.  To"
	echo "          remove this warning create an empty file named"
	echo "          piaNetTest.trusted which will serve the same purpose as no"
	echo "          file at all."
	TRUSTEDNETS=()
fi

# Read the current network state.
CURRENTNET=$($AIRPORTCMD $INTERFACE -I|grep -v BSSID|grep SSID|xargs|cut -c7-)

if [[ $LASTNET == $CURRENTNET ]]; then
	# Don't do anything if a chance in the network has not occurred.
	exit 0
else
	# Only check on PIA status if a change in the network has occurred.
	PIASTATUS=$($PIACMD get connectionstate)
	
	# Output information for the log.
	echo $(/bin/date)
	echo "Network state has changed since last check."
	echo "Pinging $PINGTARGET to test Internet connectivity..."
	
	$PINGCMD &> /dev/null

	if (( $? > 0)); then
		# Network is offline.
		echo "The Internet is offline."

		# If PIA is connected, disconnect it.
		if [[ $PIASTATUS == "Connected" ]]; then
			echo "Disconnecting from PIA."
			$PIACMD disconnect
		fi
	else
		# Network is online.
		ONTRUSTEDNET=0 # Stet this flag, assume no trusted networks.
	
		echo "The Internet is online and connected to $CURRENTNET."
		
		# If there are no trusted networks, this should not be done.
		if [[ $TRUSTEDNETS != "" ]]; then
			# Find out if we're on a trusted net.
			for i in "${TRUSTEDNETS[@]}"
			do
				if [[ $i == $CURRENTNET ]]; then
					ONTRUSTEDNET=1
					break
				fi
			done
		fi
		
		# Now decide what to do with PIA.
		if (( $ONTRUSTEDNET > 0 )); then
			if [[ $PIASTATUS == "Connected" ]]; then
				echo "Current network is trusted, disconnecting from PIA."
				$PIACMD disconnect
			fi
		else
			if [[ $PIASTATUS == "Disconnected" ]]; then
				echo "Current network is not trusted, connecting to PIA."
				$PIACMD set region $PIAREGION
				$PIACMD connect
			fi
		fi
	fi

	# Store current network state.
	echo $CURRENTNET > piaNetTest.data
fi
