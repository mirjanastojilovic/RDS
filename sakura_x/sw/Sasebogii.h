/*
 RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
 Copyright 2023, School of Computer and Communication Sciences, EPFL.

 All rights reserved. Use of this source code is governed by a
 BSD-style license that can be found in the LICENSE.md file. 
 */

#ifndef SASEBOGII
#define SASEBOGII

#include "ftd2xx.h"
#include "ftdi_interface.h"

/*
 *
 * Implementation of interface with sasebogii: read / write protocol
 *
 */

typedef struct sasebo_t {
  FT_HANDLE handle;
  // possibly more stuff ...
} sasebo_t;

FT_HANDLE* sasebo_init();
int sasebo_read(FT_HANDLE handle, char* buffer, size_t len, int addr);
int sasebo_write(FT_HANDLE handle, char* buffer, size_t len, int addr);
int sasebo_read_unit(FT_HANDLE handle, int addr);
int sasebo_write_unit(FT_HANDLE handle, int addr, int data);
int select_comp(FT_HANDLE handle);
int sasebo_purge(FT_HANDLE handle);
void sasebo_close(FT_HANDLE* handle);

// ADDR of sasebogii elements (key, input plaintext, etc...)
#define ADDR_CONT     0x0002
#define ADDR_IPSEL    0x0004
#define ADDR_OUTSEL   0x0008
#define ADDR_MODE     0x000C
#define ADDR_RSEL     0x000E
#define ADDR_KEY0     0x0100
#define ADDR_ITEXT0   0x0140
#define ADDR_OTEXT0   0x0180
#define ADDR_MASK     0x0200
#define ADDR_VERSION  0xFFFC

// modes
#define MODE_ENC  0x0000
#define MODE_DEC  0x0001


#endif
