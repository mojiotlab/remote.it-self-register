#!/bin/bash
# @author: Moji Jun 26th 2019
#

#---------------------------------------#

# This is a prefix for your device names on remote.it platform. 
# e.g. MY_PI_XXXXX (where XXXXX is the MAC address of network interface on your pi)

PREFIX="MY_PI_"


# The network interface whose MAC address will be used to construct the device name
# ON raspbian the default name for ethernet interface is eth0

NETI="eth0"


# It is recommended to store the email and password in a file named "creds" next to this file with the same flowwing format.
email="email@example.com"		# Remote.it email (Change it!)
password="Remote.itPassword"	# Password (Change it!)


# Uncomment any service that you want to control your pi with

declare -a SERVICES_LIST=(\
"SSH" \
#"NCL" \
#"NXW" \
#"OVPN" \
#"RDP" \
#"SMB" \
#"VNC" \
"HTTP" \
#"HTTPS" \
);

#---------------------------------------#

SCRIPT_PATH=$(dirname $(realpath $0))

#Logs (needs care)
#exec 1>$SCRIPT_PATH/remote.it.log 2>&1
#set -x

#Using Rapi MAC address as device ID
MAC=$(cat /sys/class/net/$NETI/address)
MAC=${MAC//:}
gwId="${MAC^^}"

#----------------------------------#

echo "" > $SCRIPT_PATH/log.txt

#check if the server is accessible
acc=$(curl -Is https://remote.it | head -n 1 | awk '{print $2}')
if [ "$acc" != "200" ]; then
	echo "Remote.it is not accessible"
	echo "Remote.it is not accessible" >> $SCRIPT_PATH/log.txt
	exit
fi

if [ -f $SCRIPT_PATH/done.txt ]; then
	echo "Already registered."
	echo "Already registered." >> $SCRIPT_PATH/log.txt
	exit
fi

#----------------------------------#

if [ -f $SCRIPT_PATH/creds ]; then
	echo "Reading the credentials from an external file [ $SCRIPT_PATH/creds ]."
	echo "Reading the credentials from an external file [ $SCRIPT_PATH/creds ]." >> $SCRIPT_PATH/log.txt
	. $SCRIPT_PATH/creds
fi

USERNAME="$email"
PASSWORD="$password"
AUTHHASH="REPLACE_AUTHHASH"
DEVELOPERKEY=""
MAXSEL=6

. /usr/bin/connectd_library

checkForRoot
checkForUtilities
platformDetection
connectdCompatibility
userLogin
testLogin

#----------------------------------#

registerRemoteIT()
{
	setConnectdPort "$PROTOCOL"
	#configureConnection

	getHardwareID
	echo "Registring the device with HardwareID: $HardwareID and Name: $SNAME"
	echo "Registring the device with HardwareID: $HardwareID and Name: $SNAME" >> $SCRIPT_PATH/log.txt
	installProvisioning
	installStartStop
	fetchUID
	checkUID
	preregisterUID
	registerDevice <<EOF
$SNAME
EOF

}

#----------------------------------#

rtServices=`checkForServices<<EOF
n
EOF`

#----------------------------------#

echo "Registring $PREFIX$gwId" >> $SCRIPT_PATH/log.txt

if [[ $rtServices == *"$PREFIX$gwId"* ]]; then

	echo "Already Registered under name [ $PREFIX$gwId ]" 
	echo "Already Registered under name [ $PREFIX$gwId ]" >> $SCRIPT_PATH/log.txt

else

	PROTOCOL=rmt3
	PORT=65535
	SNAME="$PREFIX$gwId"
	registerRemoteIT

	echo "$error"
	echo "$error" >> $SCRIPT_PATH/log.txt
	
	echo "Done"
	echo "Done" >> $SCRIPT_PATH/log.txt

fi

#--------------------#

for sName in "${SERVICES_LIST[@]}"
do
   . $SCRIPT_PATH/conf/$sName

	echo "Registring $sName..." >> $SCRIPT_PATH/log.txt

	if [[ $rtServices == *"$sName-$PREFIX$gwId"* ]]; then
		
		echo "SSH is already registered [ $sName-$PREFIX$gwId ]"
		echo "SSH is already registered [ $sName-$PREFIX$gwId ]" >> $SCRIPT_PATH/log.txt
		
	else

		#Register the device for SSH
		PROTOCOL=$PROTOCOL
		PORT=$PORT
		SNAME="$sName-$PREFIX$gwId"
		registerRemoteIT

		echo "$error"

		echo "$error" >> $SCRIPT_PATH/log.txt
		echo "Done" >> $SCRIPT_PATH/log.txt

	fi

done

#--------------------#

#Double check if everything is done correctly

rtServices=`checkForServices<<EOF
n
EOF`

echo "" > $SCRIPT_PATH/done.txt
for sName in "${SERVICES_LIST[@]}"
do
	if [[ $rtServices == *"$sName-$PREFIX$gwId"* ]]; then

		echo "$sName-$PREFIX$gwId" >> $SCRIPT_PATH/done.txt
		echo -e "\n\t$sName-$PREFIX$gwId done successfully\n"
	else
		echo "Registring $sName-$PREFIX$gwId Failed!"
		echo "Registring $sName-$PREFIX$gwId Failed!" >> $SCRIPT_PATH/log.txt
	fi

done
