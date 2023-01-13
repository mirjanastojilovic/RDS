/*
 RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
 Copyright 2023, School of Computer and Communication Sciences, EPFL.

 All rights reserved. Use of this source code is governed by a
 BSD-style license that can be found in the LICENSE.md file. 
 */

#include <stdio.h>
#include <stdlib.h>
#include "ftdi_interface.h"

int baud_rates[] = {50, 75, 110, 134, 150, 200, // 6
                    300, 600, 1200, 1800, 2400, 4800, // 12
                    9600, 19200, 38400, 57600, 115200, // 17
                    230400, 460800, 576000, 921600}; // 21


int setup_device(int device, FT_HANDLE* handle) {
  FT_STATUS status;
  unsigned int number; // number of device connected

  if((status = FT_CreateDeviceInfoList(&number)) != FT_OK) {
    fprintf(stderr, "Can't create device info list\n");
    return EXIT_FAILURE;
  }

  if(number == 0) {
    fprintf(stderr, "No device detected\n");
    return EXIT_FAILURE;
  } else {
    //printf("%d devices available\n", number);
  }

  FT_DEVICE_LIST_INFO_NODE* devices = malloc(number * sizeof(FT_DEVICE_LIST_INFO_NODE));

  if((status = FT_GetDeviceInfoList(devices, &number)) != FT_OK) {
    fprintf(stderr, "Can't get device info list!\n");
    return EXIT_FAILURE;
  }
  
  // ----------------------------------------------------------------------------------------------
  int iNumDevs = 0;
  char serialNumbers[MAX_DEVICES][64];
  FT_STATUS ftStatus;

  char *serialNumbersPtr[MAX_DEVICES + 1];
  
  for(int i = 0; i < MAX_DEVICES; i++) {
    serialNumbersPtr[i] = serialNumbers[i];
  }
  serialNumbersPtr[MAX_DEVICES] = NULL;

  if((ftStatus = FT_ListDevices(serialNumbersPtr, &iNumDevs, FT_LIST_ALL | FT_OPEN_BY_SERIAL_NUMBER)) != FT_OK) {
    fprintf(stderr, "Can't list devices!\n");
    //return EXIT_FAILURE;
  }

  printf("\nAvailable devices %d\n",iNumDevs);

  if(ftStatus != FT_OK) {
    printf("Error: FT_ListDevices(%d)\n", (int)ftStatus);
    printf("Run script setupFTD.sh \n");
    return EXIT_FAILURE;
  }
  
  for(int i = 0; ( (i <MAX_DEVICES) && (i < iNumDevs) ); i++) {
    printf("Device %d Serial Number - %s\n", i, serialNumbers[i]);
  }
  printf("\n");


// ----------------------------------------------------------------------------------------------

  //print_devices(devices, number);

  int baud_rate = 9600;//baud_rates[13]; // same as the one used in their software

  // opening device
  if((status = FT_Open(device, handle)) != FT_OK || handle == NULL) {
    printf("can't open device\n");
    return EXIT_FAILURE;
  }

  printf("succesfully opened device %d, handle is %p\n", device, handle);

  if((status = FT_ResetDevice(*handle)) != FT_OK) {
    printf("can't reset device\n");
    return EXIT_FAILURE;
  }

  //setting device up
  if((status = FT_SetBaudRate(*handle, baud_rate)) != FT_OK) {
    printf("can't set baud rate\n");
    return EXIT_FAILURE;
  }

  if((status = FT_SetDataCharacteristics(*handle, FT_BITS_8, FT_STOP_BITS_2, FT_PARITY_EVEN)) != FT_OK) { // same as in their code
    printf("cant set data characteristics\n");
    return EXIT_FAILURE;
  }

  /*if((status = FT_SetDtr(*handle)) != FT_OK) {
    printf("Can't set Data Terminal Ready\n");
    return EXIT_FAILURE;
  }

  if((status = FT_SetFlowControl(*handle, FT_FLOW_RTS_CTS, 0, 0)) != FT_OK) {
    printf("can't set flow control\n");
    return EXIT_FAILURE;
    }*/

  /*if((status = FT_SetRts(*handle)) != FT_OK) {
    printf("can't set request to send bit\n");
    return EXIT_FAILURE;
    }*/

  if((status = FT_SetTimeouts(*handle, 3000, 3000)) != FT_OK) { // 3s
    printf("can't set timeout\n");
    return EXIT_FAILURE;
  }

  free(devices);

  return EXIT_SUCCESS;
}

void close_device(FT_HANDLE handle) {
  FT_STATUS status;

  if((status = FT_Close(handle)) != FT_OK) {
    printf("Closed device failed\n");
  }
}

int print_devices(FT_DEVICE_LIST_INFO_NODE* devices, unsigned int number) {
  if(devices == NULL) {
    return EXIT_FAILURE;
  }

  for(unsigned int i = 0; i < number; i++) {
    printf("Type: %d\n", devices[i].Type);
    printf("ID: %d\n", devices[i].ID);
    printf("LocId: %d\n", devices[i].LocId);
    printf("Flags: %d\n", devices[i].Flags);
    printf("Serial Number: %s\n", devices[i].SerialNumber);
    printf("Description: %s\n", devices[i].Description);
    printf("Handle: %p\n", devices[i].ftHandle);
  }

  return EXIT_SUCCESS;
}

int ft_read(char* buffer, unsigned int length_req, FT_HANDLE handle) {
  if(buffer == NULL) {
   printf("ft read, buffer null\n");
    return EXIT_FAILURE;
  }

  FT_STATUS status;
  unsigned int actual_read;

  //DWORD RxBytes = 0;
  //while(RxBytes <= 0){
  //  FT_GetQueueStatus(handle,&RxBytes);
  //  if(RxBytes <= 0){
  //    printf("Receive queue empty!\n");
  //  }
  //}

  if((status = FT_Read(handle, buffer, length_req, &actual_read)) != FT_OK) {
    fprintf(stderr, "can't read from device!\n");
    return EXIT_FAILURE;
  }

  if(length_req != actual_read) {
    fprintf(stderr, "read timeout, bytes read = %d!\n", actual_read);
    return EXIT_FAILURE;
  }

  return EXIT_SUCCESS;
}

int ft_write(char* buffer, unsigned int length_req, FT_HANDLE handle) {
  if(buffer == NULL) {
  printf("ft write \n");
    return EXIT_FAILURE;
  }

  FT_STATUS status;
  unsigned int actual_writen;

  if((status = FT_Write(handle, buffer, length_req, &actual_writen)) != FT_OK) {
    fprintf(stderr, "can't write to device!\n");
    return EXIT_FAILURE;
  }

  if(length_req != actual_writen) {
    fprintf(stderr, "write partially done!\n");
    return EXIT_FAILURE;
  }

  return EXIT_SUCCESS;
}
