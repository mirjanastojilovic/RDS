 /*
 * uart.c
 *
 *  Created on: Aug 5, 2019
 *      Author: Cristian Fatu
 *      Implements basic UART functionality, over Uart Lite linux driver, using termios.
 *      After booting linux, a device like "/dev/ttyUL1" must be present.
 *      These functions work in both canonic and not canonic modes.
 *      In the canonic communication mode, the received chars can be retrieved by read only after \n is detected.
 *      In the non canonic communication mode, the received chars can be retrieved by read as they are received.
 * 
 *  Notes from  Ognjen Glamočanin, David Spielmann, Mirjana Stojilović: This file is taken from https://github.com/Digilent/uart_demo_linux/blob/master/uart.c
 */
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <termios.h>
#include "uart.h"

/*
Parameters:

      struct UartDevice* dev	- pointer to the UartDevice struct
      unsigned char canonic		- communication mode
              1 	- canonic communication (chars are only received after \n is detected).
              0		- non canonic communication (chars are received as they arrive over UART).

Return value:
    UART_FAILURE	-1	failure
    UART_SUCCESS	0	success

Description:
    Initializes the UART device.
    When calling the function, the device name (usually "/dev/ttyUL1") must be filled in dev->name and the baud rate must be filled in dev->rate.
    The canonic function parameter indicates communication mode (canonic or not).
    In the canonic communication mode, the received chars can be retrieved by read only after \n is detected.
    In the non canonic communication mode, the received chars can be retrieved by read as they are received, as the non canonic mode is configured with no wait.
*/
int uartStart(struct UartDevice* dev, unsigned char canonic) {
    struct termios *tty;
    int fd;
    int rc;

    fd = open(dev->name, O_RDWR | O_NOCTTY);
    if (fd < 0) {
        printf("%s: failed to open file descriptor for file %s\r\n", __func__, dev->name);
        return UART_FAILURE;
    }

    tty = calloc(1, sizeof(*dev->tty));
    if (!tty) {
        printf("%s: failed to allocate tty instance\r\n", __func__);
        return UART_FAILURE;
    }
//	memset(tty, 0, sizeof(struct termios));


    /*
      BAUDRATE: Set bps rate. You could also use cfsetispeed and cfsetospeed.
      CRTSCTS : output hardware flow control (only used if the cable has
                all necessary lines. See sect. 7 of Serial-HOWTO)
      CS8     : 8n1 (8bit,no parity,1 stopbit)
      CLOCAL  : local connection, no modem contol
      CREAD   : enable receiving characters
    */
    tty->c_cflag = dev->rate | CRTSCTS | CS8 | CLOCAL | CREAD;
    if (canonic)
    {
        // canonic

        /*
            IGNPAR  : ignore bytes with parity errors
            ICRNL   : map CR to NL (otherwise a CR input on the other computer
                    will not terminate input)
            otherwise make device raw (no other input processing)
        */
         tty->c_iflag = IGNPAR | ICRNL;
        /*
            ICANON  : enable canonical input
            disable all echo functionality, and don't send signals to calling program
        */
        tty->c_lflag = ICANON;
    }
    else
    {
        // not canonic
        /*
            IGNPAR  : ignore bytes with parity errorsc_cc[VTIME]
        */
         tty->c_iflag = IGNPAR;
        /* set input mode (non-canonical, no echo,...) */
        tty->c_lflag = 0;
        /* Do not wait for data */
        tty->c_cc[VTIME]    = 0;   /* inter-character timer unused */
	// 0.5s read timeout
        tty->c_cc[VMIN]     = 5;   /* blocking read until 5 chars received */
    }

    /*
     Raw output.
    */
    tty->c_oflag = 0;



    /* Flush port */
    tcflush(fd, TCIFLUSH);

    /* Apply attributes */
    rc = tcsetattr(fd, TCSANOW, tty);
    if (rc) {
        printf("%s: failed to set TCSANOW attr\r\n", __func__);
        return UART_FAILURE;
    }

    dev->fd = fd;
    dev->tty = tty;

    return UART_SUCCESS;
}

/*
Parameters:

      struct UartDevice* dev	- pointer to the UartDevice struct
      char *data				- pointer to the array of chars to be sent over UART
      int size
          positive value - number of chars to be sent over UART
          -1			 - indicates that all the chars until string terminator \0 will be sent

Return value:
    number of chars sent over UART


Description:
    This function sends a number of chars over UART.
    If the size function parameter is -1 then all the characters until string terminator \0 will be sent.
*/
int uartSend(struct UartDevice* dev, char *data, int size) {
    int sent = 0;
    if(size == -1)
    {
        size = strlen(data);
    }
    sent = write(dev->fd, data, size);

#ifdef DEBUG
        printf("%s: sent %d characters\r\n", __func__, sent);
#endif

    return sent;
}

/*
Parameters:

      struct UartDevice* dev	- pointer to the UartDevice struct
      char *data				- pointer to the array of chars to hold the cars revceived over UART
      int size_max				- the maximum number of characters to be received

Return value:
    number of chars received over UART


Description:
    This function receives characters over UART.
    In the canonic communication mode, the received chars will be retrieved by read only after \n is detected.
    In the non canonic communication mode, the received chars will be retrieved by read as they are received, as the non canonic mode is configured with no wait.
*/
int uartReceive(struct UartDevice* dev, char* data, int size_max) {
    int received = 0;

#ifdef DEBUG
//	printf("%s: receiving characters %d\r\n", __func__, size_max);
#endif

    received = read(dev->fd, data, size_max - 1);
    //data[received] = '\0'; // REMOVED TERMINATION CHARACTER BECAUSE OSEF

#ifdef DEBUG
//	if(received > 0)
//		printf("%s: received %d characters\r\n", __func__, received);
//	else
//		printf("%s: r%d/%d\r\n", __func__, received, size_max);

#endif

    return received;

}

int uartStop(struct UartDevice* dev) {
    free(dev->tty);

    return UART_SUCCESS;

}
