#!/bin/bash

# RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
# Copyright 2023, School of Computer and Communication Sciences, EPFL.
#
# All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

# Location /home/andres/Windows_Documents/Eclipse\ projects/ftdexample/setup.sh

#echo "This file is not needed anymore, please check the function getPhysicalConnection in the FTD2xxDev library"
#
#exit

echo "Init FTD2xx"

devpath="/dev/bus/usb/001/"
devices=$(ls $devpath)
devices="$devices "
iteEnd=${#devices}

for (( i=0; i<$iteEnd; i=i+4 ))
do
	last=${devices:$i:4}
done


lastdev="$devpath$last"
echo "Given access to the device $lastdev"
sudo chmod 666 $lastdev


#checl for ftdi_sio and  usbserial

ftdi_sio=$(lsmod | grep "ftdi_sio")
[ ! -z "$ftdi_sio" ] && sudo rmmod ftdi_sio

usbserial=$(lsmod | grep "usbserial")
[ ! -z "$usbserial" ] && sudo rmmod usbserial

exit


