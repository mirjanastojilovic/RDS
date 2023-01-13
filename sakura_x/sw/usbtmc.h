/*
 RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
 Copyright 2023, School of Computer and Communication Sciences, EPFL.

 All rights reserved. Use of this source code is governed by a
 BSD-style license that can be found in the LICENSE.md file. 
 */

#ifndef USBTMC_H_
#define USBTMC_H_

// usbtmc.h
// This file is part of a Linux kernel module for USBTMC (USB Test and
// Measurement Class) devices
// Copyright (C) 2007 Stefan Kopp, Gechingen, Germany
// See usbtmc.c source file for license details

#include <linux/ioctl.h> // For _IO macro

// Driver parameters that you might want to tune...

// Maximum number of USBTMC devices to be concurrently serviced by this module
#define USBTMC_MINOR_NUMBERS 						16

// Size of driver internal IO buffer. Must be multiple of 4 and at least as
// large as wMaxPacketSize (which is usually 512 bytes).
#define USBTMC_SIZE_IOBUFFER 						4096

// Default USB timeout (in jiffies)
#define USBTMC_DEFAULT_TIMEOUT 						10*HZ

// Maximum number of read cycles to empty bulk in endpoint during CLEAR and
// ABORT_BULK_IN requests. Ends the loop if (for whatever reason) a short
// packet is never read.
#define USBTMC_MAX_READS_TO_CLEAR_BULK_IN			100

// Other definitions

// Request values for USBTMC driver's ioctl entry point
#define USBTMC_IOC_NR								91
#define USBTMC_IOCTL_GET_CAPABILITIES				_IO(USBTMC_IOC_NR,0)
#define USBTMC_IOCTL_INDICATOR_PULSE				_IO(USBTMC_IOC_NR,1)
#define USBTMC_IOCTL_CLEAR							_IO(USBTMC_IOC_NR,2)
#define USBTMC_IOCTL_ABORT_BULK_OUT					_IO(USBTMC_IOC_NR,3)
#define USBTMC_IOCTL_ABORT_BULK_IN					_IO(USBTMC_IOC_NR,4)
#define USBTMC_IOCTL_SET_ATTRIBUTE					_IO(USBTMC_IOC_NR,5)
#define USBTMC_IOCTL_CLEAR_OUT_HALT					_IO(USBTMC_IOC_NR,6)
#define USBTMC_IOCTL_CLEAR_IN_HALT					_IO(USBTMC_IOC_NR,7)
//#define USBTMC_IOCTL_TIMEOUT						_IO(USBTMC_IOC_NR,8)
#define USBTMC_IOCTL_GET_ATTRIBUTE					_IO(USBTMC_IOC_NR,9)
#define USBTMC_IOCTL_INSTRUMENT_DATA				_IO(USBTMC_IOC_NR,10)
#define USBTMC_IOCTL_RESET_CONF						_IO(USBTMC_IOC_NR,11)

// Request names for usbtmc_ioctl command line utility
#define USBTMC_IOCTL_NAME_GET_CAPABILITIES			"getcaps"
#define USBTMC_IOCTL_NAME_INDICATOR_PULSE			"indpulse"
#define USBTMC_IOCTL_NAME_CLEAR						"clear"
#define USBTMC_IOCTL_NAME_ABORT_BULK_OUT			"abortout"
#define USBTMC_IOCTL_NAME_ABORT_BULK_IN				"abortin"
#define USBTMC_IOCTL_NAME_SET_ATTRIBUTE				"setattr"
#define USBTMC_IOCTL_NAME_CLEAR_OUT_HALT			"clearouthalt"
#define USBTMC_IOCTL_NAME_CLEAR_IN_HALT				"clearinhalt"
#define USBTMC_IOCTL_NAME_GET_ATTRIBUTE				"getattr"
#define USBTMC_IOCTL_NAME_RESET_CONF				"reset"

// This structure is used with USBTMC_IOCTL_GET_CAPABILITIES.
// See section 4.2.1.8 of the USBTMC specification for details.
struct usbtmc_dev_capabilities {
	char interface_capabilities;
	char device_capabilities;
	char usb488_interface_capabilities;
	char usb488_device_capabilities;
};

// This structure is used with USBTMC_IOCTL_SET_ATTRIBUTE and
// USBTMC_IOCTL_GET_ATTRIBUTE.
struct usbtmc_attribute {
	int attribute;
	int value;
};

// Defines for attributes and their values
#define USBTMC_ATTRIB_AUTO_ABORT_ON_ERROR			0
#define USBTMC_ATTRIB_NAME_AUTO_ABORT_ON_ERROR		"autoabort"
#define USBTMC_ATTRIB_READ_MODE						1
#define USBTMC_ATTRIB_NAME_READ_MODE				"readmode"
#define USBTMC_ATTRIB_TIMEOUT						2
#define USBTMC_ATTRIB_NAME_TIMEOUT					"timeout"
#define USBTMC_ATTRIB_NUM_INSTRUMENTS				3
#define USBTMC_ATTRIB_NAME_NUM_INSTRUMENTS			"numinst"
#define USBTMC_ATTRIB_MINOR_NUMBERS					4
#define USBTMC_ATTRIB_NAME_MINOR_NUMBERS			"numminor"
#define USBTMC_ATTRIB_SIZE_IO_BUFFER				5
#define USBTMC_ATTRIB_NAME_SIZE_IO_BUFFER			"buffsize"
#define USBTMC_ATTRIB_DEFAULT_TIMEOUT				6
#define USBTMC_ATTRIB_NAME_DEFAULT_TIMEOUT			"deftimeout"
#define USBTMC_ATTRIB_DEBUG_MODE					7
#define USBTMC_ATTRIB_NAME_DEBUG_MODE				"debug"
#define USBTMC_ATTRIB_VERSION						8
#define USBTMC_ATTRIB_NAME_VERSION					"version"
#define USBTMC_ATTRIB_TERM_CHAR_ENABLED				9
#define USBTMC_ATTRIB_NAME_TERM_CHAR_ENABLED		"termcharenab"
#define USBTMC_ATTRIB_TERM_CHAR						10
#define USBTMC_ATTRIB_NAME_TERM_CHAR				"termchar"
#define USBTMC_ATTRIB_ADD_NL_ON_READ				11
#define USBTMC_ATTRIB_NAME_ADD_NL_ON_READ			"addnlread"
#define USBTMC_ATTRIB_REM_NL_ON_WRITE				12
#define USBTMC_ATTRIB_NAME_REM_NL_ON_WRITE			"remnlwrite"
#define USBTMC_ATTRIB_VAL_OFF						0
#define USBTMC_ATTRIB_NAME_VAL_OFF					"off"
#define USBTMC_ATTRIB_VAL_ON						1
#define USBTMC_ATTRIB_NAME_VAL_ON					"on"
#define USBTMC_ATTRIB_VAL_FREAD						0
#define USBTMC_ATTRIB_NAME_VAL_FREAD				"fread"
#define USBTMC_ATTRIB_VAL_READ						1
#define USBTMC_ATTRIB_NAME_VAL_READ					"read"

// This structure is used with USBTMC_IOCTL_INSTRUMENT_DATA.
struct usbtmc_instrument {
	int minor_number;
	char manufacturer[200];
	char product[200];
	char serial_number[200];
};

// USBTMC status values
#define USBTMC_STATUS_SUCCESS						0x01
#define USBTMC_STATUS_PENDING						0x02
#define USBTMC_STATUS_FAILED						0x80
#define USBTMC_STATUS_TRANSFER_NOT_IN_PROGRESS		0x81
#define USBTMC_STATUS_SPLIT_NOT_IN_PROGRESS			0x82
#define USBTMC_STATUS_SPLIT_IN_PROGRESS				0x83

// USBTMC requests values
#define USBTMC_REQUEST_INITIATE_ABORT_BULK_OUT		1
#define USBTMC_REQUEST_CHECK_ABORT_BULK_OUT_STATUS	2
#define USBTMC_REQUEST_INITIATE_ABORT_BULK_IN		3
#define USBTMC_REQUEST_CHECK_ABORT_BULK_IN_STATUS	4
#define USBTMC_REQUEST_INITIATE_CLEAR				5
#define USBTMC_REQUEST_CHECK_CLEAR_STATUS			6
#define USBTMC_REQUEST_GET_CAPABILITIES				7
#define USBTMC_REQUEST_INDICATOR_PULSE				64




#endif /* USBTMC_H_ */
