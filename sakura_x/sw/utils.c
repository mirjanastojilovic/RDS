/*
 RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
 Copyright 2023, School of Computer and Communication Sciences, EPFL.

 All rights reserved. Use of this source code is governed by a
 BSD-style license that can be found in the LICENSE.md file. 
 */

#include "utils.h"

void print_help() {
  printf("HELP\n");
  printf("\n==================================================\n");
  printf("AES Power Side-Channel Measurement Software\n");
  printf("\n==================================================\n");
  printf("\nShort summary:\n");
  printf("\t- This program sends plaintexts and reads ciphertexts from an AES core running on the Sakura-X board. At the same time, the program can read the power consumption traces of the AES from the Tektronix MDO3104 oscilloscope, and store each trace as a .csv file.\n");
  printf("\t- The plaintexts sent to the AES core can either be in constant mode (one same plaintext), in chained mode (next plaintext is the current ciphertext) or in t-test mode (chained plaintexts are alternating with one fixed plaintext). In all cases, the plaintext can be specified by the corresponding command line option. If no plaintext is specified, then the all-zero plaintext is used.\n");
  printf("\t- The key can stay the same for all encryptions using the default key or a user specified key, or can randomly change for every encryption.\n");
  printf("\t- The system can also be in the S-box mode, where the plaintext consists of 16 identical bytes which increase from 0 to 256. The key also consists of 16 identical bytes that iterate from 0 to 256, and increment only when the plaintext makes a full loop. This double loop is repeated 100 times, so the number of traces is always overwriten by 256*256*10\n");
  printf("\t- The ouput of this program is by default in the same directory as the executable, but this can be changed. By default, the output files are the following:\n");
  printf("\t\t* Binary file containing all the plaintexts\n");
  printf("\t\t* Binary file containing all the ciphertexts\n");
  printf("\t\t* Binary file containing all the keys (or one single key if it does not change\n");
  printf("\n==================================================\n");
  printf("\nProgram arguments:\n");
  printf("\t-h:              print help\n");
  printf("\t-k <number>:     key mode:\n");
  printf("\t\t- 0              constant (default key)\n");
  printf("\t\t- 1              random\n");
  printf("\t\t- 2              custom. Use -u to specify the key.\n");
  printf("\t-uk <hexvalue>: user specified key\n");
  printf("\t-pm <number>:    plaintext mode:\n");
  printf("\t\t- 0              constant\n");
  printf("\t\t- 1              chained\n");
  printf("\t\t- 2              t-test\n");
  printf("\t-ptxt <hexvalue> [<hexvalue>]: user specified plaintext. For plaintext mode 1 and 2, 1 and 2 hexvalues need to be specified, respectively.\n");
  printf("\t\t - if -pm 1: Only one plaintext must be specified for the chained mode.\n");
  printf("\t\t - if -pm 2: <ptxt1> <ptxt2>, where <ptxt1> is used for the chained mode and <ptxt2> is fixed.\n");
  printf("\t-t <number>:     number of encryptions (traces).\n");
  printf("\t-s <number>:     save sensor traces starting from sample 0 until sample <end>\n");
  printf("\t-c <number>:     calibration type\n");
  printf("\t\t- 0              use automatic calibration in hardware\n");
  printf("\t\t- 1              use default calibration value or specified calibration value using -idf and -idc\n");
  printf("\t\t- 2              skip the sensor calibration\n");
  printf("\t\t- 3              use automatic calibration in software solely using idc\n");
  printf("\t\t- 4              use automatic calibration in software using idc and idf\n");
  printf("\t-idf <number>: idc value. Value must be between 0 and 96.\n");
  printf("\t-idc <number>: idf value. Value must be between 0 and 32. \n");
  printf("\t-o:              save oscilloscope traces\n");
  printf("\t-d <dir-path>:   specify output directory\n");
  printf("\t-r <number>:     number of registers used. Needs to be specified when automatic calibration in software is used. Default: 128.\n");
  printf("\n\n\n");

  return;
}

int parse_args(int argc, char* argv[], config_t* config) {
  if(argc == 1) {
    return EXIT_SUCCESS;
  }

  if(argv == NULL) {
    fprintf(stderr, "Passed NULL argument string to parse_args\n");
    return EXIT_FAILURE;
  }

  for(int i = 1; i < argc; i++) {
    if(argv[i][1] == 'h') {
      print_help();
      exit(1);
    } else if(argv[i][1] == 'k') {
      i++;
      config->key_mode = atoi(argv[i]);
      if(config->key_mode > 2){
        printf("Unknown key mode : -k %d\n\n", config->key_mode);
        print_help();
        return EXIT_FAILURE;
      }
    }else if(argv[i][1] == 'r'){
      i++;
      int reg = atoi(argv[i]);
      if((reg!=128) && (reg!= 64) && (reg!=32) && (reg!=16)){
        printf("Given number of registers must be 128, 64, 32 or 16.\n");
        return EXIT_FAILURE;
      }
      config->registers = atoi(argv[i]);
    }else if(argv[i][1] == 'u' && argv[i][2] == 'k'){
      i++;
     const char *src = argv[i];
    char buffer[16];
    char *dst = buffer;
    char *end = buffer + sizeof(buffer);
    unsigned int u;
    int counter = 0;
    while (dst < end && sscanf(src, "%2x", &u) == 1)
    {
        *dst++ = u;
        src += 2;
        counter++;
    }
    if((counter != 16) || *src != '\0'){
      printf("Given key does not have size 16. Key size must be 16 bytes.\n");
      return EXIT_FAILURE;
    }
    memcpy(config->key, buffer, sizeof(buffer));
    }else if(argv[i][1] == 'p' && argv[i][2] == 'm') {
      i++;
      config->plain_mode = atoi(argv[i]);
      if(config->plain_mode > 2){
        printf("Unknown plaintext mode : -pm %d\n\n", config->plain_mode);
        print_help();
        return EXIT_FAILURE;
      }
    }else if(argv[i][1] == 'i'){
      if(argv[i][2] == 'd'){
        if(argv[i][3] == 'c'){
          i++;
        char buffer[4];
        int idc = atoi(argv[i]);
        if((idc < 0) || (idc > 32)){
        printf("idc value must be between 0 and 32\n");
        return EXIT_FAILURE;  
        }
        int f_toadd = idc / 8;
        int i=0;
        for(i=0;i<f_toadd;i++){
        memset(buffer+i, 0xff, 1);
        }
        int remainder = idc - f_toadd * 8;
        if(remainder==0){
        memset(buffer+i, 0x00, 1);
        }else if(remainder==1){
        memset(buffer+i, 0x80, 1);
        }else if(remainder==2){
        memset(buffer+i, 0xc0, 1);
        }else if(remainder==3){
        memset(buffer+i, 0xe0, 1);
        }else if(remainder==4){
        memset(buffer+i, 0xf0, 1);
        }else if(remainder==5){
        memset(buffer+i, 0xf8, 1);
        }else if(remainder==6){
        memset(buffer+i, 0xfc, 1);
        }else if(remainder==7){
        memset(buffer+i, 0xfe, 1);
        }
        i++;
        for(;i<sizeof(buffer); i++){
        memset(buffer+i, 0x00, 1);
        }
        memcpy(config->idc,buffer, sizeof(config->idc));
        }else if(argv[i][3] == 'f'){
          i++;
        char buffer[12];
        int idf = atoi(argv[i]);
        if((idf < 0) || (idf > 96)){
        printf("idf value must be between 0 and 96\n");
        return EXIT_FAILURE;  
        }
        int f_toadd = idf / 8;
        int i=0;
        for(i=0;i<f_toadd;i++){
        memset(buffer+i, 0xff, 1);
        }
        int remainder = idf - f_toadd * 8;
        if(remainder==0){
        memset(buffer+i, 0x00, 1);
        }else if(remainder==1){
        memset(buffer+i, 0x80, 1);
        }else if(remainder==2){
        memset(buffer+i, 0xc0, 1);
        }else if(remainder==3){
        memset(buffer+i, 0xe0, 1);
        }else if(remainder==4){
        memset(buffer+i, 0xf0, 1);
        }else if(remainder==5){
        memset(buffer+i, 0xf8, 1);
        }else if(remainder==6){
        memset(buffer+i, 0xfc, 1);
        }else if(remainder==7){
        memset(buffer+i, 0xfe, 1);
        }
        i++;
        for(;i<sizeof(buffer); i++){
        memset(buffer+i, 0x00, 1);
        }
        memcpy(config->idf,buffer, sizeof(config->idf));
        }
      }
    } else if(argv[i][1] == 't') {
      i++;
      config->n_traces = atoi(argv[i]);
    } else if(argv[i][1] == 'o') {
      config->osc_en = 1;
    } else if(argv[i][1] == 's') {
      i++;
      config->sensor_en = 1;
      config->n_samples = atoi(argv[i]);
    } else if(argv[i][1] == 'c') {
      i++;
      config->calib = atoi(argv[i]);
      if(config->calib > 5){
        printf("Unknown calibration mode : -c %d\n\n", config->calib);
        print_help();
        return EXIT_FAILURE;
      }
    } else if(argv[i][1] == 'd') {
      i++;
      memcpy(config->dump_path, argv[i], strlen(argv[i]));
      config->dump_path[strlen(argv[i])] = '\0';
    }else if((((argv[i][1] = 'p') && argv[i][2] == 't') && argv[i][3] == 'x') && argv[i][4] == 't'){
    //the user specified at least one plaintext. Store it in config->ptxt
    i++;
    const char *src = argv[i];
    char buffer[16];
    char *dst = buffer;
    char *end = buffer + sizeof(buffer);
    unsigned int u;
    int counter = 0;
    while (dst < end && sscanf(src, "%2x", &u) == 1)
    {
        *dst++ = u;
        src += 2;
        counter++;
    }
    if((counter != 16) || *src != '\0'){
      printf("Given plaintext does not have size 16. The size must be 16 bytes.\n\n");
      return EXIT_FAILURE;
    }
    memcpy(config->ptxt, buffer, sizeof(buffer));
    
    //check if the user specified two plaintexts
    i++;
    if(strlen(argv[i]) == 32){
    const char *src2 = argv[i];
    char buffer2[16];
    char *dst2 = buffer2;
    char *end2 = buffer2 + sizeof(buffer2);
    unsigned int u2;
    while (dst2 < end2 && sscanf(src2, "%2x", &u2) == 1)
    {
        *dst2++ = u2;
        src2 += 2;
    }
    memcpy(config->fixed_ptxt, buffer2, sizeof(buffer2));
    }else{
      i--;
    }
    }else {
      printf("Unknown argument: -%c\n\n", argv[i][1]);
      print_help();
      return EXIT_FAILURE;
    }
  }

  return EXIT_SUCCESS;

}


int init_config(config_t* config){

  if (config == NULL)
    return EXIT_FAILURE;
  
  config->key_mode     = 0; 
  config->plain_mode   = 0; 
  config->n_traces     = 10; 
  config->osc_en       = 0; 
  config->calib        = 0; 
  config->sensor_en    = 0; 
  config->n_samples    = 1024; 
  config->start_sample = 0; 
  config->dump_path[0] = '.'; 
  config->dump_path[1] = '\0'; 
  config->registers    = 128;
  unsigned char ptxt[16] = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
  unsigned char idf[12] = {0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xc0, 0x00, 0x00, 0x00, 0x00, 0x00};
  unsigned char idc[4] = {0xfc, 0x00, 0x00, 0x00};
  memcpy(config->idc, idc, sizeof(config->idc));
  memcpy(config->idf, idf, sizeof(config->idf));
  memcpy(config->ptxt, ptxt, sizeof(config->ptxt));
  memcpy(config->fixed_ptxt, ptxt, sizeof(ptxt));
  return EXIT_SUCCESS;

}

int print_config(config_t* config){

  if (config == NULL)
    return EXIT_FAILURE;
  
  printf("\nProgram configuration:\n");
  printf("\t- key mode: %d\n", config->key_mode);
  if(config->key_mode == 2){
  printf("\t- key used: 0x%x", config->key[0]);
  for(int j=1;j<sizeof(config->key)-1; j++)
    printf("%x", config->key[j]);
  printf("%x\n", config->key[sizeof(config->key)-1]);
  }
  printf("\t- plaintext mode: %d\n", config->plain_mode);
  printf("\t- number of traces: %d\n", config->n_traces);
  printf("\t- osciloscope enabled: %d\n", config->osc_en);
  printf("\t- calibration mode: %d\n", config->calib);
  printf("\t- sensor enabled: %d\n", config->sensor_en);
  printf("\t- starting sensor sample: %d\n", config->start_sample);
  printf("\t- number of sensor samples: %d\n", config->n_samples);
  printf("\t- idc_idf array used: 0x%x", config->idf[0]);
  for(int j=1;j<sizeof(config->idf); j++)
    printf("%x", config->idf[j]);
  printf("%x", config->idc[0]);
 for(int j=1;j<sizeof(config->idc); j++)
    printf("%x", config->idc[j]);
  printf("%x\n", config->idc[sizeof(config->idc)-1]);
  printf("\t- output path: %s\n\n", config->dump_path);
  return EXIT_SUCCESS;

}

void initialize_random(unsigned char array[16]){

  for (int i = 0; i < 16; i++) {
        array[i] = rand() % 256;
  }

  return;

}

void sbox_key_pt(int trace, unsigned char pt[16], unsigned char key[16]){

  if(trace == 0){
    for(int i=0; i<16; i++){
      pt[i]  = 0;
      key[i] = 0;
    }
  } else {

    for(int i=0; i<16; i++){
      pt[i]++;
      pt[i] = pt[i]%256;
    }

    if(trace%256 == 0 && trace != 0){
      for(int i=0; i<16; i++){
        key[i]++;
        key[i] = key[i]%256;
      }
    }

  }

  return;  

}

unsigned char hamming_weight(unsigned char byte) {

  unsigned char weight = 0;

  for(int i=0; i<(8*sizeof(byte)); i++){
    weight += (byte&(1<<i))>>i;
  }

  return weight;

}

