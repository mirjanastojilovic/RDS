#!/bin/bash

# RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
# Copyright 2023, School of Computer and Communication Sciences, EPFL.
#
# All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.



N_TRACES="2000000"

OUT_PATH="./"

mkdir -p $OUT_PATH/RDS

for VERSION in 1 2 3 4
do

  mkdir -p $OUT_PATH/RDS/v$VERSION/key1
  ./host ../bitstreams/host/shell_v1/RDS/aes_sca.xclbin 1 256 128 32 96 $N_TRACES . $OUT_PATH/v$VERSION/key1/ 7d266aecb153b4d5d6b171a58136605b 1 0 > $OUT_PATH/v$VERSION/key1/out_key1.txt
  mkdir -p $OUT_PATH/RDS/v$VERSION/key2
  ./host ../bitstreams/host/shell_v1/RDS/aes_sca.xclbin 1 256 128 32 96 $N_TRACES . $OUT_PATH/v$VERSION/key2/ e3fb107fa4aaeb7130f411d4c88dbf6c 1 0 > $OUT_PATH/v$VERSION/key2/out_key2.txt
  mkdir -p $OUT_PATH/RDS/v$VERSION/key3
  ./host ../bitstreams/host/shell_v1/RDS/aes_sca.xclbin 1 256 128 32 96 $N_TRACES . $OUT_PATH/v$VERSION/key3/ a89e2fd6926dc2478402b717631d08ce 1 0 > $OUT_PATH/v$VERSION/key3/out_key3.txt
  mkdir -p $OUT_PATH/RDS/v$VERSION/key4
  ./host ../bitstreams/host/shell_v1/RDS/aes_sca.xclbin 1 256 128 32 96 $N_TRACES . $OUT_PATH/v$VERSION/key4/ a3a03d60c06457dc65d8afd5815f629c 1 0 > $OUT_PATH/v$VERSION/key4/out_key4.txt
  mkdir -p $OUT_PATH/RDS/v$VERSION/key5
  ./host ../bitstreams/host/shell_v1/RDS/aes_sca.xclbin 1 256 128 32 96 $N_TRACES . $OUT_PATH/v$VERSION/key5/ e1055ac2abadea4fc7fc6be1310448d9 1 0 > $OUT_PATH/v$VERSION/key5/out_key5.txt

done

mkdir -p $OUT_PATH/RDS

for VERSION in 1 2 3 4
do

  mkdir -p $OUT_PATH/TDC/v$VERSION/key1
  ./host ../bitstreams/host/shell_v1/TDC/aes_sca.xclbin 1 256 128 32 0 $N_TRACES . $OUT_PATH/v$VERSION/key1/ 7d266aecb153b4d5d6b171a58136605b 0 0 > $OUT_PATH/v$VERSION/key1/out_key1.txt
  mkdir -p $OUT_PATH/TDC/v$VERSION/key2
  ./host ../bitstreams/host/shell_v1/TDC/aes_sca.xclbin 1 256 128 32 0 $N_TRACES . $OUT_PATH/v$VERSION/key2/ e3fb107fa4aaeb7130f411d4c88dbf6c 0 0 > $OUT_PATH/v$VERSION/key2/out_key2.txt
  mkdir -p $OUT_PATH/TDC/v$VERSION/key3
  ./host ../bitstreams/host/shell_v1/TDC/aes_sca.xclbin 1 256 128 32 0 $N_TRACES . $OUT_PATH/v$VERSION/key3/ a89e2fd6926dc2478402b717631d08ce 0 0 > $OUT_PATH/v$VERSION/key3/out_key3.txt
  mkdir -p $OUT_PATH/TDC/v$VERSION/key4
  ./host ../bitstreams/host/shell_v1/TDC/aes_sca.xclbin 1 256 128 32 0 $N_TRACES . $OUT_PATH/v$VERSION/key4/ a3a03d60c06457dc65d8afd5815f629c 0 0 > $OUT_PATH/v$VERSION/key4/out_key4.txt
  mkdir -p $OUT_PATH/TDC/v$VERSION/key5
  ./host ../bitstreams/host/shell_v1/TDC/aes_sca.xclbin 1 256 128 32 0 $N_TRACES . $OUT_PATH/v$VERSION/key5/ e1055ac2abadea4fc7fc6be1310448d9 0 0 > $OUT_PATH/v$VERSION/key5/out_key5.txt

done
