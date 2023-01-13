/*
 RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
 Copyright 2023, School of Computer and Communication Sciences, EPFL.

 All rights reserved. Use of this source code is governed by a
 BSD-style license that can be found in the LICENSE.md file. 
 */

#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include "usbtmc.h"
#include "oscilloscope.h"

#define SIZE 10000 * (sizeof(int)) // osc send measurements in byte form embedded in ints, p125
#define FILENAME_SIZE 50
#define FILENAME_SIZE_BIG 2048
#define BUFFER_OSC 40000

int get_Acq_param(int file) {
  write_file(file, "ACQuire?");

  char buffer[1000];

  read(file, buffer, 1000);
  buffer[1000] = '\0';

  printf("%s\n", buffer);

  return EXIT_SUCCESS;
}

int init_osc() {
  // open file for communication
  int osc = open("/dev/usbtmc0", O_RDWR);
  struct usbtmc_attribute attr;
  attr.attribute = USBTMC_ATTRIB_READ_MODE;
  attr.value = USBTMC_ATTRIB_VAL_READ;

  // set attribute for read / write procedure (read, and not fread)
  ioctl(osc, USBTMC_IOCTL_SET_ATTRIBUTE, &attr);

  // reset params
  clear(osc);

  // here setup interface: div etc..., needed?

  return osc;
}

int open_osc() {
  int osc = init_osc();

  // get identification of oscilloscope
  //get_id(osc);

  // setup params for data transfer
  setup_osc(osc);

  // read data
  read_osc(osc, 2);

  close(osc);

  return EXIT_SUCCESS;
}

int setup_osc(int osc) {
  write_file(osc, ":DATa:SOUrce CH1");
  write_file(osc, ":DATa:STARt 1");
  write_file(osc, ":DATa:STOP 10000");
  write_file(osc, ":DATa:ENCdg ASCIi");
  write_file(osc, ":DATa:WIDth 1");
  // write_file(osc, ":HEADer 1");
  // write_file(osc, ":VERBose");
  // write_file(osc, ":WFMOutpre?"); // probably not needed
  write_file(osc, ":HEADer 0");
  write_file(osc, ":ACQuire:STOPAfter RUNStop"); // maybe change this setting

  return EXIT_SUCCESS;
}

int quick_save(int osc, int id, int precision, char file_path[300]) {

  char pre_filename[300];
  sprintf(pre_filename, "%s/quicksave", file_path);
  char filename[FILENAME_SIZE_BIG];
  memset(filename, '\0', FILENAME_SIZE_BIG);

  set_filename(filename, id, pre_filename);

  write_file(osc, ":DATa:SOUrce CH1");
  write_file(osc, ":DATa:ENCdg ASCIi");
  write_file(osc, ":DATa:WIDth 1");
  write_file(osc, ":HEADer 0");
  write_file(osc, ":DATa:STARt 0");
  write_file(osc, ":DATa:STOP 10000");

  size_t size = SIZE * precision;
  char* buffer = (char *) malloc(size + 1);
  write_file(osc, ":CURVe?"); // transfer data from oscilloscope

  int readed = read(osc, buffer, size);
  buffer[readed] = '\0';

  printf("Oscilloscope: read %d from osc out of %ld\n", readed, size);

  FILE* f = fopen(filename, "w");
  fprintf(f, "%s\n", buffer);
  fclose(f);

  free(buffer);

  return EXIT_SUCCESS;
}

int trigger_save(int osc, int id, int precision, char file_path[300]) {

  char pre_filename[300];
  sprintf(pre_filename, "%s/trigger", file_path);
  char filename[FILENAME_SIZE_BIG];
  memset(filename, '\0', FILENAME_SIZE_BIG);

  set_filename(filename, id, pre_filename);

  write_file(osc, ":DATa:SOUrce CH2");
  write_file(osc, ":DATa:ENCdg ASCIi");
  write_file(osc, ":DATa:WIDth 1");
  write_file(osc, ":HEADer 0");
  write_file(osc, ":DATa:STARt 0");
  write_file(osc, ":DATa:STOP 10000");

  size_t size = SIZE * precision;
  char* buffer = (char *) malloc(size + 1);
  write_file(osc, ":CURVe?"); // transfer data from oscilloscope

  int readed = read(osc, buffer, size);
  buffer[size] = '\0';

  printf("Oscilloscope: read %d from osc out of %ld\n", readed, size);

  FILE* f = fopen(filename, "w");
  fprintf(f, "%s\n", buffer);
  fclose(f);

  free(buffer);

  return EXIT_SUCCESS;
}

int start_reccording(int osc) {
  write_file(osc, ":ACQuire:STATE ON");
  return EXIT_SUCCESS;
}

int read_osc(int osc, int id) {
  write_file(osc, ":ACQuire:STATE OFF");
  write_file(osc, ":CURVe?"); // transfer data from oscilloscope

  char* buffer = (char *) malloc(SIZE + 1);
  size_t read_ = read(osc, buffer, SIZE);

  printf("read %ld from oscilloscope\n", read_);

  buffer[SIZE] = '\0';

  //printf("buffer: %s\n", buffer); // read config

  //memset(buffer, '\0', SIZE);

  //read(osc, buffer, SIZE);
  //buffer[SIZE] = '\0';

  char filename[FILENAME_SIZE];
  memset(filename, '\0', FILENAME_SIZE);
  char prefix[] = "../results/test";

  set_filename(filename, id, prefix);
  printf("printing to filename %s\n", filename);

  FILE* f = fopen(filename, "ab+");
  fprintf(f, "%s\n", buffer);
  fclose(f);

  free(buffer);

  return EXIT_SUCCESS;
}

int get_id(int osc) {
  int en;

  // get oscilloscope identification
  int ret;
  if((ret = write(osc, "*IDN?\n", 6)) == -1) {
    en = errno;
    printf("Error during write: %s\n", strerror(en));
    return EXIT_FAILURE;
  }

  // read data (identification) from oscilloscope
  char buffer[4000];
  if((ret = read(osc, buffer, 4000)) == -1) {
    en = errno;
    printf("Error during read: %s\n", strerror(en));
    return EXIT_FAILURE;
  } else {
    buffer[ret] = 0;
    printf("ID: %s\n", buffer);
  }

  return EXIT_SUCCESS;
}

int clear(int osc) {
  int ret;
  if((ret = write(osc, "*CLS\n", 5)) == -1) {
    int en = errno;
    printf("Error during write: %s\n", strerror(en));
  }

  return EXIT_SUCCESS;
}

int write_file(int osc, const char* message) {
  
  char *message_cpy = (char *) malloc(strlen(message) + 1);
  strcpy(message_cpy, message);

  int ret;
  if((ret = write(osc, message, strlen(message))) == -1) {

    free(message_cpy);
    return EXIT_FAILURE;
  }

  free(message_cpy);
  return EXIT_SUCCESS;
}

int set_filename(char* s, int id, char* prefix) {
  size_t l = strlen(prefix);
  memcpy(s, prefix, l);
  sprintf(s + l, "%d", id);
  char tmp[16];
  sprintf(tmp, "%d", id);
  memcpy(s + l + strlen(tmp), ".csv", 4);



  return EXIT_SUCCESS;
}
