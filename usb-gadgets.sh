#!/bin/sh
# SPDX-License-Identifier: MIT

set -e
#set -x

CONFIGFS="/sys/kernel/config"
GADGET="$CONFIGFS/usb_gadget"
#VID="0x0525"
#PID="0xa4a2"
VID="0x1d6b"
PID="0x0104"
SERIAL="fedcba9876543210"
#MANUF=$(hostname)
MANUF="Pawkow"
PRODUCT="Raspberry Pi Gadget"
#CONFIGURATION="ECM + UAC2 + UVC + MIDI"
#CONFIGURATION="UAC2 + UVC + MIDI"
CONFIGURATION="UAC2 x2 + MIDI"
#CONFIGURATION="UAC2"
MAXPOWERMW=250

USBFILE=/root/usbstorage.img

BOARD=$(strings /proc/device-tree/model)

case $BOARD in
	"Renesas Salvator-X board based on r8a7795 ES1.x")
		UDC_USB2=e6590000.usb
		UDC_USB3=ee020000.usb

		UDC_ROLE2=/sys/devices/platform/soc/ee080200.usb-phy/role
		UDC_ROLE2=/dev/null #Not needed - always peripheral
		UDC_ROLE3=/sys/devices/platform/soc/ee020000.usb/role

		UDC=$UDC_USB2
		UDC_ROLE=$UDC_ROLE2
		;;

	"TI OMAP4 PandaBoard-ES")
		UDC=`ls /sys/class/udc` # Should be musb-hdrc.0.auto
		UDC_ROLE=/dev/null # Not needed - peripheral enabled
		;;

	*)
		UDC=`ls /sys/class/udc` # will identify the 'first' UDC
		UDC_ROLE=/dev/null # Not generic
		;;
esac

echo "Detecting platform:"
echo "  board : $BOARD"
echo "  udc   : $UDC"

create_msd() {
	# Example usage:
	#	create_msd <target config> <function name> <image file>
	#	create_msd configs/c.1 mass_storage.0 /root/backing.img
	CONFIG=$1
	FUNCTION=$2
	BACKING_STORE=$3

	if [ ! -f $BACKING_STORE ]
	then
		echo "\tCreating backing file"
		dd if=/dev/zero of=$BACKING_STORE bs=1M count=32 > /dev/null 2>&1
		mkfs.ext4 $USBFILE > /dev/null 2>&1
		echo "\tOK"
	fi

	echo "\tCreating MSD gadget functionality"
	mkdir functions/$FUNCTION
	echo 1 > functions/$FUNCTION/stall
	echo $BACKING_STORE > functions/$FUNCTION/lun.0/file
	echo 1 > functions/$FUNCTION/lun.0/removable
	echo 0 > functions/$FUNCTION/lun.0/cdrom

	ln -s functions/$FUNCTION configs/c.1
	echo "\tOK"
}

create_ecm() {
	# Example usage:
	#       create_ecm <target config> <function name>
	#       create_ecm config/c.1 ecm.0
	CONFIG=$1
	FUNCTION=$2

	# Ethernet
	# https://www.kernel.org/doc/html/latest/usb/gadget-testing.html#ecm-function
	pwd
	echo "	Creating ECM gadget functionality : $FUNCTION"
	mkdir -p functions/$FUNCTION
	# first byte of address must be even
	echo "48:6f:73:74:50:43" > functions/$FUNCTION/host_addr
	echo "42:61:64:55:53:42" > functions/$FUNCTION/dev_addr
	ln -s functions/$FUNCTION configs/c.1
	echo "\tOK"
}

create_midi() {
	# Example usage:
	#       create_midi <target config> <function name>
	#       create_midi config/c.1 midi.0
	CONFIG=$1
	FUNCTION=$2
	midinameshort="$3"
	midinamelong="$4"
	midiportsin="$5"
	midiportsout="$6"

	# MIDI
	# https://www.kernel.org/doc/html/latest/usb/gadget-testing.html#midi-function
	pwd
	echo "	Creating MIDI gadget functionality : $FUNCTION"
	mkdir -p functions/$FUNCTION
	echo "PiMIDI" > functions/$FUNCTION/id
	#echo "1" > functions/$FUNCTION/index
	echo "1" > functions/$FUNCTION/in_ports
	echo "1" > functions/$FUNCTION/out_ports
	echo -n "$midinameshort" > functions/$FUNCTION/shortname
	echo -n "$midinamelong" > functions/$FUNCTION/longname
	#echo "f_midi" > functions/$FUNCTION/shortname
	#echo "MIDI function" > functions/$FUNCTION/longname
	echo "$midiportsin" > functions/$FUNCTION/in_ports
	echo "$midiportsout" > functions/$FUNCTION/out_ports
	ln -s functions/$FUNCTION $CONFIG
	echo "\tOK"
}

create_acm() {
	# Example usage:
	#       create_acm <target config> <function name>
	#       create_acm config/c.1 acm.0
	CONFIG=$1
	FUNCTION=$2

	# ACM serial
	# https://www.kernel.org/doc/html/latest/usb/gadget-testing.html#acm-function
	pwd
	echo "	Creating ACM gadget functionality : $FUNCTION"
	mkdir -p functions/$FUNCTION
	echo -n "Created serial device: /dev/ttyGS"
	cat functions/$FUNCTION/port_num
	ln -s functions/$FUNCTION configs/c.1
	echo "\tOK"
}

create_uac2() {
	# Example usage:
	#       create_uac <target config> <function name>
	#       create_uac config/c.1 uac.0
	CONFIG=$1
	FUNCTION=$2
	uac2name="$3"
	uac2alsadevname="$4"
	uac2alsadevpcmname="$5"
	uac2channelcount="$6"

	# UAC2 audio
	# https://www.kernel.org/doc/html/latest/usb/gadget-testing.html#uac2-function
	pwd
	echo "	Creating UAC gadget functionality : $FUNCTION"
	mkdir -p functions/$FUNCTION
	echo 48000 > functions/$FUNCTION/c_srate
	echo 48000 > functions/$FUNCTION/p_srate
	echo "$uac2name" > functions/$FUNCTION/function_name
	echo "$uac2alsadevname" > functions/$FUNCTION/local_dev_name
	echo "$uac2alsadevpcmname" > functions/$FUNCTION/local_dev_pcm_name
	echo `audio-gadget-helper $uac2channelcount|head -n1|cut -f5 -d' '` > functions/$FUNCTION/c_chmask
	echo `audio-gadget-helper $uac2channelcount|head -n1|cut -f5 -d' '` > functions/$FUNCTION/p_chmask
	#echo `audio-gadget-helper 24|head -n1|cut -f5 -d' '` > functions/$FUNCTION/c_chmask
	#echo `audio-gadget-helper 24|head -n1|cut -f5 -d' '` > functions/$FUNCTION/p_chmask
	echo 2 > functions/$FUNCTION/c_ssize
	echo 2 > functions/$FUNCTION/p_ssize
	#echo 32 > functions/$FUNCTION/req_number
	#echo 80 > functions/$FUNCTION/fb_max
	ln -s functions/$FUNCTION $CONFIG
	echo "\tOK"
}

delete_ecm() {
	# Example usage:
	#	delete_ecm <target config> <function name>
	#	delete_ecm config/c.1 ecm.0
	CONFIG=$1
	FUNCTION=$2

	echo "Removing ECM network interface : $FUNCTION"
	rm -f $CONFIG/$FUNCTION
	rmdir functions/$FUNCTION
	echo "OK"
}

delete_uac2() {
	# Example usage:
	#	delete_uac <target config> <function name>
	#	delete_uac config/c.1 uac.0
	CONFIG=$1
	FUNCTION=$2

	echo "Removing UAC audio interface : $FUNCTION"
	rm -f $CONFIG/$FUNCTION
	rmdir functions/$FUNCTION
	echo "OK"
}

delete_msd() {
	# Example usage:
	#	delete_msd <target config> <function name>
	#	delete_msd config/c.1 uvc.0
	CONFIG=$1
	FUNCTION=$2

	echo "Removing Mass Storage interface : $FUNCTION"
	rm -f $CONFIG/$FUNCTION
	rmdir functions/$FUNCTION
	echo "OK"
}

delete_acm() {
	# Example usage:
	#	delete_acm <target config> <function name>
	#	delete_acm config/c.1 acm.usb0
	CONFIG=$1
	FUNCTION=$2

	echo "Removing ACM serial interface : $FUNCTION"
	rm -f $CONFIG/$FUNCTION
	rmdir functions/$FUNCTION
	echo "OK"
}

delete_midi() {
	# Example usage:
	#	delete_midi <target config> <function name>
	#	delete_midi config/c.1 midi.usb0
	CONFIG=$1
	FUNCTION=$2

	echo "Removing MIDI serial interface : $FUNCTION"
	rm -f $CONFIG/$FUNCTION
	rmdir functions/$FUNCTION
	echo "OK"
}

create_frame() {
	# Example usage:
	# create_frame <function name> <width> <height> <format> <name>

	FUNCTION=$1
	WIDTH=$2
	HEIGHT=$3
	FORMAT=$4
	NAME=$5

	wdir=functions/$FUNCTION/streaming/$FORMAT/$NAME/${HEIGHT}p

	mkdir -p $wdir
	echo $WIDTH > $wdir/wWidth
	echo $HEIGHT > $wdir/wHeight
	echo $(( $WIDTH * $HEIGHT * 2 )) > $wdir/dwMaxVideoFrameBufferSize
	cat <<EOF > $wdir/dwFrameInterval
666666
100000
5000000
EOF
}

create_uvc() {
	# Example usage:
	#	create_uvc <target config> <function name>
	#	create_uvc config/c.1 uvc.0
	CONFIG=$1
	FUNCTION=$2

	pwd
	echo "	Creating UVC gadget functionality : $FUNCTION"
	mkdir functions/$FUNCTION

	create_frame $FUNCTION 640 360 uncompressed u
	create_frame $FUNCTION 1280 720 uncompressed u
	create_frame $FUNCTION 320 180 uncompressed u
	create_frame $FUNCTION 1920 1080 mjpeg m
	create_frame $FUNCTION 640 480 mjpeg m
	create_frame $FUNCTION 640 360 mjpeg m

	mkdir functions/$FUNCTION/streaming/header/h
	cd functions/$FUNCTION/streaming/header/h
	ln -s ../../uncompressed/u
	ln -s ../../mjpeg/m
	cd ../../class/fs
	ln -s ../../header/h
	cd ../../class/hs
	ln -s ../../header/h
	cd ../../class/ss
	ln -s ../../header/h
	cd ../../../control
	mkdir header/h
	ln -s header/h class/fs
	ln -s header/h class/ss
	cd ../../../

	# Set the packet size: uvc gadget max size is 3k...
	echo 3072 > functions/$FUNCTION/streaming_maxpacket
	echo 2048 > functions/$FUNCTION/streaming_maxpacket
	echo 1024 > functions/$FUNCTION/streaming_maxpacket

	ln -s functions/$FUNCTION configs/c.1
	echo "\tOK"
}

delete_uvc() {
	# Example usage:
	#	delete_uvc <target config> <function name>
	#	delete_uvc config/c.1 uvc.0
	CONFIG=$1
	FUNCTION=$2

	echo "	Deleting UVC gadget functionality : $FUNCTION"
	rm $CONFIG/$FUNCTION

	rm functions/$FUNCTION/control/class/*/h
	rm functions/$FUNCTION/streaming/class/*/h
	rm functions/$FUNCTION/streaming/header/h/u
	rmdir functions/$FUNCTION/streaming/uncompressed/u/*/
	rmdir functions/$FUNCTION/streaming/uncompressed/u
	rm -rf functions/$FUNCTION/streaming/mjpeg/m/*/
	rm -rf functions/$FUNCTION/streaming/mjpeg/m
	rmdir functions/$FUNCTION/streaming/header/h
	rmdir functions/$FUNCTION/control/header/h
	rmdir functions/$FUNCTION
}

case "$1" in
    start)
	echo "Creating the USB gadget"
	echo "Loading composite module"
	modprobe libcomposite

	echo "Creating gadget directory g_multi.0"
	mkdir -p $GADGET/g_multi.0

	cd $GADGET/g_multi.0
	if [ $? -ne 0 ]; then
	    echo "Error creating usb gadget in configfs"
	    exit 1;
	else
	    echo "OK"
	fi

	echo "Setting Vendor and Product ID's"
	echo $VID > idVendor
	echo $PID > idProduct
	echo "OK"

	echo "Setting English strings"
	mkdir -p strings/0x409
	echo $SERIAL > strings/0x409/serialnumber
	echo $MANUF > strings/0x409/manufacturer
	echo $PRODUCT > strings/0x409/product
	echo 0x0100 > bcdDevice
	echo 0xEF > bDeviceClass
	echo 0x02 > bDeviceSubClass
	echo 0x01 > bDeviceProtocol
	echo 0x200 > bcdUSB
	echo "OK"

	echo "Creating Config"
	mkdir configs/c.1
	#mkdir configs/c.2
	#mkdir configs/c.3
	mkdir configs/c.1/strings/0x409
	#mkdir configs/c.2/strings/0x409
	#mkdir configs/c.3/strings/0x409
	echo $MAXPOWERMW > configs/c.1/MaxPower
	#echo $MAXPOWERMW > configs/c.2/MaxPower
	#echo $MAXPOWERMW > configs/c.3/MaxPower
	echo $CONFIGURATION > configs/c.1/strings/0x409/configuration
	#echo $CONFIGURATION > configs/c.2/strings/0x409/configuration
	#echo $CONFIGURATION > configs/c.3/strings/0x409/configuration

	echo "Creating functions..."
	#create_msd configs/c.1 mass_storage.0 $USBFILE
	#create_uvc configs/c.1 uvc.0
	#create_uvc configs/c.1 uvc.1
	#create_acm configs/c.1 acm.usb0
	#create_ecm configs/c.1 ecm.usb0
	create_uac2 configs/c.1 uac2.usb0 "ASSound0" "ASSound0" "ASSound0" 27
	create_uac2 configs/c.1 uac2.usb1 "ASSound1" "ASSound1" "ASSound1" 27
	create_midi configs/c.1 midi.usb2 "Pi_MIDI" "Pi MIDI" 1 1
	echo "OK"

	echo "Binding USB Device Controller"
	echo $UDC > UDC
	echo peripheral > $UDC_ROLE
	cat $UDC_ROLE
	echo "OK"
	;;

    stop)
	echo "Stopping the USB gadget"

	set +e # Ignore all errors here on a best effort

	cd $GADGET/g_multi.0

	if [ $? -ne 0 ]; then
	    echo "Error: no configfs gadget found"
	    exit 1;
	fi

	echo "Unbinding USB Device Controller"
	grep $UDC UDC && echo "" > UDC
	echo "OK"

	#delete_uvc configs/c.1 uvc.1
	#delete_uvc configs/c.1 uvc.0
	#delete_msd configs/c.1 mass_storage.0
	#delete_acm configs/c.1 acm.usb0
	#delete_ecm configs/c.1 ecm.usb0
	delete_uac2 configs/c.1 uac2.usb0
	delete_uac2 configs/c.1 uac2.usb1
	delete_midi configs/c.1 midi.usb2

	echo "Clearing English strings"
	rmdir strings/0x409
	echo "OK"

	echo "Cleaning up configuration"
	rmdir configs/c.1/strings/0x409
	rmdir configs/c.1
	rmdir configs/c.2/strings/0x409
	rmdir configs/c.2
	rmdir configs/c.3/strings/0x409
	rmdir configs/c.3
	echo "OK"

	echo "Removing gadget directory"
	cd $GADGET
	rmdir g_multi.0
	cd /
	echo "OK"

	#echo "Disable composite USB gadgets"
	modprobe -r libcomposite
	#echo "OK"
	;;
    *)
	echo "Usage : $0 {start|stop}"
esac
