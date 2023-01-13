# RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks

This directory contains the design files corresponding to the TCHES'23 paper "RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks" by David Spielmann, Ognjen Glamočanin, and Mirjana Stojilović.

```
Overview:
│   │
│   └───README.md
│   │
│   └───LICENSE
│
└───alveo/
│   │
│   └───bitstreams/: Directory containing the bitstreams used for the experiments on the Alveo U200 Datacenter Card.
│   │
│   └───constraints/: Directory containing the constraints for RDS and TDC sensors.
│   │
│   └───rtl/: Directory containing the hardware files needed to create the project of the Alveo U200 Datacenter Card.
│   │
│   └───soft/: Directory containing all the software files need to collect the power traces on the Alveo U200 Datacenter Card.
│   │
│   └───tcl/: Directory containing the files that automatically create the project in Vivado by using the files from hw/.
│
└───basys3/
│   │
│   └───bitstream/: Directory containing the bitstream used for the temperature experiments on the Digilent Basys 3 board.
│   │
│   └───create_project_AES50MHz_SENSOR200MHz.tcl: TCL file that automatically creates the project in Vivado.
│   │
│   └───hw/: Directory containing all the hardware files needed to create the project of the Digilent Basys 3 board.
│   │
│   └───sw/: Directory containing the software files needed to collect the power traces on the Digilent Basys 3 board.
│
└───sakura_x
    │
    └───bitstreams/: Directory containing all the bitstreams used on the Sakura-X board. The type of the sensor is specified by the name of the folder. The placement of the sensor and the AES is specified in the name of the bitstream.
    │
    └───hw/: Directory containing all the hardware files needed to create the project on the Sakura-X board.
    │    │
    │    └───tcl/: Directory containing the TCL scripts to automatically set up a project in Vivado with the desired on-chip sensor.
    │
    └───sw/: Directory containing the software files needed to collect the power traces on the Sakura-X board.

```

## Alveo U200 Datacenter Card

The RDS sensor implementation file is located in: `alveo/rtl/sensor/sensor_RDS.vhd`.

Follow these steps to collect power traces on the Alveo U200 Datacenter Card. The Alveo U200 experiments were built and run on Ubuntu 20.04.

### Generating the bitstream (optional)

1. Install Vitis/Vivado and XRT library
    * Experiments done on Vitis 2021.1, XRT library 2.11.634 (2021.1); with bitstreams in `bitstreams/host/shell_v1/`
    * Also works with Vitis 2022.1, XRT library 2.13.466 (2022.1); bitstreams in `bitstreams/host/shell_v2/`
2. In `hardware/fpga/tcl`, run `make impl_tdc` to generate the TDC bitstream
3. In `hardware/fpga/tcl`, run `make impl_rds` to generate the RDS bitstream
4. Bitstream will be generated in `hardware/fpga/tcl/bin`

### Running the experiments

5. In `soft/`, run `make`
6. For a single experiment, run the host command:
    * `./host <path_to_bitstream>/aes_sca.xclbin <number_of_sensors: only 1 supported> <number_of_samples> <sensor_width> <IDC_size> <IDF_size: max 32> <number_of_traces: max 96> <calibration_file_path> <output_path> <AES_key> <calibration_type: 0 automatic TDC, 1 automatic RDS, 2 from file> <temperature: 0 for not recording temperature, 1 for recording temperature>`
7. To run TDC experiments for multiple keys:
    * `./regression_TDC.sh`
8. To run RDS experiments for multiple keys:
    * `./regression_RDS.sh`
9. To run repeated experiments for both RDS and TDC for multiple keys:
    * `./regression_all.sh`

### Generated files

10. Each run generates five files:
    * `traces_encoded.bin`, containing `N_TRACES` traces, each with `N\_SAMPLES` `uint8_t` values, stored in binary format
    * `traces_raw.bin`, containing `N_TRACES` traces, each with `N\_SAMPLES` hex values of `SENSOR_WIDTH` bits, representing the non-encoded output of the delay line, stored in binary format
    * `ciphertexts.bin`, containing one 16-byte value per trace, in binary format, stored in the same order as the power traces, representing the ciphertexts of the traces
    * `keys.bin`, containing one 16-byte value per trace, in binary format, stored in the same order as the power traces, representing the keys of the traces
    * `temperatures.csv`, containing temperature information recorded every 100000 traces
    * In case of a regression, these files are stored in separate folders for each key, and each experiment repetition


## Sakura-X Side-Channel Evaluation Board

The RDS sensor implementation file is located in: `sakura_x/hw/sources/RDS/sensor.vhd`.

Follow these steps to collect power traces on the Sakura-X board. The Sakura-X experiments were built and run on Ubuntu 20.04.

### Bitstream Generation (optional) and Trace Acquisition

1. Install Vivado and the D2XX driver for the FTDI chip on the Sakura-X board
    * Experiments done on Vivado 2018.3, and using version 1.4.24 of the libftd2xx driver
2. Start Vivado 2018.3. When Vivado is started, a TCL command-line interface appears in the lower part of the GUI. Use this TCL command-line interface to change the directory:
   ```bash
      cd sakura_x/hw/tcl
   ```
3. Give a name to your project as follows:
   ```bash
      set project_name <your_project_name>
   ```
4. Choose your desired sensor and execute the corresponding TCL script, e.g.,
   ```bash
      source create_vivado_project_rds.tcl
   ```
5. Vivado automatically creates the project. To implement the design, hit the `Run Implementation` button.
6. Click on the `Generate Bitstream` button to generate the bitstream of the implementation.
7. Program the control FPGA of the Sakura-X board with the bitstream `sakura_x/bitstreams/ctrl/sasebo_giii_ctrl_20MHz.bit`.
8. Program the cryptographic FPGA with the bitstream that has been generated in point 5.
9. Compile the software part in the directory `sakura_x/sw/sakura_x_interface` by typing `make`.
10. Change to the following directory: `sakura_x/sw/sakura_x_interface/Debug` and execute the two scripts:
    * `setupFTD.sh`
    * `unload_sio.sh`
11. The software comes along with a help message. Display the help message by typing `./FTDexamplesAES -help`. The help message describes all the arguments needed to collect the power traces. For example, for the experiments in Section 6.1, the following command was used:
    `./FTDexampleAES -k 2 -uk 7d266aecb153b4d5d6b171a58136605b -pm 1 -t 100000 -d traces/experiment_6_1 -c 4 -s 128 -r 128`.

## Digilent Basys 3 Board

The RDS sensor implementation file is located in: `basys3/hw/rtl/sensor/sensor.vhd`.

Follow these steps to collect power traces on the Digilent Basys 3 board. The Basys 3 experiments were built and run on Ubuntu 20.04.

### Bitstream Generation (optional) and Trace Acquisition

1. Install Vivado, add Basys 3 board files to the Vivado installation directory, and install the USB cable drivers
    * Experiments done on Vivado 2018.3, using the cable driver from the Vivado installation path
2. Start Vivado 2018.3. When Vivado is started, a TCL command-line interface appears in the lower part of the GUI. Use this TCL command-line interface to change the directory:
   ```bash
      cd basys3
   ```
3. Give a name to your project as follows:
   ```bash
      set project_name <your_project_name>
   ```
4. Execute the TCL script by typing `source create_project_AES50MHz_SENSOR200MHz.tcl`.
5. Vivado automatically creates a project which implements the RDS sensor. To implement the design, hit the `Run Implementation` button.
6. Click on the `Generate Bitstream` button to generate the bitstream of the implementation.
7. Program the FPGA with the bistream that has been generated in point 5.
8. Compile the software part in the directory `basys3/sw` by typing `make`.
9. Change to the directory `basys3/sw/bin`. The software comes along with a help message. Display the help message by typing `./interface -help`. The help message describes all the arguments needed to collect the power traces. For example, for the experiments in Section 6.5, the following command was used: `./interface -k 0 -pt 1 -t 70000 -s -d traces/experiment_6_5 `.
