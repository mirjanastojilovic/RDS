/*
 RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
 Copyright 2023, School of Computer and Communication Sciences, EPFL.

 All rights reserved. Use of this source code is governed by a
 BSD-style license that can be found in the LICENSE.md file. 
 */

#include "host.hpp"

unsigned char hamming_weight(uint32_t data) {
    unsigned char weight = 0;

    for (int i = 0; i < (8 * sizeof(data)); i++) {
        weight += (data & (1 << i)) >> i;
    }

    return weight;
}

int count_one(int x) {
    x = (x & (0x55555555)) + ((x >> 1) & (0x55555555));
    x = (x & (0x33333333)) + ((x >> 2) & (0x33333333));
    x = (x & (0x0f0f0f0f)) + ((x >> 4) & (0x0f0f0f0f));
    x = (x & (0x00ff00ff)) + ((x >> 8) & (0x00ff00ff));
    x = (x & (0x0000ffff)) + ((x >> 16) & (0x0000ffff));
    return x;
}

int get_min_sample(uint32_t *hbuf, int N_SAMPLES, int SENSOR_WIDTH) {
    int min = SENSOR_WIDTH * 8;
    int current = 0;
    for (int j = 0; j < N_SAMPLES; ++j) {
        current = 0;
        for (int i = 0; i < SENSOR_WIDTH / 8; ++i) {
            current += count_one((int)hbuf[j * 16 + i]);
        }
        if (min > current) {
            min = current;
        }
    }
    return min;
}

int get_max_sample(uint32_t *hbuf, int N_SAMPLES, int SENSOR_WIDTH) {
    int max = 0;
    int current = 0;

    for (int j = 0; j < N_SAMPLES; ++j) {
        current = 0;
        for (int i = 0; i < SENSOR_WIDTH / 8; ++i) {
            current += count_one((int)hbuf[j * 16 + i]);
        }
        if (max < current) {
            max = current;
        }
    }
    return max;
}

uint32_t *pack_idc_idf(uint32_t *idc_idf, int idc, int idf, int IDC_SIZE,
                       int IDF_SIZE) {
    // CHECK IF THIS IS OK IN ALL CASES!!!!!!!!!!!!
    for (int i = 0; i < (IDC_SIZE + IDF_SIZE) / 32; i++) {
        idc_idf[i] = 0;
    }

    for (int i = 0; i < int(idf / 32); i++) {
        idc_idf[i] = 0xffffffff;
    }
    idc_idf[int(idf / 32)] = 0;
    for (int i = 0; i < (idf % 32); i++) {
        idc_idf[int(idf / 32)] = 0x80000000 | (idc_idf[int(idf / 32)] >> 1);
    }

    for (int i = IDF_SIZE / 32; i < IDF_SIZE / 32 + int(idc / 32); i++) {
        idc_idf[i] = 0xffffffff;
    }
    idc_idf[IDF_SIZE / 32 + int(idc / 32)] = 0;
    for (int i = 0; i < (idc % 32); i++) {
        idc_idf[IDF_SIZE / 32 + int(idc / 32)] =
            0x80000000 | (idc_idf[IDF_SIZE / 32 + int(idc / 32)] >> 1);
    }

    return idc_idf;
}

void uint8_to_uint32(uint8_t *input, uint32_t *output) {
    for (int chunk = 0; chunk < 4; chunk++) {
        output[chunk] = 0;
        for (int byte = 0; byte < 4; byte++) {
            output[chunk] =
                output[chunk] | (input[chunk * 4 + byte] << (3 - byte) * 8);
        }
    }

    return;
}

void uint32_to_uint8(uint32_t *input, uint8_t *output) {
    for (int chunk = 0; chunk < 4; chunk++) {
        for (int byte = 0; byte < 4; byte++) {
            output[chunk * 4 + byte] = (input[chunk] >> (3 - byte) * 8) & 0xff;
        }
    }

    return;
}

void aes_encrypt(xrt::ip kernel, uint8_t *key, uint8_t *plaintext,
                 uint8_t *ciphertext) {
    uint32_t *key_32 = (uint32_t *)malloc(4 * sizeof(uint32_t));
    uint32_t *pt_32 = (uint32_t *)malloc(4 * sizeof(uint32_t));
    uint32_t *ct_32 = (uint32_t *)malloc(4 * sizeof(uint32_t));

    uint8_to_uint32(key, key_32);
    uint8_to_uint32(plaintext, pt_32);
    uint8_to_uint32(ciphertext, ct_32);

    // Reset system
    //DEBUG_PRINT(("************************************************\n"));
    //DEBUG_PRINT(("RESET AES...\n"));
    //DEBUG_PRINT(("\tWriting data: %08x to address: %08x\n", 0x00, RST_ADDR));
    //kernel.write_register(RST_ADDR, 0x00);

    // STORE KEY
    DEBUG_PRINT(("************************************************\n"));
    DEBUG_PRINT(("STORE AES KEY...\n"));
    for (int chunk = 0; chunk < 4; chunk++) {
        DEBUG_PRINT(("\tWriting data: %08x to address: %08x\n", key_32[chunk],
               KEY_BASE_ADDR + 4 * (3 - chunk)));
        kernel.write_register(KEY_BASE_ADDR + 4 * (3 - chunk), key_32[chunk]);
    }

    // SET KEY
    DEBUG_PRINT(("************************************************\n"));
    DEBUG_PRINT(("SET AES KEY...\n"));
    DEBUG_PRINT(("\tWriting data: %08x to address: %08x\n", 0x00, SET_AES_KEY_ADDR));
    kernel.write_register(SET_AES_KEY_ADDR, 0x00);

    // SET PT
    DEBUG_PRINT(("************************************************\n"));
    DEBUG_PRINT(("SET AES PLAINTEXT...\n"));
    for (int chunk = 0; chunk < 4; chunk++) {
        DEBUG_PRINT(("\tWriting data: %08x to address: %08x\n", pt_32[chunk],
               PLAINTEXT_BASE_ADDR + 4 * (3 - chunk)));
        kernel.write_register(PLAINTEXT_BASE_ADDR + 4 * (3 - chunk),
                              pt_32[chunk]);
    }

    // Start CPU execution
    DEBUG_PRINT(("************************************************\n"));
    DEBUG_PRINT(("START AES ENCRYPTION...\n"));
    DEBUG_PRINT(("\tWriting data: %08x to address: %08x\n", 0x00, START_EXEC_ADDR));
    kernel.write_register(START_EXEC_ADDR, 0x00);

    uint32_t resp;

    // Wait until the trace is recorded
    do {
        resp = kernel.read_register(STATUS_REG_ADDR);
    } while ((resp & TRACE_DUMP_IDLE_MASK) != TRACE_DONE_IDLE_MASK);

    // READ CT
    DEBUG_PRINT(("************************************************\n"));
    DEBUG_PRINT(("READ CIPHERTEXT...\n"));
    for (int chunk = 0; chunk < 4; chunk++) {
        DEBUG_PRINT(("\tReading data from address %08x:",
               CIPHERTEXT_ADDR + 4 * (3 - chunk)));
        ct_32[chunk] = kernel.read_register(CIPHERTEXT_ADDR + 4 * (3 - chunk));
        DEBUG_PRINT(("%08X\n", ct_32[chunk]));
    }

    uint32_to_uint8(ct_32, ciphertext);

    free(key_32);
    free(pt_32);
    free(ct_32);

    return;
}

void save_trace(xrt::bo buffer, uint32_t *hbuf, int N_SAMPLES, int SENSOR_WIDTH,
                FILE *traces_bin, FILE *traces_raw) {
    // Read trace from DRAM
    buffer.sync(XCL_BO_SYNC_BO_FROM_DEVICE);

    unsigned char sensor_trace[N_SAMPLES];
    uint32_t sensor_trace_raw[N_SAMPLES*((int)SENSOR_WIDTH / 32)];

    for (int sample = 0; sample < N_SAMPLES; sample++) {
        sensor_trace[sample] = 0;
        for (int chunk = 0; chunk < (int)SENSOR_WIDTH / 32; chunk++) {
            sensor_trace[sample] += hamming_weight(hbuf[sample * 16 + chunk]);
            sensor_trace_raw[((int)SENSOR_WIDTH / 32)*sample+chunk] = hbuf[sample * 16 + chunk];
        }
    }
    fwrite(sensor_trace, sizeof(sensor_trace[0]), N_SAMPLES, traces_bin);
    fwrite(sensor_trace_raw, sizeof(sensor_trace_raw[0]), N_SAMPLES*((int)SENSOR_WIDTH / 32), traces_raw);

    return;
}

void save_ciphertext(uint8_t *ciphertext, FILE *ciphertext_f) {
    fwrite(ciphertext, sizeof(ciphertext[0]), 16, ciphertext_f);
}

void save_key(uint8_t *key, FILE *key_f) {
    fwrite(key, sizeof(key[0]), 16, key_f);
}

void init_system(xrt::ip kernel, xrt::bo buffer) {
    // Reset system
    DEBUG_PRINT(("************************************************\n"));
    DEBUG_PRINT(("RESET SYSTEM...\n"));
    DEBUG_PRINT(("\tWriting data: %08x to address: %08x\n", RST_ADDR, 0x00));
    kernel.write_register(RST_ADDR, 0x00);

    // Set DRAM pointer
    DEBUG_PRINT(("************************************************\n"));
    DEBUG_PRINT(("SET DRAM DUMP POINTER...\n"));
    uint32_t payload = buffer.address();
    DEBUG_PRINT(("\tWriting data: %08x to address: %08x\n", payload,
           DUMP_PTR_BASE_ADDR));
    kernel.write_register(DUMP_PTR_BASE_ADDR, payload);
    payload = buffer.address() >> 32;
    DEBUG_PRINT(("\tWriting data: %08x to address: %08x\n", payload,
           DUMP_PTR_BASE_ADDR + 4));
    kernel.write_register(DUMP_PTR_BASE_ADDR + 4, payload);

    return;
}

void send_calibration(xrt::ip kernel, xrt::bo buffer, uint32_t *hbuf,
                                 uint32_t **idc_idf, int N_SENSORS,
                                 int IDC_SIZE, int IDF_SIZE) {
    int init_delay_size = IDC_SIZE + IDF_SIZE;

    for (int sensor = 0; sensor < N_SENSORS; sensor++) {
        for (int chunk = 0; chunk < init_delay_size / 32; chunk++) {
            if (chunk == 0)
                printf("SEND IDC...\n");
            else
                printf("SEND IDF...\n");
            // idc_idf[0-X] is IDF but addr[0] is IDC so invert these two
            printf("\tWriting data: %08x to address: %08x\n",
                   idc_idf[sensor][init_delay_size / 32 - 1 - chunk],
                   CALIB_REG_BASE_ADDR + 4 * chunk);
            kernel.write_register(
                CALIB_REG_BASE_ADDR + 4 * chunk,
                idc_idf[sensor][init_delay_size / 32 - 1 - chunk]);
        }
        // Calibrate sensor
        printf("\tWriting data: %08x to address: %08x\n", sensor,
               CALIB_TRG_ADDR);
        kernel.write_register(CALIB_TRG_ADDR, sensor);
    }
}


void calibrate_sensors_from_file(xrt::ip kernel, xrt::bo buffer, uint32_t *hbuf,
                                 int N_SENSORS,
                                 int IDC_SIZE, int IDF_SIZE, char* CALIB_PATH) {
    // Load calibration data from file
    char file_path[10000];
    sprintf(file_path, "%s", CALIB_PATH);
    FILE * idc_idf_file;
    idc_idf_file = fopen(file_path, "rb");
    if(idc_idf_file == NULL) {
      printf("ERROR IN OPENING IDC IDF BIN FILE\n");
      printf("%s\n", file_path);
      return;
    }

    int init_delay_size = IDC_SIZE + IDF_SIZE;

    uint32_t ** idc_idf = (uint32_t **)malloc(N_SENSORS*sizeof(uint32_t *));
    for(int sensor = 0; sensor<N_SENSORS; sensor++){
      idc_idf[sensor] = (uint32_t *)malloc((init_delay_size)/32*sizeof(uint32_t));
      fread(idc_idf[sensor], sizeof(uint32_t), (init_delay_size)/32, idc_idf_file);
    }

    for (int sensor = 0; sensor < N_SENSORS; sensor++) {
        for (int chunk = 0; chunk < init_delay_size / 32; chunk++) {
            if (chunk == 0)
                printf("SEND IDC...\n");
            else
                printf("SEND IDF...\n");
            // idc_idf[0-X] is IDF but addr[0] is IDC so invert these two
            printf("\tWriting data: %08x to address: %08x\n",
                   idc_idf[sensor][init_delay_size / 32 - 1 - chunk],
                   CALIB_REG_BASE_ADDR + 4 * chunk);
            kernel.write_register(
                CALIB_REG_BASE_ADDR + 4 * chunk,
                idc_idf[sensor][init_delay_size / 32 - 1 - chunk]);
        }
        // Calibrate sensor
        printf("\tWriting data: %08x to address: %08x\n", sensor,
               CALIB_TRG_ADDR);
        kernel.write_register(CALIB_TRG_ADDR, sensor);
    }
    fclose(idc_idf_file);
}

void calibrate(xrt::ip kernel, xrt::bo buffer, uint32_t *hbuf,
               char calib_file_name[100], int N_SENSORS, int N_SAMPLES,
               int IDC_SIZE, int IDF_SIZE, int calib, int SENSOR_WIDTH, FILE* idc_idf_f) {
    uint32_t **idc_idf = (uint32_t **)malloc(N_SENSORS * sizeof(uint32_t *));
    for (int sensor = 0; sensor < N_SENSORS; sensor++) {
        idc_idf[sensor] =
            (uint32_t *)malloc((IDC_SIZE + IDF_SIZE) / 32 * sizeof(uint32_t));
    }
    int idc = 0;
    for (idc; idc <= IDC_SIZE; idc++) {
        pack_idc_idf(idc_idf[0], idc, 0, IDC_SIZE, IDF_SIZE);

        // Calibrate sensors
        printf("************************************************\n");
        printf("CALIBRATE SENSORS...\n");

        send_calibration(kernel, buffer, hbuf, idc_idf, N_SENSORS,
                                    IDC_SIZE, IDF_SIZE);

        bool max_hw_violated = false;
        for (int i = 0; i < 10; i++) {
            // Trigger the recording of the calibration traces
            printf("TRIGGER TRACE RECORDING!...\n");
            printf("\tWriting data: %08x to address: %08x\n", 0x50000000,
                   CALIB_TRACE_TRG_ADDR);
            kernel.write_register(CALIB_TRACE_TRG_ADDR, 0x50000000);

            // Wait until the trace is recorded and stored in DRAM
            uint32_t resp;
            do {
                resp = kernel.read_register(STATUS_REG_ADDR);
            } while ((resp & CALIB_DUMP_IDLE_MASK) != CALIB_DUMP_IDLE_MASK);

            // Read trace from DRAM
            buffer.sync(XCL_BO_SYNC_BO_FROM_DEVICE);

            for (int sample = 0; sample < N_SAMPLES; sample++) {
                // Print sample of a trace
                printf("Sample %d:\n", sample);
                printf("0x");
                for (int offset = 15; offset >= 0; offset--) {
                    printf("%08x|", hbuf[sample * 16 + offset]);
                }
                printf("\n");
            }
            int min_sample = get_min_sample(hbuf, N_SAMPLES, SENSOR_WIDTH);

            if (min_sample != SENSOR_WIDTH) {
                max_hw_violated = true;
                break;
            }
        }
        if (!max_hw_violated) {
            break;
        }
    }

    for (idc; idc <= IDC_SIZE; idc++) {
        pack_idc_idf(idc_idf[0], idc, 0, IDC_SIZE, IDF_SIZE);
        // Calibrate sensors
        printf("************************************************\n");
        printf("CALIBRATE SENSORS...\n");

        send_calibration(kernel, buffer, hbuf, idc_idf, N_SENSORS,
                                    IDC_SIZE, IDF_SIZE);

        int violated = false;
        for (int i = 0; i < 10; i++) {
            // Trigger the recording of the calibration traces
            printf("TRIGGER TRACE RECORDING!...\n");
            printf("\tWriting data: %08x to address: %08x\n", 0x50000000,
                   CALIB_TRACE_TRG_ADDR);
            kernel.write_register(CALIB_TRACE_TRG_ADDR, 0x50000000);

            // Wait until the trace is recorded and stored in DRAM
            uint32_t resp;
            do {
                resp = kernel.read_register(STATUS_REG_ADDR);
            } while ((resp & CALIB_DUMP_IDLE_MASK) != CALIB_DUMP_IDLE_MASK);

            // Read trace from DRAM
            buffer.sync(XCL_BO_SYNC_BO_FROM_DEVICE);

            for (int sample = 0; sample < N_SAMPLES; sample++) {
                // Print sample of a trace
                printf("Sample %d:\n", sample);
                printf("0x");
                for (int offset = 15; offset >= 0; offset--) {
                    printf("%08x|", hbuf[sample * 16 + offset]);
                }
                printf("\n");
            }

            int min = get_min_sample(hbuf, N_SAMPLES, SENSOR_WIDTH);
            int max = get_max_sample(hbuf, N_SAMPLES, SENSOR_WIDTH);
            if (min < 32) {
                violated = true;
                break;
            }
            if (max == SENSOR_WIDTH) {
                violated = true;
                break;
            }
        }
        if (!violated) {
            break;
        }
    }

    for (int sensor = 0; sensor < N_SENSORS; sensor++) {
        printf("IDC = %08x\n", idc_idf[sensor][(IDC_SIZE + IDF_SIZE) / 32 - 1]);
        printf("IDF = %08x%08x%08x\n", 
                idc_idf[sensor][(IDC_SIZE + IDF_SIZE) / 32 - 1 - 3],
                idc_idf[sensor][(IDC_SIZE + IDF_SIZE) / 32 - 1 - 2],
                idc_idf[sensor][(IDC_SIZE + IDF_SIZE) / 32 - 1 - 1]);
        fwrite(idc_idf[sensor], sizeof(idc_idf[sensor][0]), (IDC_SIZE+IDF_SIZE)/32, idc_idf_f);
        free(idc_idf[sensor]);
    }
    free(idc_idf);

    return;
}

void calibrate_idc_idf(xrt::ip kernel, xrt::bo buffer, uint32_t *hbuf,
                       char calib_file_name[100], int N_SENSORS, int N_SAMPLES,
                       int IDC_SIZE, int IDF_SIZE, int calib,
                       int SENSOR_WIDTH, FILE* idc_idf_f) {
    uint32_t **idc_idf = (uint32_t **)malloc(N_SENSORS * sizeof(uint32_t *));
    for (int sensor = 0; sensor < N_SENSORS; sensor++) {
        idc_idf[sensor] =
            (uint32_t *)malloc((IDC_SIZE + IDF_SIZE) / 32 * sizeof(uint32_t));
    }
    int idc = 0;
    for (idc; idc <= IDC_SIZE; idc++) {
        pack_idc_idf(idc_idf[0], idc, 0, IDC_SIZE, IDF_SIZE);

        // Calibrate sensors
        printf("************************************************\n");
        printf("CALIBRATE SENSORS...\n");

        send_calibration(kernel, buffer, hbuf, idc_idf, N_SENSORS,
                                    IDC_SIZE, IDF_SIZE);

        bool max_hw_violated = false;
        for (int i = 0; i < 10; i++) {
            // Trigger the recording of the calibration traces
            printf("TRIGGER TRACE RECORDING!...\n");
            printf("\tWriting data: %08x to address: %08x\n", 0x50000000,
                   CALIB_TRACE_TRG_ADDR);
            kernel.write_register(CALIB_TRACE_TRG_ADDR, 0x50000000);

            // Wait until the trace is recorded and stored in DRAM
            uint32_t resp;
            do {
                resp = kernel.read_register(STATUS_REG_ADDR);
            } while ((resp & CALIB_DUMP_IDLE_MASK) != CALIB_DUMP_IDLE_MASK);

            // Read trace from DRAM
            buffer.sync(XCL_BO_SYNC_BO_FROM_DEVICE);

            for (int sample = 0; sample < N_SAMPLES; sample++) {
                // Print sample of a trace
                printf("Sample %d:\n", sample);
                printf("0x");
                for (int offset = 15; offset >= 0; offset--) {
                    printf("%08x|", hbuf[sample * 16 + offset]);
                }
                printf("\n");
            }
            int min_sample = get_min_sample(hbuf, N_SAMPLES, SENSOR_WIDTH);

            if (min_sample != SENSOR_WIDTH) {
                max_hw_violated = true;
                break;
            }
        }
        if (!max_hw_violated) {
            break;
        }
    }

    int break_idc_loop = false;
    for (idc; idc <= IDC_SIZE; idc++) {
        for (int idf = 0; idf < IDF_SIZE; idf++) {
            pack_idc_idf(idc_idf[0], idc, idf, IDC_SIZE, IDF_SIZE);
            // Calibrate sensors
            printf("************************************************\n");
            printf("CALIBRATE SENSORS...\n");

            send_calibration(kernel, buffer, hbuf, idc_idf,
                                        N_SENSORS, IDC_SIZE, IDF_SIZE);

            int violated = false;
            for (int i = 0; i < 10; i++) {
                // Trigger the recording of the calibration traces
                printf("TRIGGER TRACE RECORDING!...\n");
                printf("\tWriting data: %08x to address: %08x\n", 0x50000000,
                       CALIB_TRACE_TRG_ADDR);
                kernel.write_register(CALIB_TRACE_TRG_ADDR, 0x50000000);

                // Wait until the trace is recorded and stored in DRAM
                uint32_t resp;
                do {
                    resp = kernel.read_register(STATUS_REG_ADDR);
                } while ((resp & CALIB_DUMP_IDLE_MASK) != CALIB_DUMP_IDLE_MASK);

                // Read trace from DRAM
                buffer.sync(XCL_BO_SYNC_BO_FROM_DEVICE);

                for (int sample = 0; sample < N_SAMPLES; sample++) {
                    // Print sample of a trace
                    printf("Sample %d:\n", sample);
                    printf("0x");
                    for (int offset = 15; offset >= 0; offset--) {
                        printf("%08x|", hbuf[sample * 16 + offset]);
                    }
                    printf("\n");
                }

                int min = get_min_sample(hbuf, N_SAMPLES, SENSOR_WIDTH);
                int max = get_max_sample(hbuf, N_SAMPLES, SENSOR_WIDTH);
                if (min < 32) {
                    violated = true;
                    break;
                }
                if (max >= (SENSOR_WIDTH-20)) {
                    violated = true;
                    break;
                }
            }
            if (!violated) {
                break_idc_loop = true;
                break;
            }
        }
        if(break_idc_loop){
            break;
        }
    }

    for (int sensor = 0; sensor < N_SENSORS; sensor++) {
        printf("IDC = %08x\n", idc_idf[sensor][(IDC_SIZE + IDF_SIZE) / 32 - 1]);
        printf("IDF = %08x%08x%08x\n", 
                idc_idf[sensor][(IDC_SIZE + IDF_SIZE) / 32 - 1 - 3],
                idc_idf[sensor][(IDC_SIZE + IDF_SIZE) / 32 - 1 - 2],
                idc_idf[sensor][(IDC_SIZE + IDF_SIZE) / 32 - 1 - 1]);
        fwrite(idc_idf[sensor], sizeof(idc_idf[sensor][0]), (IDC_SIZE+IDF_SIZE)/32, idc_idf_f);
        free(idc_idf[sensor]);
    }
    free(idc_idf);

    return;
}

void save_temperature(FILE * temperature_f, int trace){

  int status = system("xbutil examine -d 0000:01:00.1 --report thermal > tmp.txt");

  char line[256];
  int line_no = 0;
  int temp[5];
  int i=0;
  char temperature[3];

  time_t rawtime;
  struct tm * timeinfo;

  time(&rawtime);
  timeinfo = localtime(&rawtime);

  FILE * temp_file = fopen("tmp.txt", "r");
  if(temp_file == NULL){
    printf("ERROR IN OPENING TEMP TEMPERATURE FILE");
    return;
  }

  while(fgets(line, sizeof(line), temp_file)){
    if(line_no>5 && line_no<11){
      temperature[0] = line[31];
      temperature[1] = line[32];
      temperature[3] = '\0';
      temp[i] = atoi(temperature);
      i++;
    }
    line_no++;
  }

  char * time_string = asctime(timeinfo);
  time_string[strlen(time_string)-1] = 0;
  fprintf(temperature_f, "%d,", trace);
  fprintf(temperature_f, "%s,", time_string);
  fprintf(temperature_f, "%d,", temp[0]);
  fprintf(temperature_f, "%d,", temp[1]);
  fprintf(temperature_f, "%d,", temp[2]);
  fprintf(temperature_f, "%d,", temp[3]);
  fprintf(temperature_f, "%d\n", temp[4]);

  fclose(temp_file);
  return;

}

