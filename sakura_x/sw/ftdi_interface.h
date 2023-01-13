/*
 RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
 Copyright 2023, School of Computer and Communication Sciences, EPFL.

 All rights reserved. Use of this source code is governed by a
 BSD-style license that can be found in the LICENSE.md file. 
 */

#ifndef FTDI_INTERFACE
#define FTDI_INTERFACE

#include "ftd2xx.h"

#define MAX_DEVICES 10

int print_devices(FT_DEVICE_LIST_INFO_NODE* devices, unsigned int number);
int setup_device(int device, FT_HANDLE* handle);
int ft_read(char* buffer, unsigned int length_req, FT_HANDLE handle);
int ft_write(char* buffer, unsigned int length_req, FT_HANDLE handle);
void close_device(FT_HANDLE handle);

#endif
