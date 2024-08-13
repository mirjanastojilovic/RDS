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

def compute_hw_trace(samples_list, sample_index):
    current_sample = samples_list[sample_index]
    sample_hw = 0
    for i in range(0,len(current_sample),2):
        current_byte = current_sample[i : i+2]
        current_byte = '0x' + current_byte
        sample_hw += bin(eval(current_byte))[2:].count('1')
    return sample_hw


if(input_file[-4:] == '.bin'):
    bin_file = open(input_file, 'rb')
if(input_file[-4:] == '.csv'):
    print("Converting sensor traces to hamming distance trace.")
    csv_file = open(input_file, 'r')


data_file = open(output_file, 'wb')
output = []
for i in range(0,int(sys.argv[2])):
    output = []
    line = csv_file.readline()
    if not line:
        break
    line = line.strip()
    mysamples = line.split(',')
    for j in range(0, int(sys.argv[3])):
        if(input_file[-4:] == '.bin'):
            a = int.from_bytes(bin_file.read(1), 'little')
        if(input_file[-4:] == '.csv'):
            a = compute_hw_trace(mysamples,j)
        output.append(a)
    float_array = array('f', output)
    float_array.tofile(data_file)

data_file.close()
if(input_file[-4:] == '.bin'):
    bin_file.close()
if(input_file[-4:] == '.csv'):
    csv_file.close()

