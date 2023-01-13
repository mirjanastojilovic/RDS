/*
 RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
 Copyright 2023, School of Computer and Communication Sciences, EPFL.

 All rights reserved. Use of this source code is governed by a
 BSD-style license that can be found in the LICENSE.md file. 
 */

#include "aes.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "utils.h"

int encdec(FT_HANDLE sasebo, int data) {
    printf("Encryption mode set to %d\n", data);
    if (sasebo_write_unit(sasebo, ADDR_MODE, data) == EXIT_FAILURE) {
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}

int set_key(FT_HANDLE sasebo, unsigned char* key) {
    if (key == NULL) {
        fprintf(stderr, "null key passed to set_key\n");
        return EXIT_FAILURE;
    }

    // write key to corresponding addr
    if (sasebo_write(sasebo, (char*)key, AES_SIZE, ADDR_KEY0) == EXIT_FAILURE) {
        return EXIT_FAILURE;
    }

    // execute key generation on HW
    if (sasebo_write_unit(sasebo, ADDR_CONT, 0x0002) == EXIT_FAILURE) {
        return EXIT_FAILURE;
    }

    // sleep(0.5); // probably useless

    // int ret;
    // while((ret = sasebo_read_unit(sasebo, ADDR_CONT)) != 0) { // wait for key
    // computations to be done
    //   printf("nop.. %d\n", ret);
    // }
    if (sasebo_read_unit(sasebo, ADDR_CONT) == EXIT_FAILURE) {
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}

int encrypt(FT_HANDLE sasebo, unsigned char* plaintext, unsigned char* cipher) {
    sleep(0.01);
    if (sasebo == NULL || plaintext == NULL || cipher == NULL) {
        fprintf(stderr, "null args to encrypt\n");
        return EXIT_FAILURE;
    }

    // write plaintext to cipher module
    if (sasebo_write(sasebo, (char*)plaintext, AES_SIZE, ADDR_ITEXT0) ==
        EXIT_FAILURE) {
        printf("sasebo write failed!\n");
        return EXIT_FAILURE;
    }

    // cipher processing
    if (sasebo_write_unit(sasebo, ADDR_CONT, 0x0001) == EXIT_FAILURE) {
        printf("sasebo write unit failed!\n");
        return EXIT_FAILURE;
    }

    // int ret;
    // while((ret = sasebo_read_unit(sasebo, ADDR_CONT)) != 0) { // wait for key
    // computations to be done
    //   printf("nop.. %d\n", ret);
    // }
    if (sasebo_read_unit(sasebo, ADDR_CONT) == EXIT_FAILURE) {
        printf("sasebo_read_unit failed\n");
        return EXIT_FAILURE;
    }

    // read encrypted ciphertext
    if (sasebo_read(sasebo, (char*)cipher, AES_SIZE, ADDR_OTEXT0) ==
        EXIT_FAILURE) {
        printf("sasebo_read failed!\n");
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}

void print_value(unsigned char* value, FILE* f) {
    // Print key
    printf("Key: ");
    for (int i = 0; i < 16; i++) {
        fprintf(f, "%02x ", (unsigned char)value[i]);
    }
    fprintf(f, "\n");
}

FT_HANDLE* sasebo_reinit(FT_HANDLE* handle, int* trace, state_t* state,
                         unsigned char* key, unsigned char* plain,
                         unsigned char* cipher, unsigned char* cipher_chained) {
    printf(
        "TRACE %d FAILED, READ ERROR. REESTABLISHING CONNECTION AND REPEATING "
        "TRACE...\n",
        *trace);

    // If read failed, close the handle
    sasebo_close(handle);

    // Open the device again
    if ((handle = sasebo_init()) == NULL) {
        return NULL;
    }

    // Setup the device
    if (select_comp(*handle) == EXIT_FAILURE) {
        sasebo_close(handle);
        return NULL;
    }

    // Set encryption mode
    if (encdec(*handle, MODE_ENC) == EXIT_FAILURE) {
        sasebo_close(handle);
        return NULL;
    }

    // Restore state
    memcpy(key, state->key, sizeof(state->key));
    memcpy(plain, state->plain, sizeof(state->plain));
    memcpy(cipher, state->cipher, sizeof(state->cipher));
    memcpy(cipher_chained, state->cipher_chained,
           sizeof(state->cipher_chained));

    // TEST
    sleep(10);

    return handle;
}

FT_HANDLE* sasebo_reinit_simple(FT_HANDLE* handle) {
    // Reset entire system
    sasebo_write_unit(*handle, ADDR_CONT, 0x0004);
    sasebo_write_unit(*handle, ADDR_CONT, 0x0000);

    // If read failed, close the handle
    sasebo_close(handle);

    // Open the device again
    if ((handle = sasebo_init()) == NULL) {
        return NULL;
    }

    sasebo_write_unit(*handle, ADDR_CONT, 0x0004);
    sasebo_write_unit(*handle, ADDR_CONT, 0x0000);

    // Setup the device
    // if(select_comp(*handle) == EXIT_FAILURE) {
    //  sasebo_close(handle);
    //  return NULL;
    //}

    // Set encryption mode
    if (encdec(*handle, MODE_ENC) == EXIT_FAILURE) {
        sasebo_close(handle);
        return NULL;
    }

    // TEST
    // sleep(10);

    return handle;
}

int send_key(FT_HANDLE* handle, unsigned char* key) {
    unsigned char cmd[16] = {0x00};

    // Set send key command
    cmd[15] = SET_KEY;
    if (set_key(*handle, cmd) == EXIT_FAILURE) {
        printf("Set key command failed!\n");
        return EXIT_FAILURE;
    }

    // Send key
    if (set_key(*handle, key) == EXIT_FAILURE) {
        printf("Send key failed!\n");
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}

int encrypt_data(FT_HANDLE* handle, unsigned char* plaintext,
                 unsigned char* cipher) {
    unsigned char cmd[16] = {0x00};

    // Set send encrypt command
    cmd[15] = ENCRYPT;
    if (set_key(*handle, cmd) == EXIT_FAILURE) {
        printf("Encrypt command failed!\n");
        return EXIT_FAILURE;
    }

    // Encrypt
    if (encrypt(*handle, plaintext, cipher) == EXIT_FAILURE) {
        printf("Encrypt failed!\n");
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}

int get_sensor_trace(FT_HANDLE* handle, int n_samples, int print, int store,
                     unsigned char sensor_trace[][16]) {
    unsigned char sensor_sample[16];
    unsigned char cmd[16] = {0x00};

    if (store == 1 && sensor_trace == NULL) {
        printf("Empty trace array passed!\n");
        return EXIT_FAILURE;
    }

    // Set read sensor command
    cmd[15] = READ_SENS;
    if (set_key(*handle, cmd) == EXIT_FAILURE) {
        printf("Sensor read command failed!\n");
        return EXIT_FAILURE;
    }

    // Read n_sample samples
    for (int sample = 0; sample < n_samples; sample++) {
        memset(sensor_sample, 0x00, sizeof(sensor_sample));

        // Write command to read sensor sample
        cmd[15] = READ_SAMPLE;
        if (encrypt(*handle, cmd, sensor_sample) == EXIT_FAILURE) {
            printf("Sensor sample collection failed\n");
            return EXIT_FAILURE;
        }
        // If print argument is set to 1, print every sensor sample
        if (print == 1) {
            for (int i = 0; i < 16; i++) {
                printf("%02x", sensor_sample[i]);
            }
            printf("\n");
        }
        // If store argument is set to 1, store every sensor sample in the input
        // array
        if (store == 1) {
            memcpy(sensor_trace[sample], sensor_sample, sizeof(sensor_sample));
        }
    }

    // Set command to end read
    cmd[15] = END_READ;
    if (encrypt(*handle, cmd, sensor_sample) == EXIT_FAILURE) {
        printf("End sensor read command failed\n");
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}

int calibrate_sensor(FT_HANDLE* handle, calib_type_t calib,
                     int registers, unsigned char idc_idf[16]) {
    unsigned char cmd[16] = {0x00};
    int best_idc = 0;
    int best_idf = 0;
    int idf = 0;
    int max_hw = registers;
    int idc = 0;
    int delta = 4;  // depends on registers! RDS: 32, HRDS: 4

    // use const and initialize global register
    if (idc_idf == NULL) {
        printf("Null IDC/IDF array!\n");
        return EXIT_FAILURE;
    }

start:;

    if (calib == MANUAL) {
        // Send calibration command
        cmd[15] = CALIB_MANUAL;
        if (set_key(*handle, cmd) == EXIT_FAILURE) {
            printf("Calibration command failed!\n");
            if ((handle = sasebo_reinit_simple(handle)) == NULL) {
                printf("Could not reinit device. EXIT\n");
                return EXIT_FAILURE;
            }
            goto start;
        }

        // Print IDC and IDF
        printf("Sensor IDF&IDC:\n");
        for (int i = 0; i < 16; i++) {
            printf("%02x", idc_idf[i]);
        }
        printf("\n");

        // Send IDC and IDF
        if (set_key(*handle, idc_idf) == EXIT_FAILURE) {
            printf("Calibration failed!\n");
            if ((handle = sasebo_reinit_simple(handle)) == NULL) {
                printf("Could not reinit device. EXIT\n");
                return EXIT_FAILURE;
            }
            goto start;
        }
    } else if (calib == AUTOMATIC_HW) {
        // Send calibration command
        cmd[15] = CALIB_AUTO;
        if (set_key(*handle, cmd) == EXIT_FAILURE) {
            printf("Calibration command failed!\n");
            if ((handle = sasebo_reinit_simple(handle)) == NULL) {
                printf("Could not reinit device. EXIT\n");
                return EXIT_FAILURE;
            }
            goto start;
        }

        if (encrypt(*handle, cmd, idc_idf) == EXIT_FAILURE) {
            printf("Automatic calibration failed!\n");
            if ((handle = sasebo_reinit_simple(handle)) == NULL) {
                printf("Could not reinit device. EXIT\n");
                return EXIT_FAILURE;
            }
            goto start;
        }

        // Print IDC and IDF
        printf("Sensor IDF&IDC retrieved from hardware:\n");
        for (int i = 0; i < 16; i++) {
            printf("%02x", idc_idf[i]);
        }
        printf("\n");

    } else if (calib == SKIP) {
        printf("Calibration mode SKIP: sensor calibration skipped. \n");
        return EXIT_SUCCESS;

    } else if (calib == AUTOMATIC_SW_IDC) {
        // initialize IDC_IDF to zero
        memset(idc_idf, 0, LEN_IDC_IDF);

        // Sensor sample may not occupy 16 bytes. If it occupies less
        // (register_bytes!=16), then the sensor sample is in the least
        // significant bytes of te sensor_trace array.
        int registers_bytes = registers / 8;

        for (; idc <= COARSE_WIDTH; ++idc) {
            set_idc(idc_idf, idc, 12);
            int max_hw_violated = FALSE;
            for (int i = 0; i < 10; ++i) {
                // Send calibration command
                cmd[15] = CALIB_MANUAL;
                if (set_key(*handle, cmd) == EXIT_FAILURE) {
                    printf("Calibration command failed!\n");
                    if ((handle = sasebo_reinit_simple(handle)) == NULL) {
                        printf("Could not reinit device. EXIT\n");
                        return EXIT_FAILURE;
                    }
                    goto start;
                }

                // Send IDC and IDF
                if (set_key(*handle, idc_idf) == EXIT_FAILURE) {
                    printf("Calibration failed!\n");
                    if ((handle = sasebo_reinit_simple(handle)) == NULL) {
                        printf("Could not reinit device. EXIT\n");
                        return EXIT_FAILURE;
                    }
                    goto start;
                }

                // get the trace in sensor_trace
                unsigned char sensor_trace[SAMPLES_PER_TRACE][LEN_SAMPLE] = {0};
                if (get_sensor_trace(handle, SAMPLES_PER_TRACE, 1, 1, sensor_trace) ==
                    EXIT_FAILURE) {
                    printf("Sensor read failed!\n");
                    if ((handle = sasebo_reinit_simple(handle)) == NULL) {
                        printf("Could not reinit device. EXIT\n");
                        return EXIT_FAILURE;
                    }
                    goto start;
                }
                if (get_min_sample(sensor_trace, registers_bytes) != max_hw) {
                    max_hw_violated = TRUE;
                    break;
                }
            }
            if (!max_hw_violated) {
                break;
            }
        }
        for (; idc <= COARSE_WIDTH; ++idc) {
            set_idc(idc_idf, idc, 12);

            // Send calibration command
            cmd[15] = CALIB_MANUAL;
            if (set_key(*handle, cmd) == EXIT_FAILURE) {
                printf("Calibration command failed!\n");
                if ((handle = sasebo_reinit_simple(handle)) == NULL) {
                    printf("Could not reinit device. EXIT\n");
                    return EXIT_FAILURE;
                }
                goto start;
            }

            // Send IDC and IDF
            if (set_key(*handle, idc_idf) == EXIT_FAILURE) {
                printf("Calibration failed!\n");
                if ((handle = sasebo_reinit_simple(handle)) == NULL) {
                    printf("Could not reinit device. EXIT\n");
                    return EXIT_FAILURE;
                }
                goto start;
            }

            int check = check_overflow_underflow(handle, registers_bytes,
                                                 max_hw, delta, 10);

            if (check) {
                best_idc = idc;
                break;
            }
        }

        printf("Best idc %d \n", idc);
        set_idc(idc_idf, best_idc, 12);

    } else if (calib == AUTOMATIC_SW) {
        // initialize IDC_IDF to zero
        memset(idc_idf, 0, LEN_IDC_IDF);

        // Sensor sample may not occupy 16 bytes. If it occupies less
        // (register_bytes!=16), then the sensor sample is in the least
        // significant bytes of te sensor_trace array.
        int registers_bytes = registers / 8;

        for (; idc <= COARSE_WIDTH; ++idc) {
            set_idc(idc_idf, idc, 12);
            int max_hw_violated = FALSE;
            for (int i = 0; i < 10; ++i) {
                // Send calibration command
                cmd[15] = CALIB_MANUAL;
                if (set_key(*handle, cmd) == EXIT_FAILURE) {
                    printf("Calibration command failed!\n");
                    if ((handle = sasebo_reinit_simple(handle)) == NULL) {
                        printf("Could not reinit device. EXIT\n");
                        return EXIT_FAILURE;
                    }
                    goto start;
                }

                // Send IDC and IDF
                if (set_key(*handle, idc_idf) == EXIT_FAILURE) {
                    printf("Calibration failed!\n");
                    if ((handle = sasebo_reinit_simple(handle)) == NULL) {
                        printf("Could not reinit device. EXIT\n");
                        return EXIT_FAILURE;
                    }
                    goto start;
                }

                // get the trace in sensor_trace
                unsigned char sensor_trace[SAMPLES_PER_TRACE][LEN_SAMPLE] = {0};
                if (get_sensor_trace(handle, SAMPLES_PER_TRACE, 1, 1, sensor_trace) ==
                    EXIT_FAILURE) {
                    printf("Sensor read failed!\n");
                    if ((handle = sasebo_reinit_simple(handle)) == NULL) {
                        printf("Could not reinit device. EXIT\n");
                        return EXIT_FAILURE;
                    }
                    goto start;
                }
                if (get_min_sample(sensor_trace, registers_bytes) != max_hw) {
                    max_hw_violated = TRUE;
                    break;
                }
            }
            if (!max_hw_violated) {
                break;
            }
        }
        int break_loop = FALSE;
        for (; idc <= COARSE_WIDTH; ++idc) {
            for (idf = 0; idf <= 4 * FINE_WIDTH; ++idf) {
                set_idc(idc_idf, idc, 12);
                set_idf(idc_idf, idf);

                // Send calibration command
                cmd[15] = CALIB_MANUAL;
                if (set_key(*handle, cmd) == EXIT_FAILURE) {
                    printf("Calibration command failed!\n");
                    if ((handle = sasebo_reinit_simple(handle)) == NULL) {
                        printf("Could not reinit device. EXIT\n");
                        return EXIT_FAILURE;
                    }
                    goto start;
                }

                // Send IDC and IDF
                if (set_key(*handle, idc_idf) == EXIT_FAILURE) {
                    printf("Calibration failed!\n");
                    if ((handle = sasebo_reinit_simple(handle)) == NULL) {
                        printf("Could not reinit device. EXIT\n");
                        return EXIT_FAILURE;
                    }
                    goto start;
                }
                int check = check_overflow_underflow(handle, registers_bytes,
                                                     max_hw, delta,10);
                if (check) {
                    best_idc = idc;
                    best_idf = idf;
                    break_loop = TRUE;
                    break;
                }
            }
            if (break_loop) {
                break;
            }
        }
        set_idc(idc_idf, best_idc, 12);
        set_idf(idc_idf, best_idf);
        printf("best idc %d \n", best_idc);
        printf("best idf %d \n", best_idf);
    } else {
        printf("Calibration mode unknown!\n");
        return EXIT_FAILURE;
    }
    // Send calibration command
    cmd[15] = CALIB_MANUAL;
    if (set_key(*handle, cmd) == EXIT_FAILURE) {
        printf("Calibration command failed!\n");
        if ((handle = sasebo_reinit_simple(handle)) == NULL) {
            printf("Could not reinit device. EXIT\n");
            return EXIT_FAILURE;
        }
        goto start;
    }

    // Send IDC and IDF
    if (set_key(*handle, idc_idf) == EXIT_FAILURE) {
        printf("Calibration failed!\n");
        if ((handle = sasebo_reinit_simple(handle)) == NULL) {
            printf("Could not reinit device. EXIT\n");
            return EXIT_FAILURE;
        }
        goto start;
    }
    // Print sensor trace for debugging purposes
    if (get_sensor_trace(handle, SAMPLES_PER_TRACE, 1, 0, NULL) == EXIT_FAILURE) {
        printf("Sensor read failed!\n");
        if ((handle = sasebo_reinit_simple(handle)) == NULL) {
            printf("Could not reinit device. EXIT\n");
            return EXIT_FAILURE;
        }
        goto start;
    }

    printf("Is the sensor calibrated?\n");
    return EXIT_SUCCESS;
}

void set_idc(unsigned char idc_idf[LEN_IDC_IDF], int idc, int idf_width) {
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

void set_idf(unsigned char idc_idf[LEN_IDC_IDF], int idf) {
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

int count_one(int x) {
    x = (x & (0x55555555)) + ((x >> 1) & (0x55555555));
    x = (x & (0x33333333)) + ((x >> 2) & (0x33333333));
    x = (x & (0x0f0f0f0f)) + ((x >> 4) & (0x0f0f0f0f));
    x = (x & (0x00ff00ff)) + ((x >> 8) & (0x00ff00ff));
    x = (x & (0x0000ffff)) + ((x >> 16) & (0x0000ffff));
    return x;
}

int get_max_sample(unsigned char sensor_trace[SAMPLES_PER_TRACE][LEN_SAMPLE],
                   int registers_bytes) {
    int max = 0;
    int current = 0;

    for (int j = 0; j < SAMPLES_PER_TRACE; ++j) {
        current = 0;
        for (int i = 0; i < registers_bytes; ++i) {
            current +=
                count_one((int)sensor_trace[j][i + (16 - registers_bytes)]);
        }
        if (max < current) {
            max = current;
        }
    }
    return max;
}
int get_min_sample(unsigned char sensor_trace[SAMPLES_PER_TRACE][LEN_SAMPLE],
                   int registers_bytes) {
    int min = registers_bytes * 8;
    int current = 0;
    for (int j = 0; j < SAMPLES_PER_TRACE; ++j) {
        current = 0;
        for (int i = 0; i < registers_bytes; ++i) {
            current +=
                count_one((int)sensor_trace[j][i + (16 - registers_bytes)]);
        }
        if (min > current) {
            min = current;
        }
    }
    return min;
}

int check_overflow_underflow(FT_HANDLE* handle, int registers_bytes, int max_hw,
                             int delta, int N) {
    unsigned char key[16] = {0};
    unsigned char plain[16] = {0};
    unsigned char cipher[16] = {0};
    unsigned char sensor_trace[SAMPLES_PER_TRACE][LEN_SAMPLE] = {0};

    for (int trace = 0; trace < N; trace++) {
        initialize_random(key);
        initialize_random(plain);

        // Write key into the AES core
        if (send_key(handle, key) == EXIT_FAILURE) {
            printf("Sending key failed\n");
            if ((handle = sasebo_reinit_simple(handle)) == NULL) {
                printf("Could not reinit device. EXIT\n");
                return EXIT_FAILURE;
            }
            trace--;
            continue;
        }

        // encrypt data
        if (encrypt_data(handle, plain, cipher) == EXIT_FAILURE) {
            printf("Encrypt failed\n");
            if ((handle = sasebo_reinit_simple(handle)) == NULL) {
                printf("Could not reinit device. EXIT\n");
                return EXIT_FAILURE;
            }
            trace--;
            continue;
        }
        if (get_sensor_trace(handle, SAMPLES_PER_TRACE, 0, 1, sensor_trace) ==
            EXIT_FAILURE) {
            printf("Encrypt failed\n");
            if ((handle = sasebo_reinit_simple(handle)) == NULL) {
                printf("Could not reinit device. EXIT\n");
                return EXIT_FAILURE;
            }
            trace--;
            continue;
        }
        // get the min sample of that trace
        int min = get_min_sample(sensor_trace, registers_bytes);
        // get the max sample of that trace
        int max = get_max_sample(sensor_trace, registers_bytes);
        if (min < delta) {
            return FALSE;
        }
        if (max == max_hw) {
            return FALSE;
        }
    }

    return TRUE;
}
