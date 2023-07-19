/*
 RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
 Copyright 2023, School of Computer and Communication Sciences, EPFL.

 All rights reserved. Use of this source code is governed by a
 BSD-style license that can be found in the LICENSE.md file. 
 */

#include "host.hpp"

#include "utils.hpp"

//#define DEBUG 0

int main(int argc, char *argv[]) {
    // Parse the command line arguments
    if (argc != 13) {
        std::cerr << "usage: " << argv[0]
                  << " XCLBIN N_SENSORS N_SAMPLES SENSOR_WIDTH IDC_SIZE "
                     "IDF_SIZE N_TRACES CALIB_PATH OUT_PATH KEY CALIB TEMPERATURE"
                  << std::endl;
        printf("Error\n");
        std::exit(-1);
    }

    int N_SENSORS = atoi(argv[2]);
    int N_SAMPLES = atoi(argv[3]);
    int SENSOR_WIDTH = atoi(argv[4]);
    int IDC_SIZE = atoi(argv[5]);
    int IDF_SIZE = atoi(argv[6]);
    int N_TRACES = atoi(argv[7]);
    char *CALIB_PATH = argv[8];
    char *OUT_PATH = argv[9];

    // read key from command line
    const char *src = argv[10];
    char cmd_buffer[16];
    uint8_t key[16];
    char *dst = cmd_buffer;
    char *end = cmd_buffer + sizeof(cmd_buffer);
    unsigned int u;
    int counter = 0;
    while (dst < end && sscanf(src, "%2x", &u) == 1) {
        *dst++ = u;
        src += 2;
        counter++;
    }
    memcpy(key, cmd_buffer, sizeof(cmd_buffer));

    // calibration mode: 0 for TDC, 1 for RDS, 2 from file
    int calib = atoi(argv[11]);

    int TEMPERATURE = atoi(argv[12]);

    char file_path[10000];

    FILE *traces_bin;
    FILE *traces_raw_bin;
    FILE *ciphertext_f;
    FILE *key_f;
    FILE *idc_idf_f;
    FILE * temperature_f;

    // Create the device
    auto dev = xrt::device(0);

    // Load dummy verification bistream and program the FPGA with it, to force
    // the the subsequent programming of the real bitstream
    auto xclbin = dev.load_xclbin("../../bitstreams/host/shell_v1/verify.xclbin");

    // load the binary into the memory
    xclbin = dev.load_xclbin(argv[1]);

    // wait_for_enter("\nPress ENTER to continue after setting up ILA
    // trigger...\n");

    auto kernel = xrt::ip(dev, xclbin, "AES_SCA_kernel");

    // args: device, size in bytes, dram bank
    auto buffer = xrt::bo(dev, N_SAMPLES * 64, 1);
    // buffers are also little-endian
    uint32_t *hbuf = buffer.map<uint32_t *>();

    init_system(kernel, buffer);

    sprintf(file_path, "%s/idc_idf.bin", OUT_PATH);
    idc_idf_f = fopen(file_path, "w");
    if (idc_idf_f == NULL) {
        printf("ERROR IN OPENING IDC IDF FILE\n");
        printf("%s\n", file_path);
        return 0;
    }

    // TDC calibration
    if (calib == 0) {
        calibrate_tdc(kernel, buffer, hbuf, file_path, N_SENSORS, N_SAMPLES,
                  IDC_SIZE, IDF_SIZE, calib, SENSOR_WIDTH, idc_idf_f);
    // RDS calibration
    } else if (calib == 1) {
        calibrate_rds(kernel, buffer, hbuf, file_path, N_SENSORS, N_SAMPLES,
                          IDC_SIZE, IDF_SIZE, calib, SENSOR_WIDTH, idc_idf_f);
    // Calibration from file
    } else {
      calibrate_from_file(kernel, buffer, hbuf, N_SENSORS, IDC_SIZE, IDF_SIZE, CALIB_PATH); 
    }

    fclose(idc_idf_f);

    // we always start from the 0 plaintext
    uint8_t plaintext[16] = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                             0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
    uint8_t ciphertext[16];

    sprintf(file_path, "%s/traces_encoded.bin", OUT_PATH);
    traces_bin = fopen(file_path, "w");
    if (traces_bin == NULL) {
        printf("ERROR IN OPENING BINARY TRACES FILE\n");
        printf("%s\n", file_path);
        return 0;
    }

    sprintf(file_path, "%s/traces_raw.bin", OUT_PATH);
    traces_raw_bin = fopen(file_path, "w");
    if (traces_raw_bin == NULL) {
        printf("ERROR IN OPENING BINARY TRACES FILE\n");
        printf("%s\n", file_path);
        return 0;
    }

    sprintf(file_path, "%s/ciphertexts.bin", OUT_PATH);
    ciphertext_f = fopen(file_path, "w");
    if (ciphertext_f == NULL) {
        printf("ERROR IN OPENING BINARY TRACES FILE\n");
        printf("%s\n", file_path);
        return 0;
    }

    sprintf(file_path, "%s/keys.bin", OUT_PATH);
    key_f = fopen(file_path, "w");
    if (key_f == NULL) {
        printf("ERROR IN OPENING BINARY TRACES FILE\n");
        printf("%s\n", file_path);
        return 0;
    }

    if(TEMPERATURE==1) {
        // Open the temperature file
        sprintf(file_path, "%s/temperature.csv", OUT_PATH);
        temperature_f = fopen(file_path, "w");
        if(temperature_f == NULL) {
            printf("ERROR IN OPENING TEMPERATURE FILE\n");
            printf("%s\n", file_path);
            return 0;
        }
        fprintf(temperature_f, "trace,date,PCB_top_front,PCB_top_rear,PCB_bottom_front,FPGA,Int_VCC\n");
    }

    for (int trace = 0; trace < N_TRACES; trace++) {
        // Run AES encryption
        aes_encrypt(kernel, key, plaintext, ciphertext);
        printf("Trace %d\n", trace);
        printf("KEY: 0x");
        for (int i = 0; i < 16; i++) printf("%02x", key[i]);
        printf("\n");
        printf("PT : 0x");
        for (int i = 0; i < 16; i++) printf("%02x", plaintext[i]);
        printf("\n");
        printf("CT : 0x");
        for (int i = 0; i < 16; i++) printf("%02x", ciphertext[i]);
        printf("\n");
        save_trace(buffer, hbuf, N_SAMPLES, SENSOR_WIDTH, traces_bin, traces_raw_bin);
        if(TEMPERATURE==1 && ((trace % 100000) == 0)) {
            // Save temperature
            save_temperature(temperature_f, trace);
        }
        save_ciphertext(ciphertext, ciphertext_f);
        save_key(key, key_f);
        memcpy(plaintext, ciphertext, 16 * sizeof(ciphertext[0]));
    }

    fclose(traces_bin);
    fclose(traces_raw_bin);
    fclose(ciphertext_f);
    fclose(key_f);
    if(TEMPERATURE==1)
        fclose(temperature_f);

    return 0;
}
