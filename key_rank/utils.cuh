/*
 RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
 Copyright 2023, School of Computer and Communication Sciences, EPFL.

 All rights reserved. Use of this source code is governed by a
 BSD-style license that can be found in the LICENSE.md file. 
*/

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

typedef struct config {

  int key[16];
  char trace_path[1000];
  char ciphertext_path[1000];
  int n_traces;
  int n_samples;
  int step_size;
  char dump_path[1000];
} config_t;

void print_help();
int parse_args(int argc, char* argv[], config_t* config); 
int init_config(config_t* config);
int print_config(config_t* config);
