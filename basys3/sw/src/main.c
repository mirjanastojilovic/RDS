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
#include <termios.h>
#include <fcntl.h>
#include <time.h>
#include "data_utils.h"
#include "aes_soft.h"


int main(int argc, char* argv[])
{

  srand(time(0));

  config_t config;
  config.tty_dev_path = NULL;
  input_t inputs;
  output_t outputs;
  dumps_t dumps;
  dumps.mask_dump = NULL;
  state_t state;

  inputs.masks = NULL;

  //Define default values
  //unsigned char default_key[16]={0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef, 0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0};
  unsigned char default_key[16] = {0x7d,0x26,0x6a,0xec,0xb1,0x53,0xb4,0xd5,0xd6,0xb1,0x71,0xa5,0x81,0x36,0x60,0x5b};
  unsigned char default_plain[16]={0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
  unsigned char default_fixed_plain[16]={0xda, 0x39, 0xa3, 0xee, 0x5e, 0x6b, 0x4b, 0x0d, 0x32, 0x55, 0xbf, 0xef, 0x95, 0x60, 0x18, 0x90};
  unsigned char IDC_IDF[16] = {0x00, 0x00,0x00, 0x00,0x00, 0x00,0x00, 0x00,0x00, 0x00,0x00, 0x00,0xE0, 0x00,0x00, 0x00};

  unsigned char key[16];
  unsigned char mask[16] = {0x00};

  int chained = 0;
  char file_name[600];
  int no_fails = 0;
  int ret;

  memset(inputs.key, 0x00, sizeof(inputs.key));
  memset(inputs.plaintext, 0x00, sizeof(inputs.plaintext));
  memset(inputs.idc_idf, 0x00, sizeof(IDC_IDF));
  memset(outputs.cipher, 0x00, sizeof(outputs.cipher));
  memset(outputs.cipher_chained, 0x00, sizeof(outputs.cipher_chained));

  init_config(&config);
  if(parse_args(argc, argv, &config) == EXIT_FAILURE)
    return 0;
  if(print_config(&config) == EXIT_FAILURE)
    return 0;

  
  // Open output files
  sprintf(file_name, "%s/plaintexts.bin", config.dump_path);
  dumps.plaintext_dump = fopen(file_name, "wb");
  if(dumps.plaintext_dump == NULL){
    printf("Error openning the output plaintexts binary!\n");
    return 0;
  }

  sprintf(file_name, "%s/ciphertexts.bin", config.dump_path);
  dumps.cipher_dump = fopen(file_name, "wb");
  if(dumps.cipher_dump == NULL){
    printf("Error openning the output ciphertexts binary!\n");
    return 0;
  }

  sprintf(file_name, "%s/keys.bin", config.dump_path);
  dumps.key_dump = fopen(file_name, "wb");
  if(dumps.key_dump == NULL){
    printf("Error openning the output keys binary!\n");
    return 0;
  }

  if(config.num_mask > 0){
    sprintf(file_name, "%s/masks.bin", config.dump_path);
    dumps.mask_dump = fopen(file_name, "wb");
    if(dumps.mask_dump == NULL){
      printf("Error openning the output masks binary!\n");
      return 0;
    }
  }

  sprintf(file_name, "%s/sensor_traces_%luk.csv", config.dump_path, (config.num_traces/1000));
  dumps.sensor_trace_dump = fopen(file_name, "w");
  if(dumps.sensor_trace_dump == NULL){
    printf("Error openning the sensor traces file!\n");
    return 0;
  }

  sprintf(file_name, "%s/ttest_valid_%luk.csv", config.dump_path, (config.num_traces/1000));
  dumps.ttest_valid_dump = fopen(file_name, "w");
  if(dumps.ttest_valid_dump == NULL){
    printf("Error opening the ttest_valid file!\n");
    return 0;
  }

  sprintf(file_name, "%s/ttest_fail_%luk.csv", config.dump_path, (config.num_traces/1000));
  dumps.ttest_fail_dump = fopen(file_name, "w");
  if(dumps.ttest_fail_dump == NULL){
    printf("Error opening the ttest_fail file!\n");
    return 0;
  }
  // If the key mode is 0 (constant key), set the key with the default value
  if(config.key_mode == 0){
    memcpy(inputs.key, default_key, sizeof(default_key));
  }

  // Set the initial plaintext to the default value, and enable the chained flag
  memcpy(inputs.plaintext, default_plain, sizeof(default_plain));
  chained = 1;

  //set calibration array
  memcpy(inputs.idc_idf, IDC_IDF, sizeof(IDC_IDF));

  // Open FPGA Device
  config.tty_fd = open(config.tty_dev_path, O_RDWR | O_NOCTTY | O_SYNC);
  if(config.tty_fd < 0){
    fprintf(stderr, "Error opening %s\n", config.tty_dev_path);
    return EXIT_FAILURE;
  }

  // Initialize the device
  if(set_interface_attribs(config.tty_fd, B115200) == EXIT_FAILURE) {
    close(config.tty_fd);
    return EXIT_FAILURE;
  }

  reset_loop(&config);

  uint8_t addr;
  uint8_t data;

  //Set AES frequency
  if(config.freq_mode != -1){
    addr = 0xEF;
    ret = write_bytes(config.tty_fd,&addr, 1);
    data = (uint8_t) config.freq_mode;
    ret = write_bytes(config.tty_fd, &data, 1);
  }

  //Calibrate the sensor, and reset the AES
  addr = 0xE0;
  ret = write_bytes(config.tty_fd,&addr, 1);
  data = 0xFF;
  ret = write_bytes(config.tty_fd, &data, 1);
  
  
  calibrate_sensor(config.tty_fd, (uint8_t *)&inputs.plaintext,(uint8_t *)&inputs.key, (uint8_t *)&inputs.idc_idf);

  time_t start = time(NULL);

  // Do n_traces encryptions
  for(size_t trace=0; trace<config.num_traces; trace++) {

    printf("Trace : %lu\n", trace);
  

    // Save initial state of the loop in case a timeout happens
    memcpy(state.key, inputs.key, sizeof(inputs.key));
    memcpy(state.plain, inputs.plaintext, sizeof(inputs.plaintext));
    memcpy(state.cipher, outputs.cipher, sizeof(outputs.cipher));
    memcpy(state.cipher_chained, outputs.cipher_chained, sizeof(outputs.cipher_chained));

    // Reset AES
    uint8_t addr = 0xE0;
    ret = write_bytes(config.tty_fd,&addr, 1);
    uint8_t data = 0x02;
    ret = write_bytes(config.tty_fd, &data, 1);

    // Set the value of the key to a random value if key mode 1 is enabled (random key mode)
    if(config.key_mode == 1 ){
      gen_random_word(inputs.key);
    }

    // Set the value of the masks to random values in the number of masks is > 0
    if(config.num_mask > 0){
      inputs.masks = (word_t *) malloc(config.num_mask * (sizeof(word_t)));
      for(size_t i = 0; i < config.num_mask; i++){
        gen_random_word(inputs.masks[i]);
      }
    }
    // START COMMUNICATING WITH THE BOARD, ANY OF THESE READS CAN GO WRONG, SO DON'T CHANGE THE DATA

    // Write key into the AES core
    if(set_key_w(config.tty_fd, (uint8_t *) &inputs.key) == EXIT_FAILURE) {

      printf("Set key failed\n");
      no_fails++;

      // Reinint the device
      reinit_fpga(&config, &inputs, &outputs, &state);

      // Decrement counter and exit current loop iteration
      trace--;
      continue;
    }


    // If in sbox mode, mask needs to be sent too.
    if(config.num_mask > 0){
      for(int mask_no = 0; mask_no < config.num_mask; mask_no++){
        // Write mask into the AES core
        if(set_mask_w(config.tty_fd, (uint8_t *)&inputs.masks[mask_no]) == EXIT_FAILURE) {

          printf("Set mask failed\n");
          no_fails++;

          // Reinint the device ???
          reinit_fpga(&config, &inputs, &outputs, &state);

          // Decrement counter and exit current loop iteration
          trace--;

          continue;
        }
      }
    }

    // Encrypt data
    memset(outputs.cipher, 0x00, sizeof(outputs.cipher));

    if(encrypt_w(config.tty_fd, (uint8_t *)&inputs.plaintext, (uint8_t *)&outputs.cipher) == EXIT_FAILURE) {

      printf("Encrypt failed\n");
      no_fails++;

      // Reinint the device ???
      reinit_fpga(&config, &inputs, &outputs, &state);

      // Decrement counter and exit current loop iteration
      trace--;
      continue;

    }

    //sleep(5);

    // Collect sensor traces
    printf("Transfering sensor trace...\n");
    if(read_trace_w(config.tty_fd, outputs.sensor_trace, outputs.signal_trace) == EXIT_FAILURE) {
      printf("Sensor trace collection failed\n");
      no_fails++;

      // Reinit the device ???
      reinit_fpga(&config, &inputs, &outputs, &state);

      // Decrement counter and exit current loop iteration
      trace--;
      goto loop_end;

    }

    printf("Sensor trace transfer done!\n");

    // Print key
    printf("Key: ");
    for (int i=0;i<16;i++){
      printf("%02x ",((uint8_t *)inputs.key)[i]);
    }
    printf("\n");

    // Write key to the output bin file
    fwrite(inputs.key, sizeof(key[0]), NUM_BYTES, dumps.key_dump);

    if(config.num_mask > 0){
      // Print mask
      for(size_t j = 0; j < config.num_mask; j++){
        fwrite(inputs.masks[j], sizeof((inputs.masks[j])[0]), NUM_BYTES, dumps.mask_dump);
        printf("Mask: ");
        for (size_t i=0;i<NUM_BYTES;i++){
          printf("%02x ",((uint8_t *)(inputs.masks[j]))[i]);
        }
        printf("\n");
      }
    }
    // Print plaintext
    printf("Plain text: ");
    for (int i=0;i<16;i++){
      printf("%02x ",((uint8_t *)inputs.plaintext)[i]);
    }
    printf("\n");

    // Write plaintext to the output bin file
    fwrite(inputs.plaintext, sizeof(inputs.plaintext[0]), NUM_BYTES, dumps.plaintext_dump);

    // Print ciphertext and convert it to unsigned char
    printf("Cipher text: ");
    for (int i=0;i<NUM_BYTES;i++){
      printf("%02x ",((uint8_t *)outputs.cipher)[i]);

      // If the plaintext mode is 2 (t-test mode), and if the current encryption encrypts the chained plaintext, save the ciphertext
      if(config.plain_mode == 2 && chained == 1)
        outputs.cipher_chained[i] = ((uint8_t*)outputs.cipher)[i];
    }
    printf("\n");

    // Write ciphertext to bin file
    fwrite(outputs.cipher, sizeof(outputs.cipher[0]), NUM_BYTES, dumps.cipher_dump);

    // Check if PT was correctly encrypted
    if(check_soft_encrypt(&inputs, &outputs, config.sbox_en, config.num_mask) == EXIT_FAILURE){
      ;
      //return EXIT_FAILURE;
    }

    /* Dump Sensor hex value */
    dump_sensor_trace(dumps.sensor_trace_dump, outputs.sensor_trace, trace == config.num_traces - 1);

    /* Dump Signal hex value */
    dump_signal_trace(dumps.ttest_valid_dump, outputs.signal_trace,  TTEST_VALID_b, trace == config.num_traces -1);
    //dump_signal_trace(dumps.ttest_fail_dump, outputs.signal_trace,  TTEST_FAIL_b, trace == config.num_traces -1);
    

    // Set next plaintext
    // If the plaintext mode is 1 (chained plaintexts), set the next plaintext to be the current ciphertext
    if(config.plain_mode == 1){
      memcpy(inputs.plaintext, outputs.cipher, sizeof(outputs.cipher));
    } else if(config.plain_mode == 2){
      // If the plaintext mode is 2 (t-test mode), and the current encryption encrypts the chained plaintext, set the next plaintext to be the default fixed plaintext
      if(chained == 1){
        memcpy(inputs.plaintext, default_fixed_plain, sizeof(default_fixed_plain));
        chained = 0;
        // If the plaintext mode is 0 (t-test mode), and the current encryption encrypts the fixed plaintext, set the next plaintext to be the last stored chained ciphertext
      } else {
        if(config.sbox_en == 0){
          memcpy(inputs.plaintext, outputs.cipher_chained, sizeof(outputs.cipher_chained));
        } else {
          gen_random_word(inputs.plaintext);         
        }
        chained = 1;
      }
    }


    loop_end: ;

  }
  time_t end = time(NULL);
  float seconds = (float) (end - start) / CLOCKS_PER_SEC;
  printf("Seconds needed to record the traces %ld\n", end-start);

  printf("Number of fails encountered: %d\n", no_fails);

  close(config.tty_fd);
  if(config.tty_dev_path != NULL)
    free(config.tty_dev_path);
  if(config.num_mask > 0)
    free(inputs.masks);
  if(dumps.key_dump != NULL)
    fclose(dumps.key_dump);
  if(dumps.mask_dump != NULL)
    fclose(dumps.mask_dump);
  if(dumps.plaintext_dump != NULL)
    fclose(dumps.plaintext_dump);
  if(dumps.cipher_dump != NULL)
    fclose(dumps.cipher_dump);
  if(dumps.sensor_trace_dump != NULL)
    fclose(dumps.sensor_trace_dump);
  if(dumps.ttest_valid_dump != NULL)
    fclose(dumps.ttest_valid_dump);
  if(dumps.ttest_fail_dump != NULL)
    fclose(dumps.ttest_fail_dump);


  return 0;
}
