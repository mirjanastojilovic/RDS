/*
 RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
 Copyright 2023, School of Computer and Communication Sciences, EPFL.

 All rights reserved. Use of this source code is governed by a
 BSD-style license that can be found in the LICENSE.md file. 
 */

#include <string.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[]) {

  FILE * traces_chained_bin;
  FILE * traces_chained_csv;

  if(argc != 4){
    printf("Usage:\n./bin2csv n_traces n_samples file_path\n");
    return 0;
  }

  int N_TRACES = atoi(argv[1]);
  int N_SAMPLES = atoi(argv[2]);
  char * file_path = argv[3];
  
  char file_name[512];

  sprintf(file_name, "%s/sensor_traces_hw_%dk.bin", file_path, (N_TRACES/1000));
  traces_chained_bin = fopen(file_name, "rb");
  if(traces_chained_bin == NULL){
    printf("Error in opening power traces file!\n");
    printf("File path: %s\n", file_name);
    return 0;
  }

  sprintf(file_name, "%s/sensor_traces_hw_%dk.csv", file_path, (N_TRACES/1000));
  traces_chained_csv = fopen(file_name, "w");
  if(traces_chained_csv == NULL){
    printf("Error in opening power traces file!\n");
    printf("File path: %s\n", file_name);
    return 0;
  }

  unsigned char ** power_traces;
  power_traces = (unsigned char **)malloc(N_TRACES*sizeof(unsigned char *));
  for(int i=0; i<N_TRACES; i++)
    power_traces[i]=(unsigned char *)malloc(N_SAMPLES*sizeof(unsigned char));

  for(int i=0; i<N_TRACES; i++)
    fread(power_traces[i], sizeof(power_traces[0][0]), N_SAMPLES, traces_chained_bin);
  
  for(int i=0; i<N_TRACES; i++){
    for(int j=0; j<N_SAMPLES; j++){
      if(j != (N_SAMPLES-1))
        fprintf(traces_chained_csv, "%d,", power_traces[i][j]);
      else
        fprintf(traces_chained_csv, "%d\n", power_traces[i][j]);
    }
  }

  
  fclose(traces_chained_bin);
  fclose(traces_chained_csv);

  return 0;
  
}
