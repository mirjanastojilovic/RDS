#!/bin/bash

# RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
# Copyright 2023, School of Computer and Communication Sciences, EPFL.
#
# All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

OUT_PATH="./"
N_TRACES="2000000"

BITSTREAM_PATH_TDC = "../bitstreams/host/shell_v1/TDC/aes_sca.xclbin"

mkdir $OUT_PATH/key1
./host $BITSTREAM_PATH_TDC 1 256 128 32 0 $N_TRACES . $OUT_PATH/key1/ 7d266aecb153b4d5d6b171a58136605b 0 0 > $OUT_PATH/key1/out_key1.txt
mkdir $OUT_PATH/key2
./host $BITSTREAM_PATH_TDC 1 256 128 32 0 $N_TRACES . $OUT_PATH/key2/ e3fb107fa4aaeb7130f411d4c88dbf6c 0 0 > $OUT_PATH/key2/out_key2.txt
mkdir $OUT_PATH/key3
./host $BITSTREAM_PATH_TDC 1 256 128 32 0 $N_TRACES . $OUT_PATH/key3/ a89e2fd6926dc2478402b717631d08ce 0 0 > $OUT_PATH/key3/out_key3.txt
mkdir $OUT_PATH/key4
./host $BITSTREAM_PATH_TDC 1 256 128 32 0 $N_TRACES . $OUT_PATH/key4/ a3a03d60c06457dc65d8afd5815f629c 0 0 > $OUT_PATH/key4/out_key4.txt
mkdir $OUT_PATH/key5
./host $BITSTREAM_PATH_TDC 1 256 128 32 0 $N_TRACES . $OUT_PATH/key5/ e1055ac2abadea4fc7fc6be1310448d9 0 0 > $OUT_PATH/key5/out_key5.txt
