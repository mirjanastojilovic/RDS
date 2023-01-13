/*
 RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
 Copyright 2023, School of Computer and Communication Sciences, EPFL.

 All rights reserved. Use of this source code is governed by a
 BSD-style license that can be found in the LICENSE.md file. 
 */

#ifndef HOST_H
#define HOST_H
#include <xrt/xrt_bo.h>
#include <xrt/xrt_device.h>
#include <xrt/xrt_kernel.h>
#include <xrt/xrt_uuid.h>
#include <experimental/xrt_error.h>
#include <experimental/xrt_ip.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <iostream>
#include <dirent.h>
#include <libgen.h>

#define DEBUG 0

#if DEBUG == 1
# define DEBUG_PRINT(x) printf x
#else
# define DEBUG_PRINT(x) do {} while (0)
#endif

// Write register addresses
#define RST_ADDR             0x100
#define DUMP_PTR_BASE_ADDR   0x200
#define CALIB_REG_BASE_ADDR  0x500
#define CALIB_TRG_ADDR       0x600
#define CALIB_TRACE_TRG_ADDR 0x700
#define KEY_BASE_ADDR        0x300
#define SET_AES_KEY_ADDR     0x900
#define PLAINTEXT_BASE_ADDR  0x400
#define START_EXEC_ADDR      0x800

// Read register address
#define STATUS_REG_ADDR      0x000
#define CIPHERTEXT_ADDR      0x004

// Read register masks
#define CALIB_DUMP_IDLE_MASK 0x03
#define TRACE_DUMP_IDLE_MASK 0x23
#define TRACE_DONE_IDLE_MASK 0x03

#define BYTE_TO_BINARY_PATTERN "%c%c%c%c%c%c%c%c\n"
#define BYTE_TO_BINARY(byte)  \
  (byte & 0x80 ? '1' : '0'), \
  (byte & 0x40 ? '1' : '0'), \
  (byte & 0x20 ? '1' : '0'), \
  (byte & 0x10 ? '1' : '0'), \
  (byte & 0x08 ? '1' : '0'), \
  (byte & 0x04 ? '1' : '0'), \
  (byte & 0x02 ? '1' : '0'), \
  (byte & 0x01 ? '1' : '0')

typedef enum {ALL_ZEROS, ALL_ONES, RISING_EDGE, FALLING_EDGE, ERROR} calib_state_t;

typedef struct Code{

  uint32_t * code;
  uint32_t code_size;

} Code;

typedef struct {

  char template_name[1000];
  char instruction[1000];
  char info[1000];
  int template_id;

} inst_info;

#endif
