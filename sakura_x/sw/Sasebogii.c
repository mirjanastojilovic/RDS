/*
 RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
 Copyright 2023, School of Computer and Communication Sciences, EPFL.

 All rights reserved. Use of this source code is governed by a
 BSD-style license that can be found in the LICENSE.md file. 
 */

#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include "Sasebogii.h"

#define A 0
#define B 1

FT_HANDLE* sasebo_init() {
  FT_HANDLE* handle = calloc(1, sizeof(FT_HANDLE));

  if(setup_device(B, handle) == EXIT_FAILURE) {
    return NULL;
  }

  return handle;
}

int select_comp(FT_HANDLE handle) {
  // select cipher
  //sasebo_write_unit(handle, ADDR_IPSEL, 0x0001);
  //sasebo_write_unit(handle, ADDR_IPSEL + 0x0002, 0x0000);

  // reset
  sasebo_write_unit(handle, ADDR_CONT, 0x0004);
  sasebo_write_unit(handle, ADDR_CONT, 0x0000);

  // select output
  //sasebo_write_unit(handle, ADDR_OUTSEL, 0x0001);
  //sasebo_write_unit(handle, ADDR_OUTSEL + 0x0002, 0x0000);

  return EXIT_SUCCESS;
}

int sasebo_read(FT_HANDLE handle, char* buffer, size_t len, int addr) {
  if(buffer == NULL) {
    fprintf(stderr, "passed NULL args to sasebo_read\n");
    return EXIT_FAILURE;
  }

  size_t length;
  if((len % 2) == 0) {
    length = 3 * (len / 2);
  } else {
    length = 3 * ((len + 1) / 2);
  }

  // format buffer according to sasebo protocol
  // TODO make sure not filling buffer
  char* buf = (char*)malloc(sizeof(char) * length);

  for(size_t i = 0; i < len / 2; i++) {
    buf[3*i] = 0x00; // read
    buf[3*i + 1] = ((addr + i*2) >> 8) & 0xFF;
    buf[3*i + 2] = (addr + i*2) & 0xFF;
  }

  if(ft_write(buf, length, handle) == EXIT_FAILURE) {
    free(buf);
    return EXIT_FAILURE;
  }

  sleep(0.5); // make sure write done

  if(ft_read(buffer, len, handle) == EXIT_FAILURE) {
    free(buf);
    return EXIT_FAILURE;
  }

  free(buf);
  return EXIT_SUCCESS;
}

int sasebo_write(FT_HANDLE handle, char* buffer, size_t len, int addr) {
  if(buffer == NULL) {
    fprintf(stderr, "passed NULL args to sasebo_write\n");
    return EXIT_FAILURE;
  }

  size_t length;
  if((len % 2) == 0) {
    length = 5 * (len / 2);
  } else {
    length = 5 * ((len + 1) / 2);
  }

  // format buffer according to sasebo protocol
  // TODO make sure not filling buffer
  char* buf = (char*)calloc(1, sizeof(char) * length);

  for(size_t i = 0; i < length / 5; i++) {
    buf[5*i] = 0x01; // write
    buf[5*i + 1] = ((addr + i*2) >> 8) & 0xFF;
    buf[5*i + 2] = (addr + i*2) & 0xFF;
    buf[5*i + 3] = buffer[2*i];
    buf[5*i + 4] = buffer[2*i + 1];
  }


  if(ft_write(buf, length, handle) == EXIT_FAILURE) {
    free(buf);
    return EXIT_FAILURE;
  }

  free(buf);
  return EXIT_SUCCESS;
}

int sasebo_read_unit(FT_HANDLE handle, int addr) {
  char buffer[3];
  buffer[0] = (unsigned char)0x00; // say that we want to read
  buffer[1] = (unsigned char)((addr >> 8) & 0xFF);
  buffer[2] = (unsigned char)(addr & 0xFF);

  if(ft_write(buffer, 3, handle) == EXIT_FAILURE) {
  printf("sasebo read unit 1 \n");
    return EXIT_FAILURE;
  }

  sleep(0.5); // make sure write operation complete (useless...)

  if(ft_read(buffer, 2, handle) == EXIT_FAILURE) {
  printf("sasebo read unit 2\n");
    return EXIT_FAILURE;
  }

  return ((int)(buffer[0] << 8) & 0xFF) + (int)(buffer[1] & 0xFF);
  //return EXIT_SUCCESS;
}

int sasebo_write_unit(FT_HANDLE handle, int addr, int data) {
  char buffer[5];
  buffer[0] = 0x01; // say that we want to write
  buffer[1] = (addr >> 8) & 0xFF;
  buffer[2] = addr & 0xFF;
  buffer[3] = (data >> 8) & 0xFF;
  buffer[4] = data & 0xFF;

  if(ft_write(buffer, 5, handle) == EXIT_FAILURE) {
    return EXIT_FAILURE;
  }

  return EXIT_SUCCESS;
}

void sasebo_close(FT_HANDLE* handle) {
  close_device(*handle);
  free(handle);
}


int sasebo_purge(FT_HANDLE handle){

  FT_STATUS ftStatus;
  ftStatus = FT_Purge(handle, FT_PURGE_RX | FT_PURGE_TX); // Purge both Rx and Tx buffers
  if (ftStatus == FT_OK) {
    return EXIT_SUCCESS;
  }else {
    return EXIT_FAILURE;
  }

}
