/*
 RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
 Copyright 2023, School of Computer and Communication Sciences, EPFL.

 All rights reserved. Use of this source code is governed by a
 BSD-style license that can be found in the LICENSE.md file. 
 */

#include "data_utils.h"

#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>
#include <time.h>
#include <unistd.h>

#include "aes_soft.h"
#include "string.h"

static const char *delims[11] = {URT_DELIM, KEY_DELIM, MSK_DELIM, DAT_DELIM,
                                 NMS_DELIM, CIP_DELIM, TRC_DELIM, KMD_DELIM,
                                 DMD_DELIM, NTR_DELIM, DMP_DELIM};

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
/* * * * * * * * Serial Device File Config and I/O Functions * * * * * * * * */
/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

/*
 *   Configures the tty interface of the UART device
 *
 *   Non-canonical, 8-bit, no parity, 1 SB and no FC
 *   VMIN = 0, VTIME = 1
 *
 *   Parameters: fd       - open file descriptor to tty device
 *               speed    - baudrate
 *
 *   Returns   : 0 if all good, -1 in case of error
 */
int set_interface_attribs(int fd, int speed) {
    struct termios tty;

    if (tcgetattr(fd, &tty) < 0) {
        printf("Error from tcgetattr: %s\n", strerror(errno));
        return -1;
    }

    cfsetospeed(&tty, (speed_t)speed);
    cfsetispeed(&tty, (speed_t)speed);

    tty.c_cflag |= (CLOCAL | CREAD); /* ignore modem controls */
    tty.c_cflag &= ~CSIZE;
    tty.c_cflag |= CS8;      /* 8-bit characters */
    tty.c_cflag &= ~PARENB;  /* no parity bit */
    tty.c_cflag &= ~CSTOPB;  /* only need 1 stop bit */
    tty.c_cflag &= ~CRTSCTS; /* no hardware flowcontrol */

    /* setup for non-canonical mode */
    tty.c_iflag &=
        ~(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL | IXON);
    tty.c_lflag &= ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN);
    tty.c_oflag &= ~OPOST;

    /* fetch bytes as they become available */
    tty.c_cc[VMIN] = 0;
    tty.c_cc[VTIME] = 1;

    if (tcsetattr(fd, TCSANOW, &tty) != 0) {
        printf("Error from tcsetattr: %s\n", strerror(errno));
        return EXIT_FAILURE;
    }
    return 0;
}

/*
 *   Configures the min bytes read parameter of the tty UART device file
 *
 *   Parameters: fd       - open file descriptor to tty device
 *               mcount   - set min number of bytes per read (before timeout)
 */
void set_mincount(int fd, int mcount) {
    struct termios tty;

    if (tcgetattr(fd, &tty) < 0) {
        printf("Error tcgetattr: %s\n", strerror(errno));
        return;
    }

    tty.c_cc[VMIN] = mcount ? 1 : 0;
    tty.c_cc[VTIME] = 5; /* half second timer */

    if (tcsetattr(fd, TCSANOW, &tty) < 0)
        printf("Error tcsetattr: %s\n", strerror(errno));
}

/*
 *   Writes numBytes from buffer to the already configured and open file
 * assigned to fd.
 *
 *   Note that the bytes from the end of the buffer are written first.
 *
 *   Parameters: fd      - file descriptor of the opened output file
 *               buffer  - array of bytes containing the data to be written
 *               numBytes- number of bytes to write
 *
 *   Returns : -1 in case of errors, otherwise the number of bytes that were
 * effectively written
 */
int write_bytes(int fd, const uint8_t *buffer, size_t numBytes) {
    int ret, bytes_written = 0;
    const uint8_t *pos = buffer + numBytes - 1;
    for (; pos >= buffer; pos--) {
        ret = write(fd, pos, 1);
        if (ret < 1) {
            fprintf(stderr, "Error writing to serial file : %d B written\n",
                    ret);
            break;
        }
        bytes_written++;
    }
    tcdrain(fd);
    return bytes_written;
}

/*
 *   Reads at most numBytes from fd to the already allocated buffer.
 *
 *   Note that the buffer will be filled from its end (buffer+numByte-1 -->
 * buffer)
 *
 *   Parameters: fd        - file descriptor of the opened input file
 *               buffer    - array of bytes to be filled with the data read from
 * fd numBytes  - number of bytes to read msTimeout - timeout value is
 * milliseconds
 *
 *   Returns : -1 in case of errors, otherwise the number of bytes that were
 * effectively read
 */
int read_bytes(int fd, uint8_t *buffer, size_t numBytes) {
    int ret;
    size_t bytes_read = 0;
    uint8_t *pos = buffer + numBytes - 1;
    do {
        ret = read(fd, pos - bytes_read, 1);
        //printf("byted read %d \n", bytes_read);

        if (ret < 0) {
            fprintf(stderr, "Error reading from serial file : %lu B read\n",
                    bytes_read);
            return bytes_read;
        }
        bytes_read += ret;

    } while (bytes_read < numBytes);

    return bytes_read;
}

/*
 *  Closes the tty device file, reopens it, reconfigures it, resets the AES and
 * restore the values from state in the inputs and outputs structures.
 *
 *  Parameters : config   - structure containing the file descriptor and path to
 * the tty device file inputs   - input structure to restore (key, masks and
 * plaintext) outputs  - output structure to restore (cipher, cipher_chained)
 *               state    - structure with saved values used to restore the
 * others
 *
 *  Returns    : EXIT_SUCCESS if all went well, EXIT_FAILURE otherwise.
 *
 */
int reinit_fpga(config_t *config, input_t *inputs, output_t *outputs,
                state_t *state) {
    close(config->tty_fd);

    config->tty_fd = open(config->tty_dev_path, O_RDWR | O_NOCTTY | O_SYNC);
    if (config->tty_fd < 0) return EXIT_FAILURE;

    if (set_interface_attribs(config->tty_fd, B115200) == EXIT_FAILURE) {
        close(config->tty_fd);
        return EXIT_FAILURE;
    }

    reset_loop(config);

    memcpy(inputs->key, state->key, sizeof(state->key));
    memcpy(inputs->plaintext, state->plain, sizeof(state->plain));
    memcpy(outputs->cipher, state->cipher, sizeof(state->cipher));
    memcpy(outputs->cipher_chained, state->cipher_chained,
           sizeof(state->cipher_chained));

    return EXIT_SUCCESS;
}

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
/* * * * * * User Input Parsing and Data Structure Initialisation  * * * * * */
/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

/*
 *   This function reads the content of the param buffer and uses it to fill the
 * user's structure. If the parameter is a path to a file, the path, a pointer
 * to the open file and the value read in the file are stored in filepath, fp
 * and value. If param contains a (string) value, it is parsed and placed into
 * value. fp is set to null and filepath is kept empty.
 *
 *   Example : 0x1234 --> [0x12, 0x34]
 *
 *   Parameters: param    - pointer to the parameter string to be read
 *               filepath - pointer string buffer to be filled with the
 * parameter's file, if any fp       - pointer to the parameter's file pointer
 * to be opened, if any value    - pointer to the parameter's byte array to be
 * filled  
 */
void get_value(char *param, file_path *filepath, FILE **fp, word_t *value) {
    if (isdigit(param[0])) {
        parse_hex(param, value);
        *fp = NULL;
    } else {
        // Param is the path to the file
        // open the file
        // read and parse the content
        char value_s[40];

        *fp = fopen(param, "r");
        fgets(value_s, 40, *fp);

        parse_hex(value_s, value);

        /* Record path to file for log purposes */
        strcpy(*filepath, param);
    }
}

/*
 *   This function reads the content of the param buffer and uses it to fill the
 * user's structure. If the parameter is a path to a file: the path, a pointer
 * to the open file and the value read in the file are stored in filepath, fp
 * and value. If param contains a (string) value: it is parsed and placed into
 * "value". *fp is set to null and filepath is kept empty.
 *
 *   num_value elements will be read and parsed from the params array. Each of
 * those can be either an hexadecimal string value or a path to a file
 * containing a value (although having a consistent way to provide input is
 * preferred).
 *
 *   Parameters: params   - pointer to an array of values for the same parameter
 * (e.g. several masks) offset   - index offset at which to start reading the
 * parameter values filepath - pointer string buffer to be filled with the
 * parameter's file, if any fp       - pointer to the parameter's file pointer
 * to be opened, if any value    - pointer to the parameter's array of values
 *               num_value- number of values to be read in the array of
 * parameter
 */
void get_values(char *params[], int offset, file_path *file_path, FILE **fp,
                word_t **value, size_t num_value) {
    *value = (word_t *)malloc(num_value * sizeof(word_t));

    for (size_t i = 0; i < num_value; i++) {
        if (isdigit(params[offset + i][0])) {
            parse_hex(params[offset + i], value[i]);
            *fp = NULL;
        } else {
            // Param is the path to the file
            // open the file
            // read and parse the content
            char value_s[40];

            *fp = fopen(params[offset + i], "r");
            fgets(value_s, 40, *fp);

            parse_hex(value_s, value[i]);

            /* Record path to file for log purposes */
            strcpy(*file_path, params[offset + i]);
        }
    }
}

/*
 *  If param contains a string representation of an hexadecimal value, it will
 * be parsed and placed into "value". If it contains the path to a file
 * containing the value, the file is opened and the first 32 characters are read
 * and parsed to fill the array.
 *
 *  Only the first 32 characters will be read and the array is filled from the
 * lowest byte toward the highest
 *
 *  E.g : "0123456789" --> [0x1, 0x23, 0x45, 0x67, 0x89]
 *
 *  Parameters  : param   - String containing the value in hexadecimal format or
 * the path to the file containing the value value   - pointer to an allocated
 * array in which to store the value
 *
 */
void get_hex_value(char *param, word_t *value) {
    if (isdigit(param[0])) {
        parse_hex(param, value);
    } else {
        // Param is the path to the file
        // open the file
        // read and parse the content
        char value_s[40];
        FILE *fp;
        fp = fopen(param, "r");

        fgets(value_s, 40, fp);

        parse_hex(value_s, value);

        fclose(fp);
    }
}

/*
 *   Parses a textual input (in hex format LSB first) to an array of bytes
 *
 *   Example : 0x1234 --> [0x12, 0x34]
 *
 *   Parameters: param    - pointer to the string hexadecimal number to be read
 *               value    - pointer to the byte array to be filled
 */
void parse_hex(char *param, word_t *value) {
    const char *pos = param;

    for (size_t i = 0; i < NUM_BYTES; i++) {
        sscanf(pos, "%2hhx", &((uint8_t *)value)[i]);
        pos += 2;
    }
}

/*
 *   Print the content of the buffer (LSB first) in hex format
 *
 *   Parameters: buffer    - pointer to data to print
 *               num_bytes - number of bytes to print
 *               output    - open file descriptor
 *
 */
void print_hex_word(uint8_t *buffer, size_t num_bytes, FILE *output) {
    for (size_t i = 0; i < num_bytes; i++) {
        fprintf(output, "%x", buffer[i] & 0xFF);
    }
    fprintf(output, "\n");
}

/*
 *   Parses and prints the content of the buffer in hex format and CSV as
 * follows (header included)
 *
 *   sensor, t_test_fail, t_test_valid_p, t_test_valid, aes_busy
 *
 *   Parameters: traces    - pointer to data to print
 *               num_traces- number of traces to print (2B each)
 *               output    - open file descriptor
 *
 */
void print_traces(uint8_t *traces, uint16_t num_traces, FILE *output) {
    fprintf(output,
            "sensor, t_test_fail, t_test_valid_p, t_test_valid, aes_busy\n");
    for (size_t i = 0; i < 2 * num_traces; i += 2) {
        fprintf(output, "%x,", traces[i] & 0xFF);
        fprintf(output, "%x,", (traces[i + 1] >> 0) & 0x1);
        fprintf(output, "%x,", (traces[i + 1] >> 1) & 0x1);
        fprintf(output, "%x,", (traces[i + 1] >> 2) & 0x1);
        fprintf(output, "%x,", (traces[i + 1] >> 3) & 0x1);
        fprintf(output, "\n");
    }
}

/*
 *  Generates a random 16-byte value that is placed in dst
 *
 *  Parameters :  dst   - Allocated array in which to store the random value
 *
 */
void gen_random_word(word_t dst) {
    // time_t t;
    for (size_t i = 0; i < NUM_BYTES; i++) {
        // srand((unsigned) time(&t));
        dst[i] = (size_t)rand() % 256;
    }
}

/*
 *   Reads the arg string and determines whether it correspond to one of the
 * predefined options for setting parameters
 *
 *   Parameters: args    - String of character to be read
 *
 *   Returns : -1 if args does not correspond to any option parameter, other the
 * index of the parameter in the static constant array DELIM
 */
int get_delim(char *arg) {
    for (size_t i = 0; i < 11; i++) {
        if (strcmp(arg, delims[i]) == 0) return i;
    }
    return -1;
}

/*
 *   Reads the array of string argv to determine the number of values provided
 * before the next type of parameter
 *
 *   Parameters: argv    - array of string containing all the command's
 * parameters offset  - offset at which to start counting the parameter's value
 *               argc    - total size of argv
 *
 *   Returns : The number hexa/path value in argv between 'offset' and the next
 * option parameter
 */
size_t get_number_of_masks(char *argv[], int offset, int argc) {
    int i = offset;
    for (; i < argc; i++) {
        if (get_delim(argv[i]) >= 0) break;
    }
    return i - offset;
}

/*
 *   Parses the array of command's parameters provided by the user and fills the
 * files_t and data_full_t structures for the experiment
 *
 *   All necessary values that are provided by the user's input argv are filled
 * with default values
 *
 *   Parameters: argc_offset - index at which to start parsing elements in argv
 *               argc        - size of argv
 *               argv        - array of string containing the user's parameters
 * input data        - structure to be filled with the user's input files -
 * structure to be filled with the user's input
 *
 *   Returns : -1 in case of errors, 0 if all goes well
 */
int parse_command(size_t argc_offset, int argc, char *argv[], data_full_t *data,
                  files_t *files) {
    bool params_done[6] = {false};
    for (int i = argc_offset; i < argc; i++) {
        /*
         switch (get_delim(argv[i])){
        case 0: // UART
        case 1: //KEY
            // etc...
        }
        */

        if (strcmp(URT_DELIM, argv[i]) == 0) {
            int temp_fd;
            params_done[0] = true;
            strcpy(files->tty_dev_path, argv[i + 1]);

            temp_fd = open(argv[i + 1], O_RDWR | O_NOCTTY | O_SYNC);
            if (temp_fd < 0) {
                fprintf(stderr, "Error opening %s: %s\n", argv[i + 1],
                        strerror((errno)));
                return -1;
            }

            set_interface_attribs(temp_fd, B115200);
            i++;
        } else if (strcmp(KEY_DELIM, argv[i]) == 0) {
            params_done[1] = true;
            get_value(argv[i + 1], &(files->key_path), &(files->k_file),
                      &(data->key));
            i++;
        } else if (strcmp(MSK_DELIM, argv[i]) == 0) {
            params_done[2] = true;
            data->num_mask = 1;
            data->num_mask = get_number_of_masks(argv, i, argc);
            data->masks = (word_t *)malloc(data->num_mask * sizeof(word_t));
            if (data->num_mask < 1) {
                fprintf(stderr, "Error reading the masks.\n");
                return -1;
            }

            get_values(argv, i + 1, &(files->mask_path), &(files->m_file),
                       &(data->masks), data->num_mask);
            i++;
        } else if (strcmp(DAT_DELIM, argv[i]) == 0) {
            params_done[3] = true;
            get_value(argv[i + 1], &(files->data_path), &(files->d_file),
                      &(data->clear_data));
            i++;
        } else if (strcmp(CIP_DELIM, argv[i]) == 0) {
            params_done[4] = true;
            strcpy(files->cipher_path, argv[i + 1]);
            files->c_file = fopen(argv[i + 1], "a");
            if (files->c_file == NULL) {
                fprintf(stderr, "Could not open cipher output file : %s: %s\n",
                        argv[i + 1], strerror((errno)));
                return -1;
            }
            i++;
        } else if (strcmp(TRC_DELIM, argv[i]) == 0) {
            params_done[5] = true;
            strcpy(files->traces_path, argv[i + 1]);
            files->t_file = fopen(argv[i + 1], "a");
            if (files->t_file == NULL) {
                fprintf(stderr, "Could not open traces output file : %s: %s\n",
                        argv[i + 1], strerror((errno)));
                return -1;
            }
            i++;
        } else {
            fprintf(stderr, "Unknown/invalid parameters.\n%s\n", HELP_STR);
            return -1;
        }
    }

    // Once all parameters are parsed, fill the required missing ones : tty_dev,
    // key, data, ciph_out and trace_out
    finish_config(params_done, files, data);

    return 0;
}

/*
 *   Parses the configuration file provided by the user and fills the files_t
 * and data_full_t structures for the experiment
 *
 *   All necessary values that are not present in the config file are filled
 * with default values
 *
 *   Parameters: path_to_file- path to the configuration file
 *               data        - structure to be filled with the user's input
 *               files       - structure to be filled with the user's input
 *
 *   Returns : -1 in case of errors, 0 if all goes well
 */
int parse_config(const char *path_to_file, data_full_t *data, files_t *files) {
    FILE *fp;
    char *line = NULL;
    char *token;
    size_t len = 0;
    ssize_t read;
    bool param_done[6] = {false};

    fp = fopen(path_to_file, "r");
    if (!fp) {
        fprintf(stderr, "Error opening %s: %s\n", path_to_file,
                strerror((errno)));
        return -1;
    }

    while ((read = getline(&line, &len, fp)) != -1) {
        line[strlen(line) - 1] = '\0';
        printf("Retrieved line of length %zu:\n", read);
        printf("%s", line);

        token = strtok(line, " ");
        printf("%s\n", token);

        if (token[0] == 'k' && param_done[1] == false) {
            param_done[1] = true;
            token = strtok(NULL, " ");
            if (token == NULL) {
                fprintf(stderr, "No/Invalid key found : %s: %s\n", path_to_file,
                        strerror((errno)));
                return -1;
            }
            get_value(token, &files->key_path, &files->k_file, &data->key);
        } else if (token[0] == 'm' &&
                   param_done[2] == false) {  // TODO: Support multiple masks
            param_done[2] = true;
            token = strtok(NULL, " ");
            if (token == NULL) {
                fprintf(stderr, "No/Invalid mask found : %s: %s\n",
                        path_to_file, strerror((errno)));
                return -1;
            }
            printf("%s", token);
            size_t num_mask = 0;
            data->masks = (word_t *)malloc(MAX_MASKS * sizeof(word_t));
            do {
                get_value(token, &files->mask_path, &files->m_file,
                          &(data->masks)[num_mask++]);
            } while ((token = strtok(NULL, " ")) != NULL);
            data->masks =
                (word_t *)realloc(data->masks, data->num_mask * sizeof(word_t));

        } else if (token[0] == 'd' && param_done[3] == false) {
            param_done[3] = true;
            token = strtok(NULL, " ");
            if (token == NULL) {
                fprintf(stderr, "No/Invalid data found : %s: %s\n",
                        path_to_file, strerror((errno)));
                return -1;
            }
            get_value(token, &files->data_path, &files->d_file,
                      &data->clear_data);
            for (size_t i = 0; i < 16; i++)
                printf("0x%x ", ((uint8_t *)&data->clear_data)[i]);
        } else if (token[0] == 'c' && param_done[4] == false) {
            param_done[4] = true;
            token = strtok(NULL, " ");
            if (token == NULL) {
                fprintf(stderr,
                        "No/Invalid path found for cipher output : %s: %s\n",
                        path_to_file, strerror((errno)));
                return -1;
            }
            strcpy(files->cipher_path, token);
            files->c_file = fopen(token, "w+");
            if (files->c_file == NULL) {
                fprintf(stderr, "Could not open cipher output file : %s: %s\n",
                        path_to_file, strerror((errno)));
                return -1;
            }
        } else if (token[0] == 't' && param_done[5] == false) {
            param_done[5] = true;
            token = strtok(NULL, " ");
            if (token == NULL) {
                fprintf(stderr,
                        "No/Invalid path found for traces output : %s: %s\n",
                        path_to_file, strerror((errno)));
                return -1;
            }
            strcpy(files->traces_path, token);
            files->t_file = fopen(token, "w+");
            if (files->t_file == NULL) {
                fprintf(stderr, "Could not open traces output file : %s: %s\n",
                        path_to_file, strerror((errno)));
                return -1;
            }
        } else if (token[0] == 'u' && param_done[0] == false) {
            param_done[0] = true;
            token = strtok(NULL, " ");
            if (token == NULL) {
                fprintf(stderr,
                        "No/Invalid path found for tty device : %s: %s\n",
                        path_to_file, strerror((errno)));
                return -1;
            }
            strcpy(files->tty_dev_path, token);

            files->tty_fd = open(token, O_RDWR | O_NOCTTY | O_SYNC);
            if (files->tty_fd < 0) {
                fprintf(stderr, "Could not tty device file  \'%s\': %s\n",
                        files->tty_dev_path, strerror((errno)));
                return -1;
            }

            set_interface_attribs(files->tty_fd, B115200);
        }
    }

    finish_config(param_done, files, data);

    fclose(fp);
    if (line) free(line);
    return 0;
}

/*
 *   Parses the array of command's parameters provided by the user and fills the
 * conf_t, input_t and dumps_t structures for the experiment. This function also
 * parses the key mode, plaintext mode, number of traces and number of masks.
 *
 *   All necessary values that aren't provided by the user's input argv are
 * filled with default values
 *
 *   Parameters: argc_offset - index at which to start parsing elements in argv
 *               argc        - size of argv
 *               argv        - array of string containing the user's parameters
 * input conf        - structure to be filled with the user's input inputs -
 * structure to be filled with the user's input dumps       - structure to be
 * filled with the file pointers of the output files
 *
 *   Returns : -1 in case of errors, 0 if all goes well
 */
int parse_command_modes(size_t argc_offset, int argc, char *argv[],
                        config_t *conf, input_t *inputs, dumps_t *dumps) {
    bool params_done[11] = {false};
    int temp_fd;
    char *token;

    for (int i = argc_offset; i < argc; i++) {
        switch (get_delim(argv[i])) {
            case 0:  // UART
                params_done[0] = true;
                strcpy(conf->tty_dev_path, argv[i + 1]);

                temp_fd = open(argv[i + 1], O_RDWR | O_NOCTTY | O_SYNC);
                if (temp_fd < 0) {
                    fprintf(stderr, "Error opening %s: %s\n", argv[i + 1],
                            strerror((errno)));
                    return -1;
                }

                set_interface_attribs(temp_fd, B115200);
                conf->tty_fd = temp_fd;
                i++;
                break;
            case 1:  // KEY
                params_done[1] = true;
                get_hex_value(argv[i + 1], &(inputs->key));
                i++;
                break;
            case 2:  // Mask
                params_done[2] = true;
                token = strtok(NULL, " ");
                if (token == NULL) {
                    fprintf(stderr, "No/Invalid mask found : %s: %s\n", token,
                            strerror((errno)));
                    return -1;
                }
                size_t num_mask = 0;
                inputs->masks = (word_t *)malloc(MAX_MASKS * sizeof(word_t));
                do {
                    get_hex_value(token, &(inputs->masks)[num_mask++]);
                } while ((token = strtok(NULL, " ")) != NULL);
                inputs->masks = (word_t *)realloc(
                    inputs->masks, inputs->num_mask * sizeof(word_t));
                break;
            case 3:  // Data
                params_done[3] = true;
                get_hex_value(argv[i + 1], &(inputs->plaintext));
                i++;
                break;
            case 4:  // Num_Masks
                params_done[4] = true;
                inputs->num_mask = atoi(argv[i + 1]);
                i++;
                break;
            case 5:  // Cipher
                params_done[5] = true;
                printf("Dynamic name for cipher dump not supported yet.\n");
                i++;
                break;
            case 6:  // Trace
                params_done[6] = true;
                printf("Dynamic name for trace dump not supported yet.\n");
                i++;
                break;
            case 7:  // Key mode
                params_done[7] = true;
                conf->key_mode = atoi(argv[++i]);
                break;
            case 8:  // Plain mode
                params_done[8] = true;
                conf->plain_mode = atoi(argv[++i]);
                break;
            case 9:  // Num traces
                params_done[9] = true;
                conf->num_traces = atoi(argv[++i]);
                break;
            case 10:  // Dump
                params_done[10] = true;

                strcpy(conf->dump_path, argv[++i]);
                break;
            default:
                fprintf(stderr, "Unknown/invalid parameters.\n%s\n", HELP_STR);
                return -1;
        }
    }

    // Once all parameters are parsed, fill the required missing ones : tty_dev,
    // key, data, ciph_out and trace_out
    finish_config_modes(params_done, conf, inputs, dumps);

    return 0;
}

/*
 *   Parses the configuration file provided by the user and fills the files_t
 * and data_full_t structures for the experiment
 *
 *   All necessary values that are not present in the config file are filled
 * with default values
 *
 *   Parameters: path_to_file- path to the configuration file
 *               data        - structure to be filled with the user's input
 *               files       - structure to be filled with the user's input
 *
 *   Returns : -1 in case of errors, 0 if all goes well
 */
int parse_config_modes(const char *path_to_file, config_t *conf,
                       input_t *inputs, dumps_t *dumps) {
    bool param_done[11] = {false};
    FILE *fp;
    char *line = NULL;
    char *token;
    size_t len = 0;
    ssize_t read;

    fp = fopen(path_to_file, "r");
    if (!fp) {
        fprintf(stderr, "Error opening %s: %s\n", path_to_file,
                strerror((errno)));
        return -1;
    }

    while ((read = getline(&line, &len, fp)) != -1) {
        line[strlen(line) - 1] = '\0';
        printf("Retrieved line of length %zu:\n", read);
        printf("%s", line);

        token = strtok(line, " ");
        printf("%s\n", token);

        if (token[0] == 'k' && param_done[1] == false) {
            param_done[1] = true;
            token = strtok(NULL, " ");
            if (token == NULL) {
                fprintf(stderr, "No/Invalid key found : %s: %s\n", path_to_file,
                        strerror((errno)));
                return -1;
            }
            get_hex_value(token, &inputs->key);
        } else if (token[0] == 'm' &&
                   param_done[2] == false) {  // TODO: Support multiple masks
            param_done[2] = true;
            token = strtok(NULL, " ");
            if (token == NULL) {
                fprintf(stderr, "No/Invalid mask found : %s: %s\n",
                        path_to_file, strerror((errno)));
                return -1;
            }
            printf("%s", token);
            size_t num_mask = 0;
            inputs->masks = (word_t *)malloc(MAX_MASKS * sizeof(word_t));
            do {
                get_hex_value(token, &(inputs->masks)[num_mask++]);
            } while ((token = strtok(NULL, " ")) != NULL);
            inputs->num_mask = num_mask;
            inputs->masks = (word_t *)realloc(
                inputs->masks, inputs->num_mask * sizeof(word_t));
        } else if (token[0] == 'd' && param_done[3] == false) {
            param_done[3] = true;
            token = strtok(NULL, " ");
            if (token == NULL) {
                fprintf(stderr, "No/Invalid data found : %s: %s\n",
                        path_to_file, strerror((errno)));
                return -1;
            }
            get_hex_value(token, &inputs->plaintext);
        } else if (token[0] == 'c' && param_done[4] == false) {
            param_done[5] = true;
        } else if (token[0] == 't' && param_done[5] == false) {
            param_done[6] = true;

        } else if (token[0] == 'u' && param_done[0] == false) {
            param_done[0] = true;
            token = strtok(NULL, " ");
            if (token == NULL) {
                fprintf(stderr,
                        "No/Invalid path found for tty device : %s: %s\n",
                        path_to_file, strerror((errno)));
                return -1;
            }
            strcpy(conf->tty_dev_path, token);

            conf->tty_fd = open(token, O_RDWR | O_NOCTTY | O_SYNC);
            if (conf->tty_fd < 0) {
                fprintf(stderr, "Could not tty device file  \'%s\': %s\n",
                        conf->tty_dev_path, strerror((errno)));
                return -1;
            }

            set_interface_attribs(conf->tty_fd, B115200);
        } else if (strcmp(token, "nm") == 0) {
            param_done[4] = true;
            token = strtok(NULL, " ");
            inputs->num_mask = atoi(token);
        } else if (strcmp(token, "km") == 0) {
            param_done[7] = true;

            token = strtok(NULL, " ");
            conf->key_mode = atoi(token);
        } else if (strcmp(token, "dm") == 0) {
            param_done[8] = true;
            token = strtok(NULL, " ");
            conf->plain_mode = atoi(token);
        } else if (strcmp(token, "nt") == 0) {
            param_done[9] = true;
            token = strtok(NULL, " ");
            conf->num_traces = atoi(token);
        } else if (strcmp(token, "dump") == 0) {
            param_done[10] = true;
            token = strtok(NULL, " ");
            strcpy(conf->dump_path, token);
        }
    }
    // Once all parameters are parsed, fill the required missing ones : tty_dev,
    // key, data, ciph_out and trace_out
    finish_config_modes(param_done, conf, inputs, dumps);

    return 0;
}

/*
 *   Parses the array of command's parameters provided by the user and fills the
 * conf_t, input_t structures for the experiment. This function also parses the
 * key mode, plaintext mode, number of traces and number of masks but doesn't
 * open the dump files not the tty device file. It also does not read provided
 * values for the key, masks or plaintext.
 *
 *   All necessary values that aren't provided by the user's input argv are
 * filled with default values
 *
 *   Parameters: argc_offset - index at which to start parsing elements in argv
 *               argc        - size of argv
 *               argv        - array of string containing the user's parameters
 * input conf        - structure to be filled with the user's input inputs -
 * structure to be filled with the user's input
 *
 *   Returns : EXIT_FAILURE in case of errors, EXIT_SUCCESS if all goes well
 */
int parse_command_no_val(size_t argc_offset, int argc, char *argv[],
                         config_t *conf, input_t *inputs) {
    bool params_done[11] = {false};

    for (int i = argc_offset; i < argc; i++) {
        switch (get_delim(argv[i])) {
            case 0: {
                // UART
                params_done[0] = true;
                strcpy(conf->tty_dev_path, argv[i + 1]);
                i++;
                break;
            }
            case 1: {
                // KEY
                params_done[1] = true;
                printf("Dynamic name for key dump not supported yet.\n");
                i++;
                break;
            }
            case 2: {
                // Mask
                params_done[2] = true;
                printf("Dynamic name for mask dump not supported yet.\n");
                i++;
            }
            case 3: {
                // Data
                params_done[3] = true;
                printf("Dynamic name for plaintext dump not supported yet.\n");
                i++;
                break;
            }
            case 4: {
                // Num_Masks
                params_done[4] = true;
                inputs->num_mask = atoi(argv[i + 1]);
                i++;
                break;
            }
            case 5: {
                // Cipher
                params_done[5] = true;
                printf("Dynamic name for cipher dump not supported yet.\n");
                i++;
                break;
            }
            case 6: {
                // Trace
                params_done[6] = true;
                printf("Dynamic name for trace dump not supported yet.\n");
                i++;
                break;
            }
            case 7: {
                // Key mode
                params_done[7] = true;
                conf->key_mode = atoi(argv[++i]);
                break;
            }
            case 8: {
                // Plain mode
                params_done[8] = true;
                conf->plain_mode = atoi(argv[++i]);
                break;
            }
            case 9: {
                // Num traces
                params_done[9] = true;
                conf->num_traces = atoi(argv[++i]);
                break;
            }
            case 10: {
                // Dump
                params_done[10] = true;

                strcpy(conf->dump_path, argv[++i]);
                break;
            }
            default: {
                fprintf(stderr, "Unknown/invalid parameters.\n%s\n", HELP_STR);
                return EXIT_FAILURE;
            }
        }
    }

    // Once all parameters are parsed, fill the required missing ones : tty_dev,
    // key, data, ciph_out and trace_out
    finish_config_no_val(params_done, conf, inputs);

    return EXIT_SUCCESS;
}

/*
 *   Completes the configuration if any required parameter hasn't been provided
 *
 *   Default key       : {0x61} (16B)
 *   Default plaintest : {0x61} (16B)
 *   Default tty       : /dev/ttyUSB1/
 *
 *   Parameters: params_done - array indicating the parameters status [uart,
 * key, mask, plaintext, cipher, traces] files       - pointer to the session's
 * I/O files parameters structure data        - pointer to the session's data
 * structure
 */
void finish_config(bool params_done[11], files_t *files, data_full_t *data) {
    for (size_t i = 0; i < 11; i++) {
        if (!params_done[i]) {
            if (i == 0) {  // tty_dev hasn't been configured

                strcpy(files->tty_dev_path, "/dev/ttyUSB1");
                files->tty_fd =
                    open(files->tty_dev_path, O_RDWR | O_NOCTTY | O_SYNC);
                if (files->tty_fd < 0) {
                    fprintf(stderr, "Error opening %s: %s\n",
                            files->tty_dev_path, strerror((errno)));
                    return;
                }

                set_interface_attribs(files->tty_fd, B115200);
            } else if (i == 1) {  // key hasn't been configured
                files->k_file = NULL;

                for (size_t i = 0; i < NUM_BYTES; i++) {
                    data->key[i] = DFLT_BYTE;
                }
            } else if (i == 3) {  // plaintext hasn't been configured
                files->d_file = NULL;

                for (size_t i = 0; i < NUM_BYTES; i++) {
                    data->clear_data[i] = DFLT_BYTE;
                }
            } else if (i == 4) {  // output for cipher hasn't been configured
                files->c_file = DFLT_OUT;
            } else if (i == 5) {  // output for traces hasn't been configured
                files->t_file = DFLT_OUT;
            }
        }
    }
}

/*
 *   Completes the configuration if any required parameter hasn't been provided
 *
 *   Default key       : {0x61} (16B)
 *   Default plaintest : {0x61} (16B)
 *   Default tty       : /dev/ttyUSB1/
 *
 *   Parameters: params_done - array indicating the parameters status
 *               conf        - pointer to the configuration data structure to be
 * completed inputs      - pointer to the inputs data structure to be completed
 *               outputs     - pointer to the outputs data structure to be
 * completed
 *
 *  Return    : EXIT_SUCCESS if all went well, EXIT_FAILURE otherwise
 */
int finish_config_modes(bool params_done[11], config_t *conf, input_t *inputs,
                        dumps_t *dumps) {
    if (!params_done[7]) {  // Key mode
        conf->key_mode = 0;
        params_done[7] = true;
    }
    if (!params_done[8]) {  // Plain mode
        conf->plain_mode = 0;
        params_done[8] = true;
    }
    if (!params_done[9]) {  // Plain mode
        conf->num_traces = 256 * 256 * 10;
        params_done[9] = true;
    }
    if (!params_done[10]) {  // Dump
        strcpy(conf->dump_path, DUMP_PATH);
        params_done[10] = true;
    }
    if (!params_done[0]) {
        conf->tty_dev_path =
            (char *)malloc((strlen(DFLT_URT) + 1) * sizeof(char));
        strcpy(conf->tty_dev_path, DFLT_URT);
        conf->tty_fd = open(conf->tty_dev_path, O_RDWR | O_NOCTTY | O_SYNC);
        if (conf->tty_fd < 0) {
            fprintf(stderr, "Error opening %s: %s\n", conf->tty_dev_path,
                    strerror((errno)));
            return -1;
        }
        set_interface_attribs(conf->tty_fd, B115200);
        params_done[0] = true;
    }
    if (!params_done[1]) {
        if (conf->key_mode)
            gen_random_word(inputs->key);
        else
            memcpy(inputs->key, default_key, NUM_BYTES);

        params_done[1] = true;
    }
    if (!params_done[2]) {
        inputs->num_mask = 0;
        params_done[2] = true;
    }
    if (!params_done[3]) {
        memcpy(inputs->plaintext, default_plain, NUM_BYTES);
        params_done[3] = true;
    }

    return 0;
}

/*
 *   Completes the configuration if any required parameter hasn't been provided.
 *
 *   It does not set default values for the key, plaintext or masks and does not
 * configure nor open the tty device file.
 *
 *   Default tty       : /dev/ttyUSB1/
 *   Default key mode  : 0 (constant)
 *   Default plain mode: 0 (constant)
 *   Default num traces: 256*256*10
 *   Default dump path : ./dumps
 *   Default num masks : 0
 *
 *   Parameters: params_done - array indicating the parameters status
 *               conf        - pointer to the configuration data structure to be
 * completed inputs      - pointer to the inputs data structure to be completed
 *
 *  Return    : EXIT_SUCCESS if all went well, EXIT_FAILURE otherwise
 */
int finish_config_no_val(bool params_done[11], config_t *conf,
                         input_t *inputs) {
    if (!params_done[7]) {  // Key mode
        conf->key_mode = 0;
        params_done[7] = true;
    }
    if (!params_done[8]) {  // Plain mode
        conf->plain_mode = 0;
        params_done[8] = true;
    }
    if (!params_done[9]) {  // Plain mode
        conf->num_traces = 256 * 256 * 10;
        params_done[9] = true;
    }
    if (!params_done[10]) {  // Dump
        strcpy(conf->dump_path, DUMP_PATH);
        params_done[10] = true;
    }
    if (!params_done[0]) {
        conf->tty_dev_path =
            (char *)malloc((strlen(DFLT_URT) + 1) * sizeof(char));
        strcpy(conf->tty_dev_path, DFLT_URT);
        params_done[0] = true;
    }
    if (!params_done[1]) {
    }
    if (!params_done[2]) {
        inputs->num_mask = 0;
        params_done[2] = true;
    }
    if (!params_done[3]) {
        params_done[3] = true;
    }

    return EXIT_SUCCESS;
}

/*
 *   Exports the experiment's config to a file. The format in which it is
 * exported can be parsed by parse_config. The file will contain the hexadecimal
 * values as well as the path to the files containing those inputs if any.
 *
 *   Parameters: path_to_config_file- path to the configuration file to be
 * written data               - structure containing the experiment's data to be
 * exported files              - structure containing the paths to the
 * experiment's input/output files if any
 */
void export_config(const char *path_to_config_file, files_t *files,
                   data_full_t *data) {
    FILE *fp;
    fp = fopen(path_to_config_file, "w+");
    if (fp == NULL) {
        fprintf(stderr, "Could not open config file : %s\n %s",
                path_to_config_file, strerror(errno));
        exit(EXIT_FAILURE);
    }

    // Print path to tty device
    if (files->tty_fd != 0) {
        fprintf(fp, "u %s\n", files->tty_dev_path);
    }

    // Print path to key file if it exist, otherwise print the key
    if (files->k_file != NULL) {
        fprintf(fp, "k %s\n", files->key_path);
    } else {
        fprintf(fp, "k ");
        for (size_t i = 0; i < NUM_BYTES; i++) fprintf(fp, "%x", data->key[i]);
        fprintf(fp, "\n");
    }

    // Print path to mask file if it exist, otherwise print the mask(s) (all
    // masks on the same line)
    if (files->m_file != NULL) {
        fprintf(fp, "m %s\n", files->mask_path);
    } else {
        fprintf(fp, "m ");
        for (size_t j = 0; j < data->num_mask; j++) {
            for (size_t i = 0; i < NUM_BYTES; i++)
                fprintf(fp, "%x", data->masks[j][i]);
            fprintf(fp, " ");
        }
        fprintf(fp, "\n");
    }

    // Print path to data file if it exist, otherwise print the data
    if (files->d_file != NULL) {
        fprintf(fp, "d %s\n", files->data_path);
    } else {
        fprintf(fp, "d ");
        for (size_t i = 0; i < NUM_BYTES; i++)
            fprintf(fp, "%x", data->clear_data[i]);
        fprintf(fp, "\n");
    }

    // Print path to cipher output file if it is not standard output
    if (files->c_file != NULL && files->c_file != stdout) {
        fprintf(fp, "c %s\n", files->cipher_path);
    }

    // Print path to traces output file if it is not standard output
    if (files->t_file != NULL && files->t_file != stdout) {
        fprintf(fp, "t %s\n", files->traces_path);
    }

    fclose(fp);
}

/*
 *   Exports the experiment's config to a file. The format in which it is
 * exported can be parsed by parse_config_modes. The file will contain the
 * hexadecimal values as well as the path to the files containing those inputs
 * if any.
 *
 *   Parameters: path_to_config_file- path to the configuration file to be
 * written conf               - structure containing the experiment's
 * configuration inputs             - structure containing the number of masks
 * used in the experiment
 */
void export_config_modes(const char *path_to_config_file, config_t *conf,
                         input_t *inputs) {
    FILE *fp;
    fp = fopen(path_to_config_file, "w+");
    if (fp == NULL) {
        fprintf(stderr, "Could not open config file : %s\n %s",
                path_to_config_file, strerror(errno));
        exit(EXIT_FAILURE);
    }

    // Print path to tty device
    if (conf->tty_fd != 0) {
        fprintf(fp, "u %s\n", conf->tty_dev_path);
    }

    // Print key mode
    fprintf(fp, "km %d\n", conf->key_mode);

    // Print plaintext mode
    fprintf(fp, "dm %d\n", conf->plain_mode);

    // Print number of masks if > 0
    if (inputs->num_mask > 0) fprintf(fp, "nm %lu\n", inputs->num_mask);

    // Print number of traces
    fprintf(fp, "nt %lu\n", conf->num_traces);

    // Print dump path
    fprintf(fp, "dump %s\n", conf->dump_path);

    fclose(fp);
}

/*
 *   Frees all dynamically allocated buffers in data and closes all the files
 * openend in files
 *
 *   Parameters: data        - pointer to the structure to be freed.
 *               files       - pointer to the structure containing files to be
 * closed.
 *
 *   Returns : -1 in case of errors, 0 otherwise
 */
int free_rsc(data_full_t *data, files_t *files) {
    int ret;

    /* Free data memory resources */
    if (data->num_mask) free(data->masks);

    if (data->num_traces) free(data->traces);

    /* Close open files */
    if (files->tty_fd > 0) {
        ret = close(files->tty_fd);
        if (ret < 0)
            fprintf(stderr, "Error closing the tty device: %s\n",
                    strerror(errno));
    }
    if (files->k_file != NULL) {
        ret = fclose(files->k_file);
        if (ret < 0)
            fprintf(stderr, "Error closing the key file: %s\n",
                    strerror(errno));
    }
    if (files->m_file != NULL) {
        ret = fclose(files->m_file);
        if (ret < 0)
            fprintf(stderr, "Error closing the mask file %s\n",
                    strerror(errno));
    }
    if (files->d_file != NULL) {
        ret = fclose(files->d_file);
        if (ret < 0)
            fprintf(stderr, "Error closing the plaintext file: %s\n",
                    strerror(errno));
    }
    if (files->c_file != DFLT_OUT) {
        ret = fclose(files->c_file);
        if (ret < 0)
            fprintf(stderr, "Error closing the cipher output file: %s\n",
                    strerror(errno));
    }
    if (files->t_file != DFLT_OUT) {
        ret = fclose(files->t_file);
        if (ret < 0)
            fprintf(stderr, "Error closing the traces output file: %s\n",
                    strerror(errno));
    }
    return ret;
}

int print_config2(config_t *config) {
    if (config == NULL) return EXIT_FAILURE;
    fprintf(stdout, "Configuration :\n");
    fprintf(stdout, "    Key mode  : %s\n",
            config->key_mode ? "random" : "constant");
    fprintf(stdout, "    Plain mode: %s\n",
            config->plain_mode ? "chained" : "t-test");
    fprintf(stdout, "    Num Traces: %lu\n", config->num_traces);
    fprintf(stdout, "    Dump paths: %s\n", config->dump_path);

    return EXIT_SUCCESS;
}

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
/* * * * * * * * AES Experiment Encapsulated Function  * * * * * * * * * * * */
/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

/*
 *   Writes the provided address to the FPGA, waits for the ACK bytes and checks
 *   the value is correct.
 *
 *   Parameters :   fd      - index of the open file descriptor to the tty
 * device address - hex byte value for the desired address
 *
 *   Returns    :  EXIT_SUCCESS if all went well, EXIT_FAILURE in case of I/O
 * error or non-matching ACK/address
 */
int write_address(int fd, const uint8_t *address) {
    int ret;
    uint8_t ack;
    ret = write_bytes(fd, address, 1);
    if (ret < 0) {
        fprintf(stderr, "Error writing the %s address.\n",
                ADDR_NAMES[*address]);
        return EXIT_FAILURE;
    }
    ret = read_bytes(fd, &ack, 1);
    if (ret < 0 || ack != *address) {
        fprintf(stderr,
                "Error: non-matching ack (ack = %d, address = %d) for %s "
                "address to AES.\n",
                ack, *address, ADDR_NAMES[*address]);
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}

/*
 *  Sets up the AES with the key and the masks.
 *
 *  Parameters :  conf    - structure containing the file descriptor to the open
 * tty device file inputs  - structure containing the key, the number of masks
 * and the masks, if any
 *
 *  Returns    : EXIT_SUCCESS if all went well, EXIT_FAILURE if not
 */  
int setup_aes(config_t *conf, input_t *inputs) {
    int ret;
    ret = write_address(conf->tty_fd, &ADDR_SPACE[KEY_IDX]);
    if (ret != EXIT_SUCCESS) return ret;

    ret = write_bytes(conf->tty_fd, (uint8_t *)&inputs->key, NUM_BYTES);
    if (ret < NUM_BYTES) {
        fprintf(stderr, "Error writing the key.\n");
        return EXIT_FAILURE;
    }
    tcdrain(conf->tty_fd);

    for (size_t i = 0; i < inputs->num_mask; i++) {
        /* Write mask address and mask */
        ret = write_address(conf->tty_fd, &ADDR_SPACE[MSK_IDX]);
        if (ret != EXIT_SUCCESS) return ret;

        ret = write_bytes(conf->tty_fd, (uint8_t *)&(inputs->masks[i]),
                          NUM_BYTES);
        if (ret < NUM_BYTES) {
            fprintf(stderr, "Error writing the mask.\n");
            return EXIT_FAILURE;
        }
        tcdrain(conf->tty_fd);
    }
    return EXIT_SUCCESS;
}

/*
 *  Sends the plaintext to the AES and reads the cipher
 *
 *  Parameters :  conf    - structure containing the file descriptor to the open
 * tty device file inputs  - structure containing the plaintext outputs -
 * structure in which to store the cipher
 *
 *  Returns    : EXIT_SUCCESS if all went well, EXIT_FAILURE if not
 */
int encrypt_word(config_t *conf, input_t *inputs, output_t *outputs) {
    int ret;
    uint8_t ack;
    /* Write the plaintext data */
    ret = write_address(conf->tty_fd, &ADDR_SPACE[DAT_IDX]);
    if (ret != EXIT_SUCCESS) return ret;

    ret = write_bytes(conf->tty_fd, (uint8_t *)&inputs->plaintext, NUM_BYTES);
    if (ret < NUM_BYTES) {
        fprintf(stderr, "Error writing the plaintext.\n");
        return EXIT_FAILURE;
    }
    tcdrain(conf->tty_fd);

    ret = read_bytes(conf->tty_fd, &ack, 1);
    if (ret < 0 || ack != 0x42) {
        fprintf(stderr, "Error reading clear flag from the device.\n");
        return EXIT_FAILURE;
    }

    /* Read the cipher data */
    ret = write_address(conf->tty_fd, &ADDR_SPACE[CIP_IDX]);
    if (ret != EXIT_SUCCESS) return ret;

    ret = read_bytes(conf->tty_fd, (uint8_t *)&(outputs->cipher), NUM_BYTES);
    if (ret < NUM_BYTES) {
        fprintf(stderr, "Error reading the cipher.Only %d bytes read\n", ret);
        print_hex_word((uint8_t *)&(outputs->cipher), ret, stderr);
        return -1;
    }

    return 0;
}

/*
 *  Reads the trace from the AES. Parses the data and fills the sensor and
 * signal trace arrays.
 *
 *  Parameters   : conf    - structure containing the open file descriptor to
 * the tty device file outputs - structure to be filled with the trace data
 *
 *  Returns       : EXIT_SUCCESS if all went well, EXIT_FAILURE if not
 *
 */
int read_traces(config_t *conf, output_t *outputs) {
    int ret;
    uint8_t temp[NUM_SAMPLES * 2];
    ret = write_address(conf->tty_fd, &ADDR_SPACE[TRC_IDX]);
    if (ret != EXIT_SUCCESS) return ret;

    ret = read_bytes(conf->tty_fd, temp, NUM_SAMPLES * 2);
    if (ret < 0) {
        fprintf(stderr, "Error reading the trace from AES.\n");
        return EXIT_FAILURE;
    }

    size_t num_B = NUM_SAMPLES * 2 - 1;

    for (size_t i = 0; i < NUM_SAMPLES; i++) {
        outputs->sensor_trace[i] = temp[num_B - 2 * i];
        outputs->signal_trace[i] = temp[num_B - 2 * i - 1];
    }

    return EXIT_SUCCESS;
}

/*
 *  Dumps the cipher and traces from outputs in the files opened in dumps.
 *
 *  The cipher is dumped in binary value whereas the traces are printed as text,
 * using hexadecimal representation.
 *
 *  Parameters   : conf    - structure containing the index of the current trace
 *                 outputs - structure containing the cipher and traces data
 *                 dumps   - structure containing the opened file pointers to
 * the dump files
 *
 *  Returns      : EXIT_SUCCESS if all went well, EXIT_FAILURE if not
 *
 */
int dump_output(config_t *conf, output_t *outputs, dumps_t *dumps) {
    /* Dump Cipher binary value */
    fwrite(outputs->cipher, 1, NUM_BYTES, dumps->cipher_dump);

    /* Dump traces hex value */
    for (size_t i = 0; i < NUM_SAMPLES; i++) {
        /* Sensor trace */
        fprintf(dumps->sensor_trace_dump, "%d,",
                outputs->sensor_trace[i] & 0xFF);

        /* Signal trace */
        fprintf(dumps->ttest_valid_dump, "%x,",
                (outputs->signal_trace[i] >> TTEST_VALID_b) & 0x1);
        fprintf(dumps->ttest_fail_dump, "%x,",
                (outputs->signal_trace[i] >> TTEST_FAIL_b) & 0x1);
        fprintf(dumps->ttest_output_valid_dump, "%x,",
                (outputs->signal_trace[i] >> TTEST_OVALID_b) & 0x1);
        fprintf(dumps->aes_busy_dump, "%x,",
                (outputs->signal_trace[i] >> AES_BUSY_b) & 0x1);
    }
    fprintf(dumps->sensor_trace_dump, "\n");

    /* Signal trace */
    fprintf(dumps->ttest_valid_dump, "\n");
    fprintf(dumps->ttest_fail_dump, "\n");
    fprintf(dumps->ttest_output_valid_dump, "\n");
    fprintf(dumps->aes_busy_dump, "\n");

    return 0;
}

/*
 *  Dumps the key, masks and plaintext from inputs in the files opened in dumps.
 *
 *  All data is dumped in binary values.
 *
 *  Parameters   : inputs  - structure containing the key, masks and plaintext
 *                 dumps   - structure containing the opened file pointers to
 * the dump files
 *
 *  Returns      : EXIT_SUCCESS if all went well, EXIT_FAILURE if not
 *
 */
int dump_input(input_t *inputs, dumps_t *dumps) {
    // TODO : Check returns
    /* Dump Key binary value */
    fwrite(inputs->key, 1, NUM_BYTES, dumps->key_dump);

    /* Dump Masks binary value */
    for (size_t i = 0; i < inputs->num_mask; i++) {
        fwrite(inputs->masks[i], 1, NUM_BYTES, dumps->mask_dump);
    }

    /* Dump Plaintext binary value */
    fwrite(inputs->plaintext, 1, 16, dumps->plaintext_dump);

    return EXIT_SUCCESS;
}

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
/* * * * * * * * * * * * AES Experiment Function * * * * * * * * * * * * * * */
/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

/*
 *  Sends the key to the AES device
 *
 *  Paramaters :  fd    - file descriptor of the open and configured tty device
 * file key   - pointer to a 16 bytes array containing the key (MSB first)
 *
 *  Returns      : EXIT_SUCCESS if all went well, EXIT_FAILURE if not
 */
int set_key_w(int fd, uint8_t *key) {
    int ret;
    ret = write_address(fd, &ADDR_SPACE[KEY_IDX]);
    if (ret != EXIT_SUCCESS) return ret;

    ret = write_bytes(fd, key, NUM_BYTES);
    if (ret < 0) {
        fprintf(stderr, "Error writing the key to AES.\n");
        return EXIT_FAILURE;
    }
    tcdrain(fd);
    return EXIT_SUCCESS;
}

/*
 *  Sends the mask to the AES device
 *
 *  Paramaters :  fd    - file descriptor of the open and configured tty device
 * file mask  - pointer to a 16 bytes array containing the key (MSB first)
 *
 *  Returns      : EXIT_SUCCESS if all went well, EXIT_FAILURE if not
 */
int set_mask_w(int fd, uint8_t *mask) {
    int ret;
    ret = write_address(fd, &ADDR_SPACE[MSK_IDX]);
    if (ret != EXIT_SUCCESS) return ret;

    ret = write_bytes(fd, mask, NUM_BYTES);
    if (ret < 0) {
        fprintf(stderr, "Error writing the mask to AES.\n");
        return EXIT_FAILURE;
    }
    tcdrain(fd);

    return EXIT_SUCCESS;
}

int calibrate_sensor(int fd, uint8_t *plaintext, uint8_t *key,
                     uint8_t *idc_idf) {
    if (set_calibration(fd, idc_idf) == EXIT_FAILURE) {
        printf("Set calibration failed\n");
    }
    // Reset AES
    uint8_t addr = 0xE0;
    int ret = write_bytes(fd, &addr, 1);
    uint8_t data = 0x02;
    ret = write_bytes(fd, &data, 1);

    // Write key into the AES core
    if (set_key_w(fd, key) == EXIT_FAILURE) {
        printf("Set key failed\n");
    }
    uint8_t cipher[16] = {0x00};
    uint8_t sensor_trace[16 * NUM_SAMPLES] = {0x00};
    uint8_t temperature[2 * NUM_SAMPLES] = {0x00};
    if (encrypt_w(fd, plaintext, cipher) == EXIT_FAILURE) {
        printf("Encrypt failed\n");
    }
    if (read_trace_w(fd, sensor_trace, temperature) == EXIT_FAILURE) {
        printf("Sensor trace collection failed\n");
    }
    int idc = 1;
    int idf = 0;
    printf("start calibration \n");
    for (; idc < 1; idc++) {
        printf("idc %d \n", idc);
        set_idc(idc_idf, idc, 12);
        // Reset AES
        uint8_t addr = 0xE0;
        int ret = write_bytes(fd, &addr, 1);
        uint8_t data = 0x02;
        ret = write_bytes(fd, &data, 1);

        if (set_calibration(fd, idc_idf) == EXIT_FAILURE) {
            printf("Set calibration failed\n");
        }
        // Write key into the AES core
        if (set_key_w(fd, key) == EXIT_FAILURE) {
            printf("Set key failed\n");
        }
        if (encrypt_w(fd, plaintext, cipher) == EXIT_FAILURE) {
            printf("Encrypt failed\n");
        }
        if (read_trace_w(fd, sensor_trace, temperature) == EXIT_FAILURE) {
            printf("Sensor trace collection failed\n");
        }
        
        // get min sample
        int min = 128;
        int current = 0;
        for (int j = 0; j < NUM_SAMPLES; j++) {
            current = 0;
            for (int i = 0; i < 16; i++) {
                current += count_one((int)sensor_trace[j * 16 + i]);
                if(j==0){
                printf("%02X", sensor_trace[i]);
                }
                
            }

            if (min > current) {
                min = current;
            }
        }
        if (min == 128) {
            break;
        }else{
            printf("min %d \n", min);
        }
    }

    int best_idc = 0;
    int best_idf = 0;
    bool break_loop = false;
    for (; idc < 33; idc++) {
        idf = 0;
        for (; idf < 96; idf++) {
            printf("idc idf %d %d\n", idc, idf);

            set_idc(idc_idf, idc, 12);
            set_idf(idc_idf, idf);

            // Reset AES
            uint8_t addr = 0xE0;
            int ret = write_bytes(fd, &addr, 1);
            uint8_t data = 0x02;
            ret = write_bytes(fd, &data, 1);

            if (set_calibration(fd, idc_idf) == EXIT_FAILURE) {
                printf("Set calibration failed\n");
            }
            // Write key into the AES core
            if (set_key_w(fd, key) == EXIT_FAILURE) {
                printf("Set key failed\n");
            }
            if (encrypt_w(fd, plaintext, cipher) == EXIT_FAILURE) {
                printf("Encrypt failed\n");
            }
            if (read_trace_w(fd, sensor_trace, temperature) == EXIT_FAILURE) {
                printf("Sensor trace collection failed\n");
            }

            int min = 128;
            int max = 0;
            int current = 0;
            for (int j = 0; j < NUM_SAMPLES; j++) {
                current = 0;
                for (int i = 0; i < 16; i++) {
                    current += count_one((int)sensor_trace[j + i]);
                    if(j==0){
                printf("%02X", sensor_trace[i]);
                }
                }
                if (min > current) {
                    min = current;
                }
                if (max < current) {
                    max = current;
                }
            }
            printf("max %d \n", max);
            if (max > 110 || min < 32) {
                continue;
            } else {
                printf("best idc found %d %d ", idc, idf);
                best_idc = idc;
                best_idf = idf;
                break_loop = true;
                break;
            }
        }
        if (break_loop) {
            break;
        }
    }
    set_idc(idc_idf, best_idc, 12);
    set_idf(idc_idf, best_idf);
    set_calibration(fd, idc_idf);
    return EXIT_SUCCESS;
}

int count_one(int x) {
    x = (x & (0x55555555)) + ((x >> 1) & (0x55555555));
    x = (x & (0x33333333)) + ((x >> 2) & (0x33333333));
    x = (x & (0x0f0f0f0f)) + ((x >> 4) & (0x0f0f0f0f));
    x = (x & (0x00ff00ff)) + ((x >> 8) & (0x00ff00ff));
    x = (x & (0x0000ffff)) + ((x >> 16) & (0x0000ffff));
    return x;
}

void set_idc(unsigned char idc_idf[16], int idc, int idf_width) {
    // we have to compute the number of 1s
    int i = 0;
    char buffer[4];
    for (i = 0; i < idc / 8; i++) {
        memset(buffer + i, 0xff, 1);
    }
    // compute the remainder, and depending on the remainder, add a number of 1s
    int remainder = idc % 8;
    if (remainder == 0) {
        memset(buffer + i, 0x00, 1);
    } else if (remainder == 1) {
        memset(buffer + i, 0x80, 1);
    } else if (remainder == 2) {
        memset(buffer + i, 0xc0, 1);
    } else if (remainder == 3) {
        memset(buffer + i, 0xe0, 1);
    } else if (remainder == 4) {
        memset(buffer + i, 0xf0, 1);
    } else if (remainder == 5) {
        memset(buffer + i, 0xf8, 1);
    } else if (remainder == 6) {
        memset(buffer + i, 0xfc, 1);
    } else if (remainder == 7) {
        memset(buffer + i, 0xfe, 1);
    }
    i++;
    for (; i < sizeof(buffer); i++) {
        memset(buffer + i, 0x00, 1);
    }
    // write the new idc value to the corresponding position in the idc_idf
    // array
    memcpy(idc_idf + idf_width, buffer, sizeof(buffer));
}

void set_idf(unsigned char idc_idf[16], int idf) {
    // we have to compute the number of 1s
    int i = 0;
    char buffer[12];
    for (i = 0; i < idf / 8; i++) {
        memset(buffer + i, 0xff, 1);
    }
    // compute the remainder, and depending on the remainder, add a number of 1s
    int remainder = idf % 8;
    if (remainder == 0) {
        memset(buffer + i, 0x00, 1);
    } else if (remainder == 1) {
        memset(buffer + i, 0x80, 1);
    } else if (remainder == 2) {
        memset(buffer + i, 0xc0, 1);
    } else if (remainder == 3) {
        memset(buffer + i, 0xe0, 1);
    } else if (remainder == 4) {
        memset(buffer + i, 0xf0, 1);
    } else if (remainder == 5) {
        memset(buffer + i, 0xf8, 1);
    } else if (remainder == 6) {
        memset(buffer + i, 0xfc, 1);
    } else if (remainder == 7) {
        memset(buffer + i, 0xfe, 1);
    }
    i++;
    for (; i < sizeof(buffer); i++) {
        memset(buffer + i, 0x00, 1);
    }
    // write the new idc value to the corresponding position in the idc_idf
    // array
    memcpy(idc_idf, buffer, sizeof(buffer));
}

/*
 *  Sends the calibration to the AES device
 *
 *  Paramaters :  fd    - file descriptor of the open and configured tty device
 * file key   - pointer to a 16 bytes array containing the key (MSB first)
 *
 *  Returns      : EXIT_SUCCESS if all went well, EXIT_FAILURE if not
 */
int set_calibration(int fd, uint8_t *idc_idf) {
    int ret;
    ret = write_address(fd, &ADDR_SPACE[NTR_IDX]);
    if (ret != EXIT_SUCCESS) return ret;

    ret = write_bytes(fd, idc_idf, NUM_BYTES);
    if (ret < 0) {
        fprintf(stderr, "Error writing the key to AES.\n");
        return EXIT_FAILURE;
    }

    tcdrain(fd);
    return EXIT_SUCCESS;
}

/*
 *  Sends the plaintext to the AES and reads the resulting cipher
 *
 *  Paramaters :  fd     - file descriptor of the open and configured tty device
 * file input  - pointer to a 16 bytes array containing the plaintext (MSB
 * first) cipher - pointer to an allocated 16 bytes array in which to store the
 * cipher
 *
 *  Returns      : EXIT_SUCCESS if all went well, EXIT_FAILURE if not
 */
int encrypt_w(int fd, uint8_t *input, uint8_t *cipher) {
    int ret;
    uint8_t ack;
    ret = write_address(fd, &ADDR_SPACE[DAT_IDX]);
    if (ret != EXIT_SUCCESS) return ret;

    ret = write_bytes(fd, input, NUM_BYTES);
    if (ret < 0) {
        fprintf(stderr, "Error writing the plaintext to AES.\n");
        return EXIT_FAILURE;
    }
    tcdrain(fd);

    ret = read_bytes(fd, &ack, 1);
    if (ret < 0 || ack != 0x42) {
        fprintf(stderr, "Error reading clear flag from the device.\n");
        return EXIT_FAILURE;
    }

    ret = write_address(fd, &ADDR_SPACE[CIP_IDX]);
    if (ret != EXIT_SUCCESS) return ret;

    ret = read_bytes(fd, cipher, NUM_BYTES);
    if (ret < 0) {
        fprintf(stderr, "Error reading the cipher from AES.\n");
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}

/*
 *  Reads the traces from the AES
 *
 *  Paramaters :  fd             - file descriptor of the open and configured
 * tty device file sensor_traces  - pointer to an allocated 256 bytes array in
 * which to store the sensor trace (LSB first) signal_traces  - pointer to an
 * allocated 256 bytes array in which to store the signal trace (LSB first)
 *
 *  Returns      : EXIT_SUCCESS if all went well, EXIT_FAILURE if not
 */
int read_trace_w(int fd, uint8_t *sensor_traces, uint8_t *signal_traces) {
    int ret;
    uint8_t temp[NUM_SAMPLES * 18];
    ret = write_address(fd, &ADDR_SPACE[TRC_IDX]);
    if (ret != EXIT_SUCCESS) return ret;

    ret = read_bytes(fd, temp, NUM_SAMPLES * 18);
    if (ret < 0) {
        fprintf(stderr, "Error reading the traces from AES.\n");
        return EXIT_FAILURE;
    }

    size_t num_B = 18 * NUM_SAMPLES - 1;

    size_t sensor_trace_index = 0;
    size_t signal_trace_index = 0;
    size_t temp_index = 0;
    for(size_t i=0;i<NUM_SAMPLES;i++){
        sensor_traces[i*16] = temp[num_B - 18*i];
        sensor_traces[i*16+1] = temp[num_B - 18*i-1];
        sensor_traces[i*16+2] = temp[num_B - 18*i-2];
        sensor_traces[i*16+3] = temp[num_B - 18*i-3];
        sensor_traces[i*16+4] = temp[num_B - 18*i-4];
        sensor_traces[i*16+5] = temp[num_B - 18*i-5];
        sensor_traces[i*16+6] = temp[num_B - 18*i-6];
        sensor_traces[i*16+7] = temp[num_B - 18*i-7];
        sensor_traces[i*16+8] = temp[num_B - 18*i-8];
        sensor_traces[i*16+9] = temp[num_B - 18*i-9];
        sensor_traces[i*16+10] = temp[num_B - 18*i-10];
        sensor_traces[i*16+11] = temp[num_B - 18*i-11];
        sensor_traces[i*16+12] = temp[num_B - 18*i-12];
        sensor_traces[i*16+13] = temp[num_B - 18*i-13];
        sensor_traces[i*16+14] = temp[num_B - 18*i-14];
        sensor_traces[i*16+15] = temp[num_B - 18*i-15];
        signal_traces[i*2] = temp[num_B - 18*i-17];
        signal_traces[i*2+1] = temp[num_B - 18*i-16];
    }
    

   /* for (size_t i = 0; i < NUM_SAMPLES; i++) {
        
        for (size_t j = 0; j < 1; j++) {
            sensor_traces[sensor_trace_index] = temp[temp_index];
            sensor_trace_index++;
            temp_index++;
        }
        for (size_t j = 0; j < ; j++) {
            signal_traces[signal_trace_index] = temp[temp_index];
            signal_trace_index++;
            temp_index++;
        }
    }*/
    return EXIT_SUCCESS;
}

/*
 *  Dump the sensor trace at the end of the file pointed by fp.
 *  Prints the value as a string representation of the hexadecimal value from
 * the sensor
 *
 *  Paramaters :  fp             - file pointer to the open files in which to
 * dump the values sensor_trace   - array of 256 bytes containing the sensor
 * trace
 *
 *  Returns      : EXIT_SUCCESS if all went well, EXIT_FAILURE if not
 */
int dump_sensor_trace(FILE *fp, uint8_t *sensor_trace, int last_line) {
    /* Dump Sensor hex value */
    int sensor_index = 0;
    for (size_t i = 0; i < NUM_SAMPLES; i++) {
        for (size_t j = 0; j < 15; j++) {
            if (fprintf(fp, "%02x", sensor_trace[sensor_index] & 0xFF) < 0)
                return EXIT_FAILURE;
            sensor_index++;
        }
        if (i < (NUM_SAMPLES - 1)) {
            if (fprintf(fp, "%02x,", sensor_trace[sensor_index] & 0xFF) < 0)
                return EXIT_FAILURE;
            sensor_index++;
        } else {
            if (fprintf(fp, "%02x", sensor_trace[sensor_index] & 0xFF) < 0)
                return EXIT_FAILURE;
            sensor_index++;
        }
    }
    if (!last_line) fprintf(fp, "\n");
    return EXIT_SUCCESS;
}

/*
 *  Dump the sensor trace at the end of the file pointed by fp.
 *  Prints the value as a string binary character of the bit indicated by offset
 *
 *
 *  Paramaters :  fp             - file pointer to the open files in which to
 * dump the values signal_trace   - array of 256 bytes containing the signal
 * trace offset         - offset of the desired bit in the trace samples
 *                last_line      - flag indicating whether the printed line is
 * the last of the experiment
 *
 *  Returns      : EXIT_SUCCESS if all went well, EXIT_FAILURE if not
 */
int dump_signal_trace(FILE *fp, uint8_t *signal_trace, size_t offset,
                      int last_line) {
    int signal_index = 0;
    for (size_t i = 0; i < NUM_SAMPLES; i++) {
        int temp1 = signal_trace[signal_index];
        signal_index++;
        int temp2 = signal_trace[signal_index];
        signal_index++;
        int temp3 = temp1 << 8 | temp2;
        

        double temp4 = ((((double)temp3 * 503.975) / 4096) - 273.15);
        if (i < (NUM_SAMPLES - 1)) {
            if (fprintf(fp, "%lf,", temp4) < 0) return EXIT_FAILURE;
        } else {
            if (fprintf(fp, "%lf", temp4) < 0) return EXIT_FAILURE;
        }
    }
    if (!last_line) fprintf(fp, "\n");
    
    return EXIT_SUCCESS;
}

/*
 *  Checks if the cipher returned by the AES is correct by computing it using a
 * software implementation of the AES encryption.
 *
 *  Parameters   : inputs  - structure containing the key, plaintext and masks
 *                 outputs - structure containing the cipher computed by the
 * hardware AES
 *
 *  Returns      : EXIT_SUCCESS if all bytes match, EXIT_FAILURE otherwise
 *
 */
int check_soft_encrypt(input_t *inputs, output_t *outputs, int sbox_en,
                       int masked) {
    word_t cipher_soft;
    bool match = true;
    if (sbox_en == 0) {
        memcpy(&cipher_soft, inputs->plaintext, NUM_BYTES);

        AES_Encrypt(cipher_soft, inputs->key);

        for (size_t i = 0; i < NUM_BYTES; i++) {
            if (cipher_soft[i] != outputs->cipher[i]) {
                fprintf(stderr,
                        "Error: Soft and Hard cipher are different at byte %lu "
                        ": %x != %x \n",
                        i, cipher_soft[i] & 0xFF, outputs->cipher[i] & 0xFF);
                match = false;
            }
        }
    } else {
        if (masked == 0) {
            if ((uint8_t)outputs->cipher[15] !=
                ((uint8_t)s_box[inputs->plaintext[15] ^ inputs->key[15]])) {
                fprintf(stderr,
                        "Error: Soft and Hard cipher are different for the "
                        "S-box : %02x != %02x \n",
                        s_box[inputs->plaintext[15] ^ inputs->key[15]],
                        outputs->cipher[15]);
                match = false;
            }
        } else {
            if ((uint8_t)outputs->cipher[15] !=
                ((uint8_t)s_box[inputs->plaintext[15] ^ inputs->key[15]] ^
                 inputs->masks[1][15])) {
                fprintf(stderr,
                        "Error: Soft and Hard cipher are different for the "
                        "masked S-box : %02x != %02x \n",
                        s_box[inputs->plaintext[15] ^ inputs->key[15]] ^
                            inputs->masks[1][15],
                        outputs->cipher[15]);
                match = false;
            }
        }
    }

    return match ? EXIT_SUCCESS : EXIT_FAILURE;
}

/*
 *  Resets the AES
 *
 *  This "soft" reset is only taken into account by the AES if the controller's
 * FSM is not in a state that is expecting data (key, masks, plaintext) from the
 * host. In such a case, a hardware reset is necessary.
 *
 *  Parameters   : conf    - structure  containing the open file descriptor of
 * the tty device file
 *
 *  Returns      : EXIT_SUCCESS if all went well, EXIT_FAILURE if not
 *
 */
int reset_loop(config_t *conf) {
    int ret;
    uint8_t reset_addr = 0xFF;
    ret = write_bytes(conf->tty_fd, &reset_addr, 1);

    return ret;
}

void print_help() {
    printf("HELP\n");
    printf("\n==================================================\n");
    printf("AES Power Side-Channel Measurement Software\n");
    printf("\n==================================================\n");
    printf("\nShort summary:\n");
    printf(
        "\t- This program sends plaintexts and reads ciphertexts from an AES "
        "core running on the Artix7 board. The program can also read the "
        "sensor power consumption traces from the FPGA and store them in a "
        ".csv file.\n");
    printf("\t- The plaintexts sent to the AES core can be in:\n");
    printf("\t\t - constant mode (one same plaintext always fed to the AES)\n");
    printf(
        "\t\t - chained mode  (the current ciphertext is used as the next "
        "plaintext)\n");
    printf(
        "\t\t - t-test mode   (chained plaintexts are alternating with a "
        "single fixed plaintext).\n");
    printf(
        "\t- The key can stay the same for all encryptions (default key), or "
        "can randomly change for every encryption.\n");
    printf(
        "\t- The ouput of this program is by default in the same directory as "
        "the executable, but this can be changed. By default, the output files "
        "are the following:\n");
    printf("\t\t - Binary file containing all the plaintexts\n");
    printf("\t\t - Binary file containing all the ciphertexts\n");
    printf(
        "\t\t - Binary file containing all the keys (or one single key if it "
        "does not change)\n");
    printf("\n==================================================\n");
    printf("\nProgram arguments:\n");
    printf("\t-h:              print help\n");
    printf("\t-k <number>:     key mode:\n");
    printf("\t\t 0 - constant (default key)\n");
    printf("\t\t 1 - random\n");
    printf("\t-pt <number>:    plaintext mode:\n");
    printf("\t\t - 0: constant\n");
    printf("\t\t - 1: chained\n");
    printf("\t\t - 2: t-test\n");
    printf("\t-m <number>:     number of masks (if masked AES):\n");
    printf("\t\t -  1: 1 mask  per round, reused for each round\n");
    printf("\t\t -  2: 2 masks per round, reused for each round\n");
    printf("\t\t -  4: 4 masks per round, reused for each round\n");
    printf("\t\t - 20: 2 masks per round, new for each round\n");
    printf("\t\t - 40: 4 masks per round, new for each round\n");
    printf("\t-t <number>:     number of encryptions (traces).\n");
    printf(
        "\t-f:              AES frequency mode (from 0 to 19, only in AES "
        "frequency sweep)\n");
    printf(
        "\t-sb:             S-box mode (if masks used, only 2 masks "
        "allowed)\n");
    printf("\t-s:              save sensor traces\n");
    printf("\t-d <dir-path>:   specify output directory\n");
    printf("\n\n\n");

    return;
}

int parse_args(int argc, char *argv[], config_t *config) {
    if (argc == 1) {
        print_help();
        return EXIT_FAILURE;
    }

    if (argv == NULL) {
        fprintf(stderr, "Passed NULL argument string to parse_args\n");
        return EXIT_FAILURE;
    }

    for (int i = 1; i < argc; i++) {
        if (argv[i][1] == 'h') {
            print_help();
            exit(1);
        } else if (argv[i][1] == 'u') {
            i++;
            if (config->tty_dev_path != NULL) free(config->tty_dev_path);
            strcpy(config->tty_dev_path, argv[i]);
            int temp_fd = open(argv[i], O_RDWR | O_NOCTTY | O_SYNC);
            if (temp_fd < 0) {
                fprintf(stderr, "Error opening %s: %s\n", argv[i],
                        strerror((errno)));
                return EXIT_FAILURE;
            }
            set_interface_attribs(temp_fd, B115200);
            config->tty_fd = temp_fd;
        } else if (argv[i][1] == 'k') {
            i++;
            config->key_mode = atoi(argv[i]);
            if (config->key_mode > 1) {
                printf("Unknown key mode : -k %d\n\n", config->key_mode);
                print_help();
                return EXIT_FAILURE;
            }
        } else if (argv[i][1] == 'p') {
            i++;
            config->plain_mode = atoi(argv[i]);
            if (config->plain_mode > 2) {
                printf("Unknown plaintext mode : -pt %d\n\n",
                       config->plain_mode);
                print_help();
                return EXIT_FAILURE;
            }
        } else if (argv[i][1] == 'm') {
            i++;
            config->num_mask = atoi(argv[i]);
            if ((config->num_mask != 1) && (config->num_mask != 2) &&
                (config->num_mask != 4) && (config->num_mask != 20) &&
                (config->num_mask != 40)) {
                printf("Unsuported number of masks : -m %d\n\n",
                       config->num_mask);
                print_help();
                return EXIT_FAILURE;
            }
        } else if (argv[i][1] == 't') {
            i++;
            config->num_traces = atoi(argv[i]);
        } else if (argv[i][1] == 'f') {
            i++;
            config->freq_mode = atoi(argv[i]);
            if (config->freq_mode > 19) {
                printf("Unknown frequency mode : -f %d\n\n", config->freq_mode);
                print_help();
                return EXIT_FAILURE;
            }
        } else if (argv[i][1] == 's') {
            if (argv[i][2] == 'b') {
                config->sbox_en = 1;
            } else {
                config->sensor_en = 1;
            }
        } else if (argv[i][1] == 'd') {
            i++;
            memcpy(config->dump_path, argv[i], strlen(argv[i]));
            config->dump_path[strlen(argv[i])] = '\0';
        } else {
            printf("Unknown argument: -%c\n\n", argv[i][1]);
            print_help();
            return EXIT_FAILURE;
        }
    }

    if (config->sbox_en == 1 &&
        (config->num_mask != 2 && config->num_mask != 0)) {
        printf("sbox_en = %d, num_mask = %d\n", config->sbox_en,
               config->num_mask);
        printf("Error: Masked S-box can have only 2 masks!\n");
        print_help();
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}

int init_config(config_t *config) {
    if (config == NULL) return EXIT_FAILURE;

    config->tty_dev_path =
        (char *)malloc((strlen(DFLT_URT) + 1) * sizeof(char));
    strcpy(config->tty_dev_path, DFLT_URT);
    config->tty_fd = open(config->tty_dev_path, O_RDWR | O_NOCTTY | O_SYNC);
    if (config->tty_fd < 0) {
        fprintf(stderr, "Error opening %s: %s\n", config->tty_dev_path,
                strerror((errno)));
        return EXIT_FAILURE;
    }
    set_interface_attribs(config->tty_fd, B115200);

    config->key_mode = 0;
    config->plain_mode = 0;
    config->freq_mode = -1;
    config->num_mask = 0;
    config->num_traces = 10;
    config->sbox_en = 0;
    config->sensor_en = 0;
    config->dump_path[0] = '.';
    config->dump_path[1] = '\0';

    return EXIT_SUCCESS;
}

int print_config(config_t *config) {
    if (config == NULL) return EXIT_FAILURE;

    printf("\nProgram configuration:\n");
    printf("\t- TTY device path: %s\n", config->tty_dev_path);
    printf("\t- TTY FD: %d\n", config->tty_fd);
    printf("\t- key mode: %d\n", config->key_mode);
    printf("\t- plaintext mode: %d\n", config->plain_mode);
    printf("\t- frequency mode: %d\n", config->freq_mode);
    printf("\t- number of masks: %d\n", config->num_mask);
    printf("\t- number of traces: %ld\n", config->num_traces);
    printf("\t- sbox enabled: %d\n", config->sbox_en);
    printf("\t- sensor enabled: %d\n", config->sensor_en);
    printf("\t- output path: %s\n\n", config->dump_path);

    return EXIT_SUCCESS;
}
