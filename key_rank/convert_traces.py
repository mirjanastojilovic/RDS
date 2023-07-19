# RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
# Copyright 2023, School of Computer and Communication Sciences, EPFL.
#
# All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file. 

from array import array
import sys
import os

if(len(sys.argv) != 4):
    print("Not enough arguments: python3 convert_traces.py /path/to/file.bin n_traces n_samples")
    exit()

input_file = sys.argv[1]
output_file = os.path.splitext(input_file)[0]+".data" 

print("Converting "+input_file+" to "+output_file+"...")

bin_file = open(input_file, 'rb')
data_file = open(output_file, 'wb')
output = []
for i in range(0,int(sys.argv[2])):
    output = []
    for j in range(0, int(sys.argv[3])):
        a = int.from_bytes(bin_file.read(1), 'little')
        output.append(a)
    float_array = array('f', output)
    float_array.tofile(data_file)
data_file.close()
bin_file.close()
