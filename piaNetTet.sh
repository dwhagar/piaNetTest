#/bin/bash
# Make changes to VPN connection based on network status.

# How do we tell we are online?
PINGTARGET=8.8.8.8
PINGCMD=/sbin/ping
WIFI=en0

# How do we control PIA?
PIACMD=/usr/local/bin/piactl
PIAREGION=auto

# How do we tell what we're connected to?
NETINTCMD=/sbin/route
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
CURRENTINT=$($NETINTCMD get default 2>&1|grep interface|awk '{print $2}')

# If the current network interface is the WiFi interface, proceed with WiFi
# information.  Set a flag so the rest of the script knows what to do.
if [[ $CURRENTINT == $WIFI ]]; then
	# If WiFi is in use, use the network SSID for the current network.
	USINGWIFI=1
	TESTNET=1
	CURRENTNET=$($AIRPORTCMD $WIFI -I|grep -v BSSID|grep SSID|xargs|awk '{print $2}')
elif [[ $CURRENTINT != "" ]]; then
	# If WiFi is not in use but there is an active network connect use the
	# interface for the current network.
	USINGWIFI=0
	TESTNET=1
	CURRENTNET=$CURRENTINT
else
	# If there is no active network interface, assume the system is offline.
	TESTNET=0
fi
	
# Check to see if anything has changed.
if [[ $LASTNET == $CURRENTNET ]]; then
	# Don't do anything if a change in the network has not occurred.
	exit 0
else
	# Output information for the log.
	echo $(/bin/date)
	echo "Network state has changed since last check."
	
	
	if (( $TESTNET > 0 )); then
		# If we're not sure about the network, better ping the Internet.
		echo "Pinging $PINGTARGET to test Internet connectivity..."
	
		$PINGCMD -c 1  $PINGTARGET &> /dev/null
	
		# Is there or isn't there Internet.
		if (( $? > 0 )); then
			echo "The network is online but the Internet is not."
			NONET=1
		else
			NONET=0
		fi
	else
		# If we already know the network is dead, the Internet will be too.
		echo "The network is offline."
		NONET=1
	fi
	
	# Find out what PIA is doing.
	PIASTATUS=$($PIACMD get connectionstate)
	
	# What to do if the Internet is not online.
	if (( $NONET > 0 )); then
		# Network is offline.
		# If PIA is connected, disconnect it.
		if [[ $PIASTATUS == "Connected" || $PIASTATUS == "Connecting" ]]; then
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
			if [[ $PIASTATUS == "Connected" || $PIASTATUS == "Connecting" ]]; then
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
