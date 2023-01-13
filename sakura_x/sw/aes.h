/*
 RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
 Copyright 2023, School of Computer and Communication Sciences, EPFL.

 All rights reserved. Use of this source code is governed by a
 BSD-style license that can be found in the LICENSE.md file. 
 */

#ifndef AES_H
#define AES_H

#define ONE_BYTE 1
#define AES_SIZE 16 // in bytes
#define COARSE_WIDTH 32 //number of LUTs defined in hw
#define FINE_WIDTH 24
#define LEN_IDC_IDF 16 //128 bit array defined in hw
#define SAMPLES_PER_TRACE 128 // WARNING: make sure that this value coincides with the value in hw
#define LEN_SAMPLE 16 //16 bytes per sample 

#include <stdio.h>
#include "Sasebogii.h"

typedef struct state_t {
  unsigned char key[AES_SIZE];
  unsigned char plain[AES_SIZE];
  unsigned char cipher[AES_SIZE];
  unsigned char cipher_chained[AES_SIZE];
} state_t;

typedef enum {AUTOMATIC_HW, MANUAL, SKIP, AUTOMATIC_SW_IDC, AUTOMATIC_SW} calib_type_t;

#define CALIB_MANUAL 0x01 
#define CALIB_AUTO   0x02
#define SET_KEY      0x04
#define ENCRYPT      0x08
#define READ_SENS    0x10
#define READ_SAMPLE  0x01
#define END_READ     0x02
int set_key(FT_HANDLE sasebo, unsigned char* key);
int encdec(FT_HANDLE sasebo, int data);
int encrypt(FT_HANDLE sasebo, unsigned char* plaintext, unsigned char* cipher);
void print_value(unsigned char* value, FILE* f);

int send_key(FT_HANDLE * sasebo, unsigned char* key);
int encrypt_data(FT_HANDLE * sasebo, unsigned char* plaintext, unsigned char* cipher);

FT_HANDLE* sasebo_reinit(FT_HANDLE* handle, int * trace, state_t * state, unsigned char *key, unsigned char *plain, unsigned char *cipher, unsigned char *cipher_chained);
FT_HANDLE* sasebo_reinit_simple(FT_HANDLE* handle);
int calibrate_sensor(FT_HANDLE * handle, calib_type_t calib, int registers, unsigned char idc_idf[16]);
int get_sensor_trace(FT_HANDLE * handle, int n_samples, int print, int store, unsigned char sensor_trace[][16]);
void set_idc(unsigned char idc_idf[LEN_IDC_IDF], int idc, int idf_width);
void set_idf(unsigned char idc_idf[LEN_IDC_IDF], int idf);
int count_one(int x);
int get_max_sample(unsigned char sample_trace[SAMPLES_PER_TRACE][LEN_SAMPLE], int registers_bytes);
int get_min_sample(unsigned char sample_trace[SAMPLES_PER_TRACE][LEN_SAMPLE], int registers_bytes);
int check_overflow_underflow(FT_HANDLE *handle, int registers_bytes, int max_hw, int delta, int N);


#endif
