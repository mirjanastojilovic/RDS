/*
 RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
 Copyright 2023, School of Computer and Communication Sciences, EPFL.

 All rights reserved. Use of this source code is governed by a
 BSD-style license that can be found in the LICENSE.md file. 
 */

#include <termios.h>
#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>

#ifndef DATA_UTILS_H
#define DATA_UTILS_H

#define WORD_SIZE sizeof(uint8_t)
#define NUM_BYTES 0x10
#define NUM_SAMPLES 0x100

#define MSR_SIZE  0x2
#define MAX_MASKS 0x20

/* FPGA Address space constants */
#define ADDR_K  0x1
#define ADDR_Ma 0x2
#define ADDR_D  0x3
#define ADDR_E  0x4
#define ADDR_Ms 0x5
#define ADDR_Nt 0x6

/* Command line parameters */
#define URT_DELIM "-u"
#define KEY_DELIM "-k"
#define MSK_DELIM "-m"
#define DAT_DELIM "-d"
#define NMS_DELIM "-nm"
#define CIP_DELIM "-c"
#define TRC_DELIM "-t"
#define DEFAULT_C "run"

#define KMD_DELIM "-km"
#define DMD_DELIM "-dm"
#define NTR_DELIM "-nt"
#define DMP_DELIM "-dump"



/* Default values for the configuration */
#define DFLT_URT "/dev/ttyUSB1"
#define DFLT_BYTE 0x00
#define DFLT_OUT stdout
#define CONFIG_FILE_PATH "../config.cfg"

#define MS_TIMEOUT 500

#define KEY_IDX 0
#define MSK_IDX 1
#define DAT_IDX 2
#define CIP_IDX 3
#define NTR_IDX 4
#define TRC_IDX 5


/* Traces configuration */
#define BYTES_PER_SAMPLE 2
#define SENSOR_B_OFFSET  1
#define SIGNAL_B_OFFSET  0
#define TTEST_FAIL_b     0
#define TTEST_VALID_b    1
#define TTEST_OVALID_b   2
#define AES_BUSY_b       3

#define HELP_STR "To run the program, enter one of the following combinations :\n - no parameter / 'run' : run with default config in config.cfg file\n - 'run file.cfg' : run with config in file.cfg\n - options : use '-X HEX | PATH' to provide either hexadecimal (LSB first) or path to file for the key (-k),\n            the mask(s) (-m) or the plaintext (-d). use '-X PATH' to indicate the output file for the cipher (-c) or the traces (-t)\n            default are 0x61 for key and plaintext (no masks), stdout for the output.\n"

#define DUMP_PATH   "./"
#define B_CIPH_DUMP "cipher.bin"
#define B_KEY_DUMP  "key.bin"
#define B_PLNT_DUMP "plaintext.bin"
#define B_MSKS_DUMP "masks.bin"
#define H_TRSE_DUMP "sensor_traces.csv"
#define TT_VLD_DUMP "ttest_valid.csv"
#define TT_FAIL_DUMP "ttest_fail.csv"
#define TT_OVLD_DUMP "ttest_output_valid.csv"
#define AES_BSY_DUMP "aes_busy.csv"

typedef  uint8_t word_t[NUM_BYTES/WORD_SIZE];
typedef  uint8_t trace_t[2];
typedef  char    file_path[100];


static word_t default_key = {0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef, 0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef};
static word_t default_plain = {0x00};

typedef struct {

    word_t key;

    word_t * masks;
    uint8_t num_mask;

    word_t clear_data;
    word_t encrypted_data;

    uint8_t * traces;
    uint16_t num_traces;

    int conf_done;

} data_full_t;

typedef struct {

    file_path tty_dev_path;
    int       tty_fd;

    file_path key_path;
    FILE *    k_file;

    file_path mask_path;
    FILE *    m_file;

    file_path data_path;
    FILE *    d_file;

    file_path cipher_path;
    FILE *    c_file;

    file_path traces_path;
    FILE *    t_file;

} files_t;

typedef struct {

    FILE * key_dump;
    FILE * mask_dump;
    FILE * plaintext_dump;
    FILE * cipher_dump;
    FILE * sensor_trace_dump;
    FILE * ttest_valid_dump;
    FILE * ttest_fail_dump;
    FILE * ttest_output_valid_dump;
    FILE * aes_busy_dump;

} dumps_t;

typedef struct {

    char * tty_dev_path;
    int    tty_fd;

    int    key_mode;
    int    plain_mode;
    int    freq_mode;

    int    sbox_en;
    int    sensor_en;

    int    num_mask;

    size_t num_traces;

    char dump_path[300];

} config_t;

typedef struct {

    word_t   key;

    word_t * masks;

    size_t   num_mask;

    word_t   plaintext;

    word_t   idc_idf;

} input_t;

typedef struct {

   word_t    cipher;
   word_t    cipher_chained;

   uint8_t    sensor_trace[16*NUM_SAMPLES];

   uint8_t    signal_trace[2*NUM_SAMPLES];

} output_t;

typedef struct {

  word_t key;

  word_t * masks;

  word_t plain;

  word_t cipher;
  word_t cipher_chained;


}  state_t;


static const uint8_t ADDR_SPACE[6] = {0x1, 0x2, 0x3, 0x4, 0x6, 0x5};

static const char *  ADDR_NAMES[6] = {"", "key", "masks", "plaintext", "cipher", "trace"};


/*      UART configuration and I/O operations */

int     set_interface_attribs(int fd, int speed);
void    set_mincount(int fd, int mcount);
int     write_bytes(int fd, const uint8_t * buffer, size_t numBytes);
int     read_bytes(int fd, uint8_t * buffer, size_t numBytes);
int     reinit_fpga(config_t * config, input_t * inputs, output_t * outputs, state_t * state);

/*      Data I/O utilities */
void    get_value(char * param, file_path * filepath, FILE ** fp, word_t * value);
void    get_values(char * params[], int offset, file_path * file_path, FILE ** fp, word_t ** value, size_t num_value);
void    get_hex_value(char * param, word_t * value);
void    parse_hex(char * param, word_t * value);
void    print_hex_word(uint8_t * buffer, size_t num_bytes, FILE * output);
void    print_traces(uint8_t * traces, uint16_t num_traces, FILE * output);

/*      User input parsing and config utilities */
void    gen_random_word(word_t dst);
int     get_delim(char * arg);
size_t  get_number_of_masks(char * argv[], int offset, int argc);
int     parse_command(size_t argc_offset, int argc, char * argv[], data_full_t * data, files_t * files);
int     parse_config(const char * path_to_file, data_full_t * data, files_t * files);
int     parse_command_modes(size_t argc_offset, int argc, char * argv[], config_t * conf, input_t * inputs, dumps_t * dumps);
int     parse_command_no_val(size_t argc_offset, int argc, char * argv[], config_t * conf, input_t * inputs);
int     parse_config_modes(const char * path_to_file, config_t * conf, input_t * inputs, dumps_t * dumps);
void    finish_config(bool params_done[11], files_t * files, data_full_t * data);
int     finish_config_modes(bool params_done[11], config_t * conf, input_t * inputs, dumps_t * dumps);
int     finish_config_no_val(bool params_done[11], config_t * conf, input_t * inputs);
void    export_config(const char * path_to_config_file, files_t * files, data_full_t * data);
int     free_rsc(data_full_t * data, files_t * files);

void    print_help();
int     print_config(config_t * config);
int     print_config2(config_t * config);
int     parse_args(int argc, char* argv[], config_t* config);
int     init_config(config_t* config);


/*      Experiment utilities */
int     setup_aes(config_t * conf, input_t * inputs);
int     encrypt_word(config_t * conf, input_t * inputs, output_t * outputs);
int     dump_output(config_t * conf, output_t * outputs, dumps_t * dumps);
int     dump_input(input_t * inputs, dumps_t * dumps);

int     set_key_w(int fd, uint8_t * key);
int     set_mask_w(int fd, uint8_t * mask);
int     set_calibration(int fd, uint8_t * idc_idf);
int     calibrate_sensor(int fd, uint8_t * plaintext, uint8_t * key, uint8_t * idc_idf);
void    set_idc(unsigned char idc_idf[16], int idc, int idf_width);
void    set_idf(unsigned char idc_idf[16], int idf);
int     count_one(int x);
int     encrypt_w(int fd, uint8_t * input, uint8_t * cipher);
int     read_trace_w(int fd, uint8_t * sensor_traces, uint8_t * signal_traces);
int     dump_sensor_trace(FILE * fp, uint8_t * sensor_trace, int last_line);
int     dump_signal_trace(FILE * fp, uint8_t * signal_trace, size_t offset, int last_line);

int     check_soft_encrypt(input_t * inputs, output_t * outputs, int sbox_en, int masked);
int     reset_loop(config_t * conf);

#endif // DATA_UTILS_H
