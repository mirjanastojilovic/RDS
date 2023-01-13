/*
 RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
 Copyright 2023, School of Computer and Communication Sciences, EPFL.

 All rights reserved. Use of this source code is governed by a
 BSD-style license that can be found in the LICENSE.md file. 
 */

#ifndef UTILS_H
#define UTILS_H

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>

typedef struct config {

  int key_mode;
  int plain_mode;
  int n_traces;
  int osc_en;
  int calib;
  int sensor_en;
  int n_samples;
  int start_sample;
  char dump_path[200];
  unsigned char key[16];
  unsigned char idf[12];
  unsigned char idc[4];
  unsigned char ptxt[16];
  unsigned char fixed_ptxt[16]; //only used for plain_mode = 2
  int registers;
} config_t;

void print_help();
int parse_args(int argc, char* argv[], config_t* config); 
int init_config(config_t* config);
int print_config(config_t* config);
void initialize_random(unsigned char array[16]);
void sbox_key_pt(int trace, unsigned char pt[16], unsigned char key[16]);
unsigned char hamming_weight(unsigned char byte);

#endif
