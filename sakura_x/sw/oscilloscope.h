/*
 RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
 Copyright 2023, School of Computer and Communication Sciences, EPFL.

 All rights reserved. Use of this source code is governed by a
 BSD-style license that can be found in the LICENSE.md file. 
 */

#ifndef OSCILLOSCOPE_H
#define OSCILLOSCOPE_H

#define SIMPLE_PRECISION 1

int open_osc();
int setup_osc(int file);
int read_osc(int file, int id);
int get_id(int file);
int clear(int file);
int write_file(int file, const char* message);
int get_Acq_param(int file);
int init_osc();
int start_reccording(int osc);
int set_filename(char* s, int id, char* prefix);

int quick_save(int file, int id, int precision, char file_path[300]);
int trigger_save(int file, int id, int precision, char file_path[300]);

#endif
