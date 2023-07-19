/*
 RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
 Copyright 2023, School of Computer and Communication Sciences, EPFL.

 All rights reserved. Use of this source code is governed by a
 BSD-style license that can be found in the LICENSE.md file. 
 */

#ifndef UTILS_H_
#define UTILS_H_

#include "host.hpp"

unsigned char hamming_weight(uint32_t data);
int count_one(int x);
int get_min_sample(uint32_t * hbuf, int N_SAMPLES, int SENSOR_WIDTH);
int get_max_sample(uint32_t * hbuf, int N_SAMPLES, int SENSOR_WIDTH);
uint32_t * pack_idc_idf(uint32_t * idc_idf, int idc, int idf, int IDC_SIZE, int IDF_SIZE);
void uint8_to_uint32(uint8_t * input, uint32_t * output);
void uint32_to_uint8(uint32_t * input, uint8_t * output);
void aes_encrypt(xrt::ip kernel, uint8_t * key, uint8_t * plaintext, uint8_t * ciphertext);
void save_trace(xrt::bo buffer, uint32_t *hbuf, int N_SAMPLES, int SENSOR_WIDTH, FILE *traces_bin, FILE *traces_raw);
void save_ciphertext(uint8_t *ciphertext, FILE *ciphertext_f);
void save_key(uint8_t *key, FILE *key_f);
void init_system(xrt::ip kernel, xrt::bo buffer);
void send_calibration(xrt::ip kernel, xrt::bo buffer, uint32_t* hbuf, uint32_t **idc_idf, int n_sensors, int idc_size, int idf_size);
void calibrate_from_file(xrt::ip kernel, xrt::bo buffer, uint32_t* hbuf, int n_sensors, int idc_size, int idf_size, char* CALIB_PATH);
void calibrate_tdc(xrt::ip kernel, xrt::bo buffer, uint32_t * hbuf, char calib_file_name[100], int N_SENSORS, int N_SAMPLES, int IDC_SIZE, int IDF_SIZE, int calib, int SENSOR_WIDTH, FILE* idc_idf_f);
void calibrate_rds(xrt::ip kernel, xrt::bo buffer, uint32_t * hbuf, char calib_file_name[100], int N_SENSORS, int N_SAMPLES, int IDC_SIZE, int IDF_SIZE, int calib, int SENSOR_WIDTH, FILE* idc_idf_f);
void save_temperature(FILE * temperature_f, int trace);


#endif
