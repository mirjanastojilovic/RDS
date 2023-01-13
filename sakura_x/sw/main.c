/*
 RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
 Copyright 2023, School of Computer and Communication Sciences, EPFL.

 All rights reserved. Use of this source code is governed by a
 BSD-style license that can be found in the LICENSE.md file. 
 */


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>

#include "Sasebogii.h"
#include "oscilloscope.h"
#include "utils.h"
#include "aes.h"
#include "aes_soft.h"

int main(int argc, char* argv[])
{

  srand(time(0));

  FILE * plaintexts;
  FILE * ciphertexts;
  FILE * keys;
  FILE * sensor_traces;
  FILE * sensor_traces_hw;

  config_t config;

  // Define default values
  unsigned char default_key[16]={0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef, 0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0};
  unsigned char default_plain[16]={0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
  unsigned char default_fixed_plain[16]={0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
  unsigned char idc_idf[16] = {0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xc0, 0x00, 0x00, 0x00, 0x00, 0x00, 0xfc, 0x00, 0x00, 0x00}; //the last 4 bytes are idc

  unsigned char key[16];
  unsigned char plain[16];
  unsigned char cipher_chained[16];
  unsigned char cipher[16];
  unsigned char cipher_soft[16];
  unsigned char sensor_trace[128][16];
  unsigned char sensor_trace_hw[128];

  int osc = -1;
  int chained = 0;
  char file_name[300];
  int no_fails = 0;

  state_t state;
  memset(state.key, 0x00, sizeof(state.key));
  memset(state.plain, 0x00, sizeof(state.plain));
  memset(state.cipher, 0x00, sizeof(state.cipher));
  memset(state.cipher_chained, 0x00, sizeof(state.cipher_chained));

  // Load program config passed by the command line arguments
  init_config(&config);
  if(parse_args(argc, argv, &config) == EXIT_FAILURE)
    return 0;
  // If in sbox mode, overwrite the number of traces to be 256*256*10
  if(print_config(&config) == EXIT_FAILURE)
    return 0;

  // Open output files
  
  sprintf(file_name, "%s/plaintexts.bin", config.dump_path);
  plaintexts = fopen(file_name, "wb");
  if(plaintexts == NULL){
    printf("Error opening the output plaintexts binary!\n");
    return 0;
  }

  sprintf(file_name, "%s/ciphertexts.bin", config.dump_path);
  ciphertexts = fopen(file_name, "wb");
  if(ciphertexts == NULL){
    printf("Error opening the output ciphertexts binary!\n");
    return 0;
  }

  sprintf(file_name, "%s/keys.bin", config.dump_path);
  keys = fopen(file_name, "wb");
  if(keys == NULL){
    printf("Error opening the output keys binary!\n");
    return 0;
  }

  sprintf(file_name, "%s/sensor_traces_%dk.csv", config.dump_path, (config.n_traces/1000));
  sensor_traces = fopen(file_name, "w");
  if(sensor_traces == NULL){
    printf("Error opening the sensor traces file!\n");
    return 0;
  }

  sprintf(file_name, "%s/sensor_traces_hw_%dk.bin", config.dump_path, (config.n_traces/1000));
  sensor_traces_hw = fopen(file_name, "wb");
  if(sensor_traces_hw == NULL){
    printf("Error opening the sensor traces HW file!\n");
    return 0;
  }
  
  // Initialize oscilloscope if oscilloscope is enabled
  if(config.osc_en == 1)
    osc = init_osc();

  // If the key mode is 0 (constant key), set the key with the default value
  if(config.key_mode == 0){
    memcpy(key, default_key, sizeof(default_key));
  }
  //if the key mode is 2 (user specified key), set the key with the default value
  if(config.key_mode == 2){
    memcpy(key, config.key, sizeof(default_key));
  }
  //set the idc_idf value. Default value changes if the user specified its own idc_idf value
  memcpy(idc_idf+12, config.idc, sizeof(config.idc));
  memcpy(idc_idf, config.idf, sizeof(config.idf));

  //If the user specified a plaintext using the command-line option, store it in default_plain
  memcpy(default_plain, config.ptxt, sizeof(default_plain));
  memcpy(default_fixed_plain, config.fixed_ptxt, sizeof(default_fixed_plain));
  
  // Set the initial plaintext to the default value, and enable the chained flag
  memcpy(plain, default_plain, sizeof(default_plain));
  chained = 1;

  
  // Open Sasebo Device
 FT_HANDLE* handle;
  if((handle = sasebo_init()) == NULL) {
    return EXIT_FAILURE;
  }

  // Initialize the device
  if(select_comp(*handle) == EXIT_FAILURE) {
    sasebo_close(handle);
    return EXIT_FAILURE;
  }

  // Set the AES core to encryption mode
  if(encdec(*handle, MODE_ENC) == EXIT_FAILURE) {
    sasebo_close(handle);
    return EXIT_FAILURE;
  }

  // Reset system
  sasebo_write_unit(*handle, ADDR_CONT, 0x0004);
  sasebo_write_unit(*handle, ADDR_CONT, 0x0000);
  
  if(calibrate_sensor(handle, config.calib, config.registers, idc_idf) == EXIT_FAILURE){
    return EXIT_FAILURE;
  }
  // Do n_traces encryptions
  for(int trace=0; trace<config.n_traces; trace++) {
    printf("Trace : %d\n", trace);

    // Save initial state of the loop in case a timeout happens
    memcpy(state.key, key, sizeof(key));
    memcpy(state.plain, plain, sizeof(plain));
    memcpy(state.cipher, cipher, sizeof(cipher));
    memcpy(state.cipher_chained, cipher_chained, sizeof(cipher_chained));
  
    // Reset AES
    sasebo_write_unit(*handle, ADDR_CONT, 0x0004);
    sasebo_write_unit(*handle, ADDR_CONT, 0x0000);
  
    // Set the value of the key to a random value if key mode 1 is enabled (random key mode)
    if(config.key_mode == 1){
      initialize_random(key);
    }

    // Write key into the AES core
    if(send_key(handle, key) == EXIT_FAILURE) {
      printf("Sending key failed\n");
      no_fails++;
      if((handle = sasebo_reinit(handle, &trace, &state, key, plain, cipher, cipher_chained)) == NULL){
        printf("Could not reinit device. EXIT\n");
        return EXIT_FAILURE;
      }
      trace--;
      continue;
    }

    // Encrypt data
    memset(cipher, 0x00, sizeof(cipher));

    if(encrypt_data(handle, plain, cipher) == EXIT_FAILURE) {
      printf("Encrypt failed\n");
      no_fails++;
      if((handle = sasebo_reinit(handle, &trace, &state, key, plain, cipher, cipher_chained)) == NULL){
        printf("Could not reinit device. EXIT\n");
        return EXIT_FAILURE;
      }
      trace--;
      continue;

    }

    // Collect sensor traces
    if(config.sensor_en == 1){
      if(get_sensor_trace(handle, config.n_samples, 0, 1, sensor_trace) == EXIT_FAILURE) {
        printf("Encrypt failed\n");
        no_fails++;
        if((handle = sasebo_reinit(handle, &trace, &state, key, plain, cipher, cipher_chained)) == NULL){
          printf("Could not reinit device. EXIT\n");
          return EXIT_FAILURE;
        }
        trace--;
        continue;

      }

      // Save sensor trace to file 
      for(int sample = 0; sample < config.n_samples; sample++){
        sensor_trace_hw[sample] = 0;
        for (int i=0;i<16;i++){
          fprintf(sensor_traces, "%02x",sensor_trace[sample][i]);
          sensor_trace_hw[sample] += hamming_weight(sensor_trace[sample][i]);
        }
        if(sample!= 127)
          fprintf(sensor_traces, ",");
      }
      fprintf(sensor_traces, "\n");
      fwrite(sensor_trace_hw, sizeof(sensor_trace_hw[0]), config.n_samples, sensor_traces_hw);
    }

    // Print key
    printf("Key: ");
    for (int i=0;i<16;i++){
      printf("%02x ",(unsigned char)key[i]);
    }
    printf("\n");

    // Write key to the output bin file
    fwrite(key, sizeof(key[0]), 16, keys);

    // Print plaintext
    printf("Plain text: ");
    for (int i=0;i<16;i++){
      printf("%02x ",(unsigned char)plain[i]);
    }
    printf("\n");
  
    // Write plaintext to the output bin file
    fwrite(plain, sizeof(plain[0]), 16, plaintexts);

    // Print ciphertext and convert it to unsigned char
    printf("Cipher text: ");
    for (int i=0;i<16;i++){
      printf("%02x ",cipher[i]);

      // If the plaintext mode is 2 (t-test mode), and if the current encryption encrypts the chained plaintext, save the ciphertext
      if(config.plain_mode == 2 && chained == 1)
        cipher_chained[i] = (unsigned char)cipher[i];
    }
    printf("\n");

    // Write ciphertext to bin file
    fwrite(cipher, sizeof(cipher[0]), 16, ciphertexts);

    // Check if PT was correctly encrypted
    memcpy(cipher_soft, plain, sizeof(plain));
    AES_Encrypt(cipher_soft, key);
    for(int i=0;i<16;i++){
      if(cipher_soft[i]!=cipher[i]){
        printf("ERROR: Obtained ciphertext is different than expected!\n");
        printf("Byte %d is supposed to be %02x but is %02x instead!\n", i, cipher_soft[i], cipher[i]);
        return EXIT_FAILURE;
      }
    }
    
    // Set next plaintext
    // If the plaintext mode is 1 (chained plaintexts), set the next plaintext to be the current ciphertext
    if(config.plain_mode == 1){
      memcpy(plain, cipher, sizeof(cipher));
    } else if(config.plain_mode == 2){
      // If the plaintext mode is 2 (t-test mode), and the current encryption encrypts the chained plaintext, set the next plaintext to be the default fixed plaintext
      if(chained == 1){
        memcpy(plain, default_fixed_plain, sizeof(default_fixed_plain));
        chained = 0;
      // If the plaintext mode is 2 (t-test mode), and the current encryption encrypts the fixed plaintext, set the next plaintext to be the last stored chained ciphertext
      } else {
        memcpy(plain, cipher_chained, sizeof(cipher_chained));
        chained = 1;
      }
    }
  
    // Read data from oscilloscope if oscilloscope is enabled
    if(config.osc_en == 1)
      quick_save(osc, trace, SIMPLE_PRECISION, config.dump_path);

  }

  sasebo_close(handle);

  printf("Number of fails encountered: %d\n", no_fails);
  
  fclose(plaintexts);
  fclose(ciphertexts);
  fclose(keys);
  fclose(sensor_traces);
  fclose(sensor_traces_hw);
  return 0;
}
