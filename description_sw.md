# Alveo
<details>
<summary>host.cpp</summary>

```
void main(int argc, char* argv[])

    entry point to the program

    argc: length of the argument vector
    argv: array of character pointers

    returns: 0 on success, -1 on failure
```

</details>

<details>
<summary>utils.cpp</summary>

```
unsigned char hamming_weight(uint32_t data)

    calculates the hamming weight of the given uint32_t data

    data: the hamming weight will be calculated on this value

    returns: hamming weight of the argument data
```
```
int count_one(int x)

    calculates the hamming weight of the binary representation of x

    x: the hamming weight will be calculated on this value

    returns: hamming weight of the argument x
```
```
int get_min_sample(uint32_t * hbuf, int N_SAMPLES, int SENSOR_WIDTH)

    computes the value of the minimum sample in hbuf

    hbuf: the array which holds the samples
    N_SAMPLES: number of samples in hbuf
    SENSOR_WIDTH: number of registers the sensor is composed of; usually 128

    returns: int which is the value of the minimum sample in hbuf
```
```
int get_max_sample(uint32_t * hbuf, int N_SAMPLES, int SENSOR_WIDTH)

    computes the value of the maximum sample in hbuf


    hbuf: the array which holds the samples
    N_SAMPLES: number of samples in hbuf
    SENSOR_WIDTH: number of registers the sensor is composed of; usually 128

    returns: int which is the value of the minimum sample in hbuf

```
```
uint32_t * pack_idc_idf(uint32_t * idc_idf, int idc, int idf, int IDC_SIZE, int IDF_SIZE)

    given the two independent integers idc and idf, the function packs them into one array idc_idf. idc_idf has the format that can be sent to the hardware for calibration.

    idc_idf: array of uint32_t data types that encodes the calibration for the voltage-drop sensor
    idc: the number of coarse elements (LUT) that should be used for calibration
    idf: the number of fine elements (CARRY8) that should be used for calibration
    IDC_SIZE: the number of coarse elements (LUT) that are available for calibration
    IDF_SIZE: the number of fine elements (CARRY8) that are available for calibration

    returns: the resulting array idc_idf
```
```
void uint8_to_uint32(uint8_t * input, uint32_t * output)

    coverts the uint8_t data type into a uint32_t data type

    input: the uint8_t value that should be converted
    output: the resulting uint32_t value after the conversion

    returns: void
```
```
void uint32_to_uint8(uint32_t * input, uint8_t * output)

    coverts the uint32_t data type into a uint8_t data type

    input: the uint32_t value that should be converted
    output: the resulting uint8_t value after the conversion

    returns: void
```
```
void aes_encrypt(xrt::ip kernel, uint8_t * key, uint8_t * plaintext, uint8_t * ciphertext)

    run the AES encryption 

    kernel: xrt ip object representing the RTL kernel
    key: the AES key which is used to encrypt the plaintext
    plaintext: plaintext that is sent to the hardware for the AES encryption
    ciphertext: result of the AES encryption with the plaintext using the key

    returns: void
```
```
void save_trace(xrt::bo buffer, uint32_t *hbuf, int N_SAMPLES, int SENSOR_WIDTH, FILE *traces_bin, FILE *traces_raw)
    read the traces from DRAM and save them in a file

    buffer: xrt buffer object used to transfer the data between the host and the FPGA
    hbuf: array that holds the recorded traces
    N_SAMPLES: the number of samples per trace
    SENSOR_WIDTH: the number of registers the sensor is composed of; usually 128
    traces_bin: pointer to a file. In this file, the samples are saved as encoded values.
    traces_bin_raw: pointer to a file. In this file, the raw traces are saved.

    returns: void
```
```
void save_ciphertext(uint8_t *ciphertext, FILE *ciphertext_f)
    
    save the ciphertext to a file

    ciphertext: result of the AES encryption.
    ciphertext_f: pointer to the file which saves the ciphertexts of the AES encryptions.

    returns: void
```
```
void save_key(uint8_t *key, FILE *key_f)

    save the key to a file

    key: the AES key which is used for the encryption
    key_f: pointer to the file which saves the key

    returns: void
```
```
void init_system(xrt::ip kernel, xrt::bo buffer) 

    initializes the FPGA system by performing a reset and sending the correct DRAM pointers

    kernel: xrt ip object representing the RTL kernel

    buffer: xrt buffer object used to transfer the data between the host and the FPGA

    returns: void
```
```
void send_calibration(xrt::ip kernel, xrt::bo buffer, uint32_t* hbuf, uint32_t **idc_idf, int N_SENSORS, int IDC_SIZE, int IDF_SIZE)

    send the calibration which is specified in the array idc_idf to the hardware to calibrate the voltage-drop sensor

    kernel: xrt ip object representing the RTL kernel
    buffer: xrt buffer object used to transfer the data between the host and the FPGA
    hbuf: array that holds the recorded traces; not used
    idc_idf: the array which specifies the calibration
    N_SENSORS: the number of sensors that are implemented in hardware; usually 1
    IDC_SIZE: the number of coarse elements (LUT) that are available for calibration
    IDF_SIZE: the number of fine elements (CARRY8) that are available for calibration

    returns: void
```
```
void calibrate_from_file(xrt::ip kernel, xrt::bo buffer, uint32_t* hbuf, int N_SENSORS, int IDC_SIZE, int IDF_SIZE, char* CALIB_PATH)

    send the calibration which is specified in a file to the hardware to calibrate the voltage-drop sensor

    kernel: xrt ip object representing the RTL kernel
    buffer: xrt buffer object used to transfer the data between the host and the FPGA
    hbuf: array that holds the recorded traces; not used
    N_SENSORS: the number of sensors that are implemented in hardware; usually 1
    IDC_SIZE: the number of coarse elements (LUT) that are available for calibration
    IDF_SIZE: the number of fine elements (CARRY8) that are available for calibration
    CALIB_PATH: pointer to the file which specifies the calibration of idc and idf

    returns: void
```
```
void calibrate_tdc(xrt::ip kernel, xrt::bo buffer, uint32_t * hbuf, char calib_file_name[100], int N_SENSORS, int N_SAMPLES, int IDC_SIZE, int IDF_SIZE, int calib, int SENSOR_WIDTH, FILE* idc_idf_f)

    this function automatically calibrates the TDC voltage-drop sensor (uses only coarse calibration)

    kernel: xrt ip object representing the RTL kernel
    buffer: xrt buffer object used to transfer the data between the host and the FPGA
    calib_file_name: point to the file; not used
    N_SENSORS: the number of sensors that are implemented in hardware; usually 1
    IDC_SIZE: the number of coarse elements (LUT) that are available for calibration
    IDF_SIZE: the number of fine elements (CARRY8) that are available for calibration
    calib: int; not used
    SENSOR_WIDTH: the number of registers the sensor is composed of; usually 128
    idc_idf_f: pointer to the file which saves the calibration

    returns: void
```
```
void calibrate_rds(xrt::ip kernel, xrt::bo buffer, uint32_t * hbuf, char calib_file_name[100], int N_SENSORS, int N_SAMPLES, int IDC_SIZE, int IDF_SIZE, int calib, int SENSOR_WIDTH, FILE* idc_idf_f)

    this function automatically calibrates the RDS voltage-drop sensor (uses coarse and fine calibration)

    kernel: xrt ip object representing the RTL kernel
    buffer: xrt buffer object used to transfer the data between the host and the FPGA
    calib_file_name: point to the file; not used
    N_SENSORS: the number of sensors that are implemented in hardware; usually 1
    IDC_SIZE: the number of coarse elements (LUT) that are available for calibration
    IDF_SIZE: the number of fine elements (CARRY8) that are available for calibration
    calib: int; not used
    SENSOR_WIDTH: the number of registers the sensor is composed of; usually 128
    idc_idf_f: pointer to the file which saves the calibration

    returns: void
```
```
void save_temperature(FILE * temperature_f, int trace)

    save the temperature of a corresponding trace to a file

    temperature_f: pointer to the file which saves the temperature
    trace: indicates to which trace the temperature measurement belongs

    returns: void
```
</details>

# Basys

<details>
<summary>aes_soft.c</summary>

```
void KeyExpansionCore (unsigned char* in, unsigned char i)

    performs a one-byte left circular shift, the AES S-box, and round constant as part of the AES key schedule

    in: number of terms in the series to sum
    i: round constant of the key expansion

    returns: void
``` 
```
void KeyExpansion(unsigned char* inputKey, unsigned char* expandedKeys)

    performs the AES key schedule to expand the inputKey into 11 separate round keys

    inputKey: AES master key
    expandedKeys: stores the 11 AES round keys 

    returns: void
``` 
```
void SubBytes(unsigned char* state)

    Substitutes bytes from the state with the values from the S-Box.

    state: The value on which the substitution should be performed.

    returns: void
``` 
```
void ShiftRows(unsigned char* state)

    Cyclically shifts the byte in each row by a certain offset.

    state: The values (16bytes) on which the shiftRows should be perfomed.

    returns: void
``` 
```
void MixColumns(unsigned char* state)

    This function multiplies the state with a special matrix.

    state: The values (16bytes) on which the shiftRows should be perfomed.

    returns: void
``` 
```
void AddRoundKey(unsigned char* state, unsigned char* roundKey)

    Performs the XOR of each byte in the state and the roundKey.

    state: The values (16bytes) on which the AddRoundKey should be perfomed.
    roundKey: The subkey of the corresponding round.

    returns: void
``` 
```
void AES_Encrypt(unsigned char* message, unsigned char* key)

    Performs the AES encryption on the message using the key.

    message: Plaintext that needs to be encrypted.
    key: The secret master key.

    returns: void
``` 
</details>

<details>
<summary>data_utils.c</summary>

```
int set_interface_attribs(int fd, int speed)

    configures the tty interface of the UART device

    fd: file descriptor that must refer to a terminal
    speed: baud rate

    returns: 0 on success, -1 on failure
```
```
void set_mincount(int fd, int mcount)

    configures the min bytes read parameter of the tty UART device file

    fd: file descriptor that must refer to a terminal
    mcount: set min number of bytes per read (before timeout)

    returns: void
```
```
int write_bytes(int fd, const uint8_t *buffer, size_t numBytes)

    writes numBytes from buffer to the already configured and open file assigned to fd

    fd: file descriptor that must refer to a terminal
    buffer: array of bytes containing the data to be written
    numBytes: number of bytes to write

    returns: 0 on success, otherwise the number of bytes that were effectively written
```
```
int read_bytes(int fd, uint8_t *buffer, size_t numBytes)

    reads at most numBytes from fd to the already allocated buffer
 
    fd: file descriptor of the opened input file 
    buffer: array of bytes to be filled with the data which will be read
    numBytes: number of bytes to read

    returns: the number of bytes that were effectively read, otherwise -1
```
```
int reinit_fpga(config_t *config, input_t *inputs, output_t *outputs, state_t *state)

    closes the tty device file, reopens it, reconfigures it, resets the AES and restores the values from state in the inputs and outputs structures
 
    config: structure containing the file descriptor and path to the tty device file
    inputs: input structure to restore (key, masks and plaintext)
    outputs: output structure to restore (cipher, cipher_chained)
    state: structure with saved values used to restore the others

    returns: 0 on success, 1 on failure
```
```
void get_value(char *param, file_path *filepath, FILE **fp, word_t *value)

    This function reads the content of the param buffer and uses it to fill the user's structure. If the parameter is a path to a file, the path, a pointer to the open file and the value read in the file are stored in filepath, fp and value. If param contains a (string) value, it is parsed and placed into value. fp is set to null and filepath is kept empty.
 
    param: pointer to the parameter string to be read
    filpath: pointer to char buffer to be filled with the parameter's file
    fp: pointer to the parameter's file pointer to be opened
    value: pointer to the parameter's byte array to be filled  

    returns: void
```
```
void get_values(char *params[], int offset, file_path *file_path, FILE **fp, word_t **value, size_t num_value)

    This function reads the content of the param buffer and uses it to fill the user's structure. If the parameter is a path to a file: the path, a pointer to the open file and the value read in the file are stored in filepath, fp and value. If param contains a (string) value: it is parsed and placed into "value". fp is set to null and filepath is kept empty. 
 
    num_value elements will be read and parsed from the params array. Each of those can be either an hexadecimal string value or a path to a file containing a value (although having a consistent way to provide input is preferred).
 
    params: pointer to an array of values for the same parameter (e.g. several masks)
    offset: index offset at which to start reading the parameter values
    filpath: pointer to char buffer to be filled with the parameter's file
    fp: pointer to the parameter's file pointer to be opened
    value: pointer to the parameter's array of values
    num_value: number of values to be read in the array of parameters

    returns: void
```
```
void get_hex_value(char *param, word_t *value) 

    If param contains a string representation of an hexadecimal value, it will be parsed and placed into "value". If it contains the path to a file containing the value, the file is opened and the first 32 characters are read and parsed to fill the array. Only the first 32 characters will be read and the array is filled from the lowest byte toward the highest
 
    param: String containing the value in hexadecimal format or the path to the file containing the value value
    value: pointer to an allocated array in which to store the value

    returns: void
```
```
void parse_hex(char *param, word_t *value)

    Parses a textual input (in hex format LSB first) to an array of bytes. Example: 0x1234 --> [0x12, 0x34]
 
    param: pointer to the string hexadecimal number to be read
    value: pointer to the byte array to be filled

    returns: void
```
```
void print_hex_word(uint8_t *buffer, size_t num_bytes, FILE *output)

    Print the content of the buffer (LSB first) in hex format
 
    buffer: pointer to data to print
    num_bytes: number of bytes to print
    output: open file descriptor

    returns: void
```
```
void print_traces(uint8_t *traces, uint16_t num_traces, FILE *output)

    Parses and prints the content of the buffer in hex format and CSV as follows (header included):
    sensor, t_test_fail, t_test_valid_p, t_test_valid, aes_busy
 
    traces: pointer to data to print
    num_traces: number of traces to print (2B each)
    output: open file descriptor

    returns: void
```
```
void gen_random_word(word_t dst) 

    Generates a random 16-byte value that is placed in dst
 
    dst: allocated array in which to store the random value

    returns: void
```
```
int get_delim(char *arg) 

    Reads the arg string and determines whether it correspond to one of the predefined options for setting parameters
 
    arg: string of character to be read

    returns: -1 if args does not correspond to any option parameter, otherwise the index of the parameter in the static constant array DELIM
```
```
size_t get_number_of_masks(char *argv[], int offset, int argc)

    Reads the array of string argv to determine the number of values provided before the next type of parameter
 
    argv: array of string containing all the command's parameters
    offset: offset at which to start counting the parameter's value
    argc: total size of argv

    returns: The number hexa/path value in argv between 'offset' and the next option parameter
```
```
int parse_command(size_t argc_offset, int argc, char * argv[], data_full_t * data, files_t * files)

    Parses the array of command's parameters provided by the user and fills the files_t and data_full_t structures for the experiment. All necessary values that are provided by the user's input argv are filled with default values.
 
    argc_offset: index at which to start parsing elements in argv
    argc: size of argv
    argv: array of string containing the user's parameters input data
    data: structure to be filled with the user's input
    files: structure to be filled with the user's input

    returns: 0 on success, -1 on failure
```
```
int parse_config(const char *path_to_file, data_full_t *data, files_t *files)

    Parses the configuration file provided by the user and fills the files_t and data_full_t structures for the experiment. All necessary values that are not present in the config file are filled with default values.

    path_to_file: path to the configuration file
    data: structure to be filled with the user's input
    files: structure to be filled with the user's input

    returns: 0 on success, -1 on failure
```
```
int parse_command_modes(size_t argc_offset, int argc, char *argv[], config_t *conf, input_t *inputs, dumps_t *dumps)

    Parses the array of command's parameters provided by the user and fills the conf_t, input_t and dumps_t structures for the experiment. This function also parses the key mode, plaintext mode, number of traces and number of masks.

    argc_offset: index at which to start parsing elements in argv
    argc: size of argv
    argv: array of string containing the user's parameters input
    conf: structure to be filled with the user's input
    inputs: structure to be filled with the user's input
    dumps: structure to be filled with the file pointers of the output files

    returns: 0 on success, -1 on failure
```
```
int parse_command_no_val(size_t argc_offset, int argc, char *argv[], config_t *conf, input_t *inputs)

    Parses the array of command's parameters provided by the user and fills the conf_t, input_t structures for the experiment. This function also parses the key mode, plaintext mode, number of traces and number of masks but doesn't open the dump files not the tty device file. It also does not read provided values for the key, masks or plaintext. All necessary values that aren't provided by the user's input argv are filled with default values

    argc_offset: index at which to start parsing elements in argv
    argc: size of argv
    argv: array of string containing the user's parameters input
    conf: structure to be filled with the user's input
    inputs: structure to be filled with the user's input

    returns: 0 on success, -1 on failure
```
```
int parse_config_modes(const char *path_to_file, config_t *conf, input_t *inputs, dumps_t *dumps) 

    Parses the configuration file provided by the user and fills the files_t and data_full_t structures for the experiment. All necessary values that are not present in the config file are filled with default values.

    path_to_file: path to the configuration file
    conf: structure to be filled with the user's input
    inputs: structure to be filled with the user's input
    dumps: structure to be filled with the user's input 

    returns: 0 on success, -1 on failure
```
```
void finish_config(bool params_done[11], files_t *files, data_full_t *data)

    Completes the configuration if any required parameter hasn't been provided.
    Default key       : {0x61} (16B)
    Default plaintest : {0x61} (16B)
    Default tty       : /dev/ttyUSB1/

    params_done: array indicating the parameters status [uart, key, mask, plaintext, cipher, traces]
    files: pointer to the session's I/O files parameters structure
    data: pointer to the session's data structure

    returns: void
```
```
int finish_config_modes(bool params_done[11], config_t *conf, input_t *inputs, dumps_t *dumps)

    Completes the configuration if any required parameter hasn't been provided.
    Default key       : {0x61} (16B)
    Default plaintest : {0x61} (16B)
    Default tty       : /dev/ttyUSB1/

    params_done: array indicating the parameters status
    conf: pointer to the configuration data structure to be completed
    inputs: pointer to the inputs data structure to be completed
    output: pointer to the outputs data structure to be completed

    returns: 0 on success, -1 on failure
```
```
int finish_config_no_val(bool params_done[11], config_t *conf, input_t *inputs)

    Completes the configuration if any required parameter hasn't been provided. It does not set default values for the key, plaintext or masks and does not configure nor open the tty device file.
    Default tty       : /dev/ttyUSB1/
    Default key mode  : 0 (constant)
    Default plain mode: 0 (constant)
    Default num traces: 256*256*10
    Default dump path : ./dumps
    Default num masks : 0

    params_done: array indicating the parameters status
    conf: pointer to the configuration data structure to be completed
    inputs: pointer to the inputs data structure to be completed

    returns: 0 on success
```
```
void export_config(const char *path_to_config_file, files_t *files, data_full_t *data)

    Exports the experiment's config to a file. The format in which it is exported can be parsed by parse_config. The file will contain the hexadecimal values as well as the path to the files containing those inputs if any.

    path_to_config_file: path to the configuration file to be written
    files: structure containing the experiment's data to be exported
    data: structure containing the paths to the experiment's input/output files if any

    returns: void
```
```
int free_rsc(data_full_t *data, files_t *files)

    Frees all dynamically allocated buffers in data and closes all the files openend in files

    data: pointer to the structure to be freed
    files: pointer to the structure containing files to be closed

    returns: 0 on success, -1 on failure
```
```
void print_help() 

    prints the help message which explains all arguments and options

    returns: void
```
```
int print_config(config_t *config) 

    prints the current configuration stored in config

    config: struct that stores the configuration of the current experiment

    returns: 0 on success
```
```
int print_config2(config_t *config) 

    prints the current configuration stored in config

    config: struct that stores the configuration of the current experiment

    returns: 0 on success
```
```
int parse_args(int argc, char *argv[], config_t *config)

    function that parses the arguments in argv and stores the configuration in config

    argc: size of argv
    argv: array of string containing the user's parameters input
    config: struct in which the configuration is stored

    returns: 0 on success, 1 on failure
```
```
int init_config(config_t *config)

    initialize the struct config

    config: struct in which the configuration is stored

    returns: 0 on success, 1 on failure
```
```
int setup_aes(config_t *conf, input_t *inputs)

    set up the AES with the key and the masks

    conf: structure containing the file descriptor to the open tty device file
    inputs: structure containing the key, the number of masks and the masks, if any

    returns: 0 on success, 1 on failure
```
```
int encrypt_word(config_t *conf, input_t *inputs, output_t *outputs)

    sends the plaintext to the AES and reads the cipher

    conf: structure containing the file descriptor to the open tty device file
    inputs: structure containing the plaintext
    outputs: structure in which to store the cipher

    returns: 0 on success, 1 on failure
```
```
int dump_output(config_t *conf, output_t *outputs, dumps_t *dumps)

    Dumps the cipher and traces from outputs in the files opened in dumps. The cipher is dumped in binary value whereas the traces are printed as text, using hexadecimal representation.

    conf: structure containing the index of the current trace
    outputs: structure containing the cipher and traces data
    dumps: structure containing the opened file pointers to the dump files

    returns: 0 on success
```
```
int dump_input(input_t *inputs, dumps_t *dumps) 

    Dumps the key, masks and plaintext from inputs in the files opened in dumps. All data is dumped in binary values.

    inputs: structure containing the key, masks and plaintext
    dumps: structure containing the opened file pointers to the dump files
    
    returns: 0 on success
```
```
int set_key_w(int fd, uint8_t *key)

    sends the key to the AES device

    fd: file descriptor of the open and configured tty device file
    key: pointer to a 16 bytes array containing the key (MSB first)
    
    returns: 0 on success, 1 on failure
```
```
int set_mask_w(int fd, uint8_t *mask)

    sends the mask to the AES device

    fd: file descriptor of the open and configured tty device file
    mask: pointer to an array containing the mask
    
    returns: 0 on success, 1 on failure
```
```
int set_calibration(int fd, uint8_t *idc_idf)

    sends the calibration to the AES device

    fd: file descriptor of the open and configured tty device file
    idc_idf: pointer to an array containing the calibration for idc and idf
    
    returns: 0 on success, 1 on failure
```
```
int calibrate_sensor(int fd, uint8_t *plaintext, uint8_t *key, uint8_t *idc_idf) 

    automatically calibrates the sensor

    fd: file descriptor of the open and configured tty device file
    plaintext: pointer to a 16 bytes array containing the plaintext
    key: pointer to a 16 bytes array containing the key
    idc_idf: the final calibration of idc and idf is stored in this array
    
    returns: 0 on success
```
```
void set_idc(unsigned char idc_idf[16], int idc, int idf_width)

    The number of coarse elements that should be used for the calibration is given with the value in idc. The function converts this into the array idc_idf such that it has the correct format to be sent to the hardware.

    idc_idf: this array stores the calibration for idc and idf
    idc: the number of coarse elements that should be used for calibration
    idf_width: the total number of bytes that is occupied by idf; usually 12
    
    returns: void
```
```
void set_idf(unsigned char idc_idf[16], int idf)

    The number of fine elements that should be used for the calibration is given with the value in idf. The function converts this into the array idc_idf such that it has the correct format to be sent to the hardware.

    idc_idf: this array stores the calibration for idc and idf
    idf: the number of fine elements that should be used for calibration
    
    returns: void
```
```
int count_one(int x)

    calculates the hamming weight of the binary representation of x
    
    x: the value to calculate the hamming weight on
    
    returns: the hamming weight of the binary representation of x
```
```
int encrypt_w(int fd, uint8_t *input, uint8_t *cipher)

    sends the plaintext to the AES and reads the resulting cipher
    
    fd: file descriptor of the open and configured tty device file
    input: pointer to a 16 bytes array containing the plaintext (MSB first)
    cipher: pointer to an allocated 16 bytes array in which to store the cipher
    
    returns: 0 on success, 1 on failure
```
```
int read_trace_w(int fd, uint8_t *sensor_traces, uint8_t *signal_traces)

    reads the traces from the AES
    
    fd: file descriptor of the open and configured tty device file
    sensor_traces: pointer to an allocated array in which to store the sensor trace
    signal_trace: pointer to an allocated bytes array in which to store the signal trace (or temperature)
    
    returns: 0 on success, 1 on failure
```
```
int dump_sensor_trace(FILE *fp, uint8_t *sensor_trace, int last_line)

    Dump the sensor trace at the end of the file pointed by fp. Prints the value as a string representation of the hexadecimal value from the sensor.
    
    fp: file pointer to the open files in which to dump the values
    sensor_trace: array of bytes containing the sensor trace
    last_line: indicates if it is the last trace of this experiment

    returns: 0 on success, 1 on failure
```
```
int dump_signal_trace(FILE *fp, uint8_t *signal_trace, size_t offset, int last_line)

    Dump the sensor trace at the end of the file pointed by fp. Prints the value as a string binary character of the bit indicated by offset
    
    fp: file pointer to the open files in which to dump the values
    sensor_trace: array of bytes containing the sensor trace
    offset: offset of the desired bit in the trace samples; not used
    last_line: indicates if it is the last trace of this experiment

    returns: 0 on success, 1 on failure
```
```
int check_soft_encrypt(input_t *inputs, output_t *outputs, int sbox_en, int masked)

    Checks if the cipher returned by the AES is correct by computing it using a software implementation of the AES encryption.
    
    inputs: structure containing the key, plaintext and masks
    outputs: structure containing the cipher computed by the hardware AES
    sbox_en: if 1, the check is for a single s-box lookup, otherwise for an AES encryption
    masked: if sbox_en is 1 and masked is 1, the check is for a single masked s-box lookup, otherwise if masked is 0, it is for an unmasked s-box.

    returns: 0 on success, 1 on failure
```
```
int reset_loop(config_t *conf)

    Reset the AES. This "soft" reset is only taken into account by the AES if the controller's FSM is not in a state that is expecting data (key, masks, plaintext) from the host. In such a case, a hardware reset is necessary.
    
    conf: structure containing the file descriptor to the open tty device file

    returns: 0 on success, 1 on failure
```
</details>

<details>

<summary>main.c</summary>

```
void main(int argc, char* argv[])

    entry point to the program

    argc: length of the argument vector
    argv: array of character pointers

    returns: 0 on success, -1 on failure
```

</details>

# Sakura-X

<details>
<summary>aes_soft.c</summary>

```
void KeyExpansionCore (unsigned char* in, unsigned char i)

    performs a one-byte left circular shift, the AES S-box, and round constant as part of the AES key schedule

    in: number of terms in the series to sum
    i: round constant of the key expansion

    returns: void
``` 
```
void KeyExpansion(unsigned char* inputKey, unsigned char* expandedKeys)

    performs the AES key schedule to expand the inputKey into 11 separate round keys

    inputKey: AES master key
    expandedKeys: stores the 11 AES round keys 

    returns: void
``` 
```
void SubBytes(unsigned char* state)

    Substitutes bytes from the state with the values from the S-Box.

    state: The value on which the substitution should be performed.

    returns: void
``` 
```
void ShiftRows(unsigned char* state)

    Cyclically shifts the byte in each row by a certain offset.

    state: The values (16bytes) on which the shiftRows should be perfomed.

    returns: void
``` 
```
void MixColumns(unsigned char* state)

    This function multiplies the state with a special matrix.

    state: The values (16bytes) on which the shiftRows should be perfomed.

    returns: void
``` 
```
void AddRoundKey(unsigned char* state, unsigned char* roundKey)

    Performs the XOR of each byte in the state and the roundKey.

    state: The values (16bytes) on which the AddRoundKey should be perfomed.
    roundKey: The subkey of the corresponding round.

    returns: void
``` 
```
void AES_Encrypt(unsigned char* message, unsigned char* key)

    Performs the AES encryption on the message using the key.

    message: Plaintext that needs to be encrypted.
    key: The secret master key.

    returns: void
``` 
</details>

<details>
<summary>aes.c</summary>

```
int set_key(FT_HANDLE sasebo, unsigned char* key)

    send the the value key to the hardware

    sasebo: handle to the FPGA board (FTD2XX)
    key: 16-bytes value that is sent to the hardware

    returns: int indicating success (0) or failure (1)
```
```
int encdec(FT_HANDLE sasebo, int data)

    Set the encryption (0) or decryption mode (1) to the hardware

    sasebo: handle to the FPGA board (FTD2XX)
    data: value which specifies if an encryption or decryption should be performed

    returns: int indicating success (0) or failure (1)

```
```
int encrypt(FT_HANDLE sasebo, unsigned char* plaintext, unsigned char* cipher)

    send the plaintext to the hardware, trigger the encrpytion, and read the ciphertext

    sasebo: handle to the FPGA board (FTD2XX) 
    plaintext: plaintext that is sent to the hardware for the AES encryption
    cipher: the ciphertext that is read from the hardware

    returns: int indicating success (0) or failure (1)
```
```
void print_value(unsigned char* value, FILE* f)

    simple function that prints the 16-byte value, e.g., the key,  in hexadecimal

    value: 16-byte value that should be printed
    f: the file where the function writes to

    returns: void
```
```
int send_key(FT_HANDLE * handle, unsigned char* key)

    send the secret AES key to the hardware

    handle: handle to the FPGA board (FTD2XX)
    key: 16-bytes key that is sent to the hardware for the AES encryption

    returns: int indicating success (0) or failure (1)
```
```
int encrypt_data(FT_HANDLE * sasebo, unsigned char* plaintext, unsigned char* cipher)

    send the encrypt command to the hardware, followed by the plaintext

    sasebo: handle to the FPGA board (FTD2XX)
    plaintext:plaintext that is sent to the hardware for the AES encryption
    cipher: the ciphertext that is read from the hardware 

    returns: int indicating success (0) or failure (1)
```
```
FT_HANDLE* sasebo_reinit(FT_HANDLE* handle, int * trace, state_t * state, unsigned char *key, unsigned char *plain, unsigned char *cipher, unsigned char *cipher_chained)

    reinitializes the state of the program (key, plaintext, ciphertext, etc.) and the FPGA-host communication in case the FPGA-host communication persistently fails.

    handle: handle to the FPGA board (FTD2XX)
    trace: trace acquisition that failed
    state: state of the program
    key: key used
    plain: plaintext used
    cipher: ciphertext used
    cipher_chained: chained ciphertext used

    returns: FT_HANDLE
```
```
FT_HANDLE* sasebo_reinit_simple(FT_HANDLE* handle)

    soft reinitialization of the FPGA-host communication, only tries to reset the FPGA.

    handle: handle to the FPGA board (FTD2XX)

    returns: FT_HANDLE
```
```
int calibrate_sensor(FT_HANDLE * handle, calib_type_t calib, int registers, unsigned char idc_idf[16])

    calibrates the voltage-drop sensor either automatically in hardware (calib=0), manually by the user (calib=1), automatically in software (calib=3), or skips the calibration(calib=2)  

    handle: handle to the FPGA board (FTD2XX)
    calib: value indicating the type of calibration
    registers: the number of registers that the sensor consists of (often 128)
    idc_idf: array that specifies how many coarse elements (LUT) and how many fine elements (CARRY4) should be used in the manual calibration. First 12 bytes are for idf, last 4 bytes are for idc.

    returns: int indicating success (0) or failure (1)
```
```
int get_sensor_trace(FT_HANDLE * handle, int n_samples, int print, int store, unsigned char sensor_trace[][16])

    collect the sensor traces that were measured by the voltage-drop sensor

    handle: handle to the FPGA board (FTD2XX)
    n_samples: the number of samples per trace
    print: if set to 1, function prints every sensor sample
    store: if set to 1, stores every sensor sample in the sensor_trace array
    sensor_trace: stores the sensor traces, if store is set to 1

    returns: int indicating success (0) or failure (1)
```
```
void set_idc(unsigned char idc_idf[LEN_IDC_IDF], int idc, int idf_width)

    compute the value that has idc many leading 1s

    idc_idf: array that specifies how many coarse elements (LUT) and how many fine elements (CARRY4) should be used in the manual calibration. First 12 bytes are for idf, last 4 bytes are for idc. The computed value is stored in this array.
    idc: the value which indicates how many coarse elements (idc) should be used
    idf_width: the width of the idf; usually 12 bytes

    returns: void
```
```
void set_idf(unsigned char idc_idf[LEN_IDC_IDF], int idf)

    compute the value that has idf many leading 1s


    idc_idf: array that specifies how many coarse elements (LUT) and how many fine elements (CARRY4) should be used in the manual calibration. First 12 bytes are for idf, last 4 bytes are for idc. The computed value is stored in this array.
    idf: the value which indicates how many fine elements (idf) should be used

    returns: void
```
```
int count_one(int x)

    calculates the hamming weight of the binary representation of x

    x: value to do the computations on

    returns: int that indicates how many 1s are needed to represent the value x
```
```
int get_max_sample(unsigned char sample_trace[SAMPLES_PER_TRACE][LEN_SAMPLE], int registers_bytes)

    computes the value of the maximum sample in sample_trace

    sample_trace: the array which holds the samples
    register_bytes: the number of bytes one sample consists of; usually 16 bytes

    returns: int which is the value of the maximum sample in sample_trace
```
```
int get_min_sample(unsigned char sample_trace[SAMPLES_PER_TRACE][LEN_SAMPLE], int registers_bytes)

    computes the value of the minimum sample in sample_trace

    sample_trace: the array which holds the samples
    register_bytes: the number of bytes one sample consists of; usually 16 bytes

    returns: int which is the value of the minimum sample in sample_trace
```
```
int check_overflow_underflow(FT_HANDLE *handle, int registers_bytes, int max_hw, int delta, int N)

    check if any sample reaches the value max_hw or if any sample is smaller than delta

    handle: handle to the FPGA board (FTD2XX)
    register_bytes: the number of bytes one sample consists of; usually 16 bytes 
    max_hw: the maximum sample must not reach the value max_hw
    delta: the minimum sample must not be below delta 
    N: number of traces that should be collected

    returns: int that indicates if all samples were in the acceptable range (1), or if at least one sample violated the range (0).
```

</details>

<details>
<summary>ftdi_interface.c</summary>

```
int print_devices(FT_DEVICE_LIST_INFO_NODE* devices, unsigned int number)

    prints the informations about the device

    devices: the device whose information should be printed
    number: the number of devices

    returns: int indicating success (0) or failure (1)
```
```
int setup_device(int device, FT_HANDLE* handle)

    set up the devices and show the available devices to the user

    device: identifier of the device
    handle: handle to the FPGA board (FTD2XX)

    returns: int indicating success (0) or failure (1)
```
```
int ft_read(char* buffer, unsigned int length_req, FT_HANDLE handle)

    read from the device and store the data in buffer

    buffer: stores the data that has been read
    length_req: number of bytes that should be read
    handle: handle to the FPGA board (FTD2XX)

    returns: int indicating success (0) or failure (1)
```
```
int ft_write(char* buffer, unsigned int length_req, FT_HANDLE handle)

    write data to the device

    buffer: data that are written to the device
    length_req: number of bytes that should be written to the device 
    handle: handle to the FPGA board (FTD2XX)

    returns: int indicating success (0) or failure (1)
```
```
void close_device(FT_HANDLE handle)

    close the connection to the device

    handle: handle to the FPGA board (FTD2XX)

    returns: void
```
</details>

</details>

<details>
<summary>main.c</summary>

```
void main(int argc, char* argv[])

    entry point to the program

    argc: length of the argument vector
    argv: array of character pointers

    returns: 0 on success, -1 on failure
```
</details>


<details>
<summary>Sasebogii.c</summary>

```
FT_HANDLE* sasebo_init()

    initialize the device

    returns: handle
```
```
int sasebo_read(FT_HANDLE handle, char* buffer, size_t len, int addr)

    read data of length len from the device

    handle: handle to the FPGA board (FTD2XX)
    buffer: stores the data that has been read from the device
    len: the number of bytes that should be read from the device
    addr: the address to read from

    returns: int indicating success (0) or failure (1)
```
```
int sasebo_write(FT_HANDLE handle, char* buffer, size_t len, int addr)

    write data to the device

    handle: handle to the FPGA board (FTD2XX) 
    buffer: stores the data that should be written to the device
    len: the number of bytes that should be written to the device
    addr: the address to write to

    returns: int indicating success (0) or failure (1)
```
```
int sasebo_read_unit(FT_HANDLE handle, int addr)

    read a constant number of bytes from the 

    handle: handle to the FPGA board (FTD2XX)
    addr: the address to read from

    returns: int indicating success (0) or failure (1)
```
```
int sasebo_write_unit(FT_HANDLE handle, int addr, int data)

    write a constant number of bytes to the device

    handle: handle to the FPGA board (FTD2XX) 
    addr: the address to write to
    data: the data that should be written to the device

    returns: int indicating success (0) or failure (1)
```
```
int select_comp(FT_HANDLE handle)

    initialize the device

    handle: handle to the FPGA board (FTD2XX) 

    returns: int indicating success (0) or failure (1)
```
```
int sasebo_purge(FT_HANDLE handle)

    purge the device

    handle: handle to the FPGA board (FTD2XX) 

    returns: int indicating success (0) or failure (1)
```
```
void sasebo_close(FT_HANDLE* handle)

    close the connection to the device

    handle: handle to the FPGA board (FTD2XX) 

    returns: int indicating success (0) or failure (1)
```

</details>

<details>
<summary>utils.c</summary>

```
void print_help()

    print the help message with the arguments and options 

    returns: void
```
```
int parse_args(int argc, char* argv[], config_t* config)

    parse the arguments and save the configuration

    argc: length of the argument vector
    argv: array of character pointers
    config: struct that stores the configuration of the current experiment

    returns: int indicating success (0) or failure (1)
```
```
int init_config(config_t* config)

    initialize the config with default values

    config: struct that stores the configuration of the current experiment

    returns: int indicating success (0) or failure (1)
```
```
int print_config(config_t* config)

    print the details of the current configuration

    config: struct that stores the configuration of the current experiment

    returns: int indicating success (0) or failure (1)
```
```
void initialize_random(unsigned char array[16])

    fills the array with 16 random bytes

    array: array that should be filled with random bytes

    returns: void
```
```
void sbox_key_pt(int trace, unsigned char pt[16], unsigned char key[16])

    function that generates a sweep of all the possible key and plaintext values for an 8-bit sbox input

    trace: which iteration of the generation it is
    pt: previous plaintext
    key: previous key

    returns: void
```
```
unsigned char hamming_weight(unsigned char byte)

    compute the hamming weight of the argument byte

    byte: the hamming weight of this value is calculated

    returns: hamming weight of the argument byte
```

</details>

<details>
<summary>oscilloscope.c</summary>

```
int open_osc()

    compute the hamming weight of the argument byte

    byte: the hamming weight of this value is calculated

    returns: hamming weight of the argument byte
```
```
int setup_osc(int osc)

    setup the parameters for the data transfer

    osc: non-negative int that is an index to an entry in the process' table of open file descriptors

    returns: int (0) on success 
```
```
int read_osc(int osc, int id)

    read data from the the oscilloscope

    osc: non-negative int that is an index to an entry in the process' table of open file descriptors
    id: identifier used for the name of the csv file

    returns: int (0) on success
```
```
int get_id(int osc)

    get oscilloscope identification

    osc: non-negative int that is an index to an entry in the process' table of open file descriptors

    returns: int (0) on success 
```
```
int clear(int osc)

    reset the parameters

    osc: non-negative int that is an index to an entry in the process' table of open file descriptors

    returns: int (0) on success
```
```
int write_file(int osc, const char* message)

    transfer data to the oscilloscope

    osc: non-negative int that is an index to an entry in the process' table of open file descriptors
    message: data that should be transferred

    returns: int (0) on success
```
```
int get_Acq_param(int file)

    loads status data from oscilloscope

    file: oscilloscope USB file

    returns: int (0) on success
```
```
int init_osc()

    initialize the oscilloscope for communication

    returns: non-negative int that is an index to an entry in the process' table of open file descriptors
```
```
int start_reccording(int osc)

    start the recording of the oscilloscope

    osc: non-negative int that is an index to an entry in the process' table of open file descriptors

    returns: int (0) on success
```
```
int set_filename(char* s, int id, char* prefix)

    compute the hamming weight of the argument byte

    byte: the hamming weight of this value is calculated

    returns: hamming weight of the argument byte
```
```
int quick_save(int osc, int id, int precision, char file_path[300])

    read data from the oscilloscope and save the data. almost identical to the function trigger_save.

    osc: non-negative int that is an index to an entry in the process' table of open file descriptors
    id: identifier used for the name of the csv file
    precision: precision of the oscilloscope
    file_path: path to the file which saves the data

    returns: int (0) on success
```
```
int trigger_save(int osc, int id, int precision, char file_path[300])

    read data from the oscilloscope and save the data. almost identical to the function quick_save.

    osc: non-negative int that is an index to an entry in the process' table of open file descriptors
    id: identifier used for the name of the csv file
    precision: precision of the oscilloscope
    file_path: path to the file which saves the data

    returns: int (0) on success
```
</details>
