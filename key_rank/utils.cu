/*
 RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
 Copyright 2023, School of Computer and Communication Sciences, EPFL.

 All rights reserved. Use of this source code is governed by a
 BSD-style license that can be found in the LICENSE.md file. 
 */

#include "utils.cuh"

void print_help() {
  printf("HELP\n");
  printf("\n==================================================\n");
  printf("CPA Key Rank Estimation Attack\n");
  printf("\n==================================================\n");
  printf("\nShort summary:\n");
  printf("\t- This program takes the power consumption traces, ciphertexts, and the last round key and computes the log2 key rank estimation metric using CPA.\n");
  printf("\t- The ouput of this program are the upper and lower bounds of the log2(key rank) metric, in a .csv file.\n");
  printf("\n==================================================\n");
  printf("\nProgram arguments:\n");
  printf("\t-h:              print help.\n");
  printf("\t-k <hexvalue>:   last round key.\n");
  printf("\t-t <file-path>:  path to trace file.\n");
  printf("\t-c <file-path>:  path to ciphertext file.\n");
  printf("\t-nt <number>:    number of encryptions (traces).\n");
  printf("\t-ns <number>:    number of samples per trace (trace lenght).\n");
  printf("\t-ss <number>:    step size for the attack.\n");
  printf("\t-o <dir-path>:   output directory.\n");
  printf("\n\n\n");

  return;
}

int parse_args(int argc, char* argv[], config_t* config) {

  int used_arguments = 0;

  if(argc == 1) {
    print_help();
    fprintf(stderr, "No arguments passed!\n");
    return EXIT_FAILURE;
  }

  if(argv == NULL) {
    fprintf(stderr, "Passed NULL argument string to parse_args\n");
    return EXIT_FAILURE;
  }

  for(int i = 1; i < argc; i++) {
    if(argv[i][1] == 'h') {
      print_help();
      exit(1);
    } else if(argv[i][1] == 'k'){
      i++;
      const char *src = argv[i];
      int buffer[16];
      int *dst = buffer;
      int *end = buffer + sizeof(buffer);
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
      used_arguments++;
    } else if(argv[i][1] == 't') {
      i++;
      memcpy(config->trace_path, argv[i], strlen(argv[i]));
      config->trace_path[strlen(argv[i])] = '\0';
      used_arguments++;
    } else if(argv[i][1] == 'c') {
      i++;
      memcpy(config->ciphertext_path, argv[i], strlen(argv[i]));
      config->ciphertext_path[strlen(argv[i])] = '\0';
      used_arguments++;
    } else if(argv[i][1] == 'n' && argv[i][2] == 't') {
      i++;
      config->n_traces = atoi(argv[i]);
      used_arguments++;
    } else if(argv[i][1] == 'n' && argv[i][2] == 's') {
      i++;
      config->n_samples = atoi(argv[i]);
      used_arguments++;
    } else if(argv[i][1] == 's' && argv[i][2] == 's') {
      i++;
      config->step_size = atoi(argv[i]);
      used_arguments++;
    } else if(argv[i][1] == 'o') {
      i++;
      memcpy(config->dump_path, argv[i], strlen(argv[i]));
      config->dump_path[strlen(argv[i])] = '\0';
      used_arguments++;
    }else {
      printf("Unknown argument: -%c\n\n", argv[i][1]);
      print_help();
      return EXIT_FAILURE;
    }
  }

  if(used_arguments != 7){
    printf("Not enough arguments used. All arguments except help need to be specified!\n");
    print_help();
    return EXIT_FAILURE;
  } else {
    return EXIT_SUCCESS;
  }

}

int init_config(config_t* config){

  if (config == NULL)
    return EXIT_FAILURE;


  unsigned char key[16] = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
  memcpy(config->key, key, sizeof(config->key));
  config->dump_path[0] = '.'; 
  config->dump_path[1] = '\0'; 
  config->trace_path[0] = '.'; 
  config->trace_path[1] = '\0'; 
  config->ciphertext_path[0] = '.'; 
  config->ciphertext_path[1] = '\0'; 
  config->n_traces     = 100; 
  config->n_samples    = 128; 
  config->step_size    = 10; 
  return EXIT_SUCCESS;

}

int print_config(config_t* config){

  if (config == NULL)
    return EXIT_FAILURE;
  
  printf("\nProgram configuration:\n");
  printf("\t- key: 0x%x", config->key[0]);
  for(int j=1;j<16; j++)
    printf("%x", config->key[j]);
  printf("\n");
  printf("\t- trace file path: %s\n\n", config->trace_path);
  printf("\t- ciphertext file path: %s\n\n", config->ciphertext_path);
  printf("\t- number of traces: %d\n", config->n_traces);
  printf("\t- number of trace samples: %d\n", config->n_samples);
  printf("\t- step size for attack: %d\n", config->step_size);
  printf("\t- output path: %s\n\n", config->trace_path);

  return EXIT_SUCCESS;

}



