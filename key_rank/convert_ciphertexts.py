# RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
# Copyright 2023, School of Computer and Communication Sciences, EPFL.
#
# All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file. 

import sys
import os

if(len(sys.argv) != 3):
    print("Not enough arguments: python3 convert_ciphertexts.py /path/to/file.bin n_traces")
    exit()

input_file = sys.argv[1]
output_file = os.path.splitext(input_file)[0]+".txt" 

print("Converting "+input_file+" to "+output_file+"...")

bin_file = open(input_file, 'rb')
text_file = open(output_file, 'w')
for i in range(0,int(sys.argv[2])):
    for j in range(0, 16):
        text_file.write(str(bin_file.read(1).hex().upper()))
        text_file.write(' ')
    text_file.write('\n')
text_file.close()
bin_file.close()
