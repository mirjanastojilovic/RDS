# RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
# Copyright 2023, School of Computer and Communication Sciences, EPFL.
#
# All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file. 

import argparse
import os.path
import subprocess
import os

# Parse all arguments
parser = argparse.ArgumentParser(description='\n==================================================\nCPA Key Rank Estimation Attack\n\n==================================================\n\nShort summary:\n\t- This program takes the power consumption traces, ciphertexts, and the last round key and computes the log2 key rank estimation metric using CPA.\n\t- The ouput of this program are the upper and lower bounds of the log2(key rank) metric, in a .csv file.\n', formatter_class=argparse.RawTextHelpFormatter );
parser.add_argument("-k",  "--key",              help="Last round key of 16 bytes, in hexadecimal value.\nExample: -k e07f16bdb9e50346a2277cd382774270", required=True)
parser.add_argument("-t",  "--trace_file",       help="Path to trace file.\nExample: -t /home/user/documents/data/traces.bin", required=True)#default=”default path”
parser.add_argument("-c",  "--ciphertexts_file", help="Path to ciphertext file.\nExample: -c /home/user/documents/data/ciphertexts.bin\n", required=True)
parser.add_argument("-nt", "--n_traces",         help="Number of traces (encryptions) in the trace file.\nExample: -nt 10000", required=True)
parser.add_argument("-ns", "--n_samples",        help="Number of sampler per trace (trace length).\nExample: -ns 128", required=True)
parser.add_argument("-ss", "--step_size",        help="Step size for the attacks.\nExample: -ss 1000", required=True)
parser.add_argument("-o",  "--output_path",      help="Path to output directory.\nExample: -o /home/user/documents/data/results/", required=True)

args = parser.parse_args()

if not (os.path.exists('out')):
    os.makedirs('out')
if not (os.path.exists('out/final_kr')):
    os.makedirs('out/final_kr')
f = open('out/log.txt', "w")
f_err = open('out/log_errors.txt', "w")

print("Attack configuration:")
print("* Key: "+args.key)
print("* Trace file: "+args.trace_file)
print("* Ciphertext file: "+args.ciphertexts_file)
print("* Number of traces: "+args.n_traces)
print("* Number of trace samples: "+args.n_samples)
print("* Attack step size: "+args.step_size)
print("* Output path: "+args.output_path)

# Perform checks
if not (os.path.exists(args.trace_file)):
    print("Trace file ("+args.trace_file+") does not exist!")
    f.write("Trace file ("+args.trace_file+") does not exist!\n")
    exit()
if not (os.path.exists(args.ciphertexts_file)):
    print("Ciphertexts file ("+args.ciphertexts_file+") does not exist!")
    f.write("Ciphertexts file ("+args.ciphertexts_file+") does not exist!\n")
    exit()
if not (os.path.exists(args.output_path)):
    print("Output directory ("+args.output_path+") does not exist!")
    f.write("Output directory ("+args.output_path+") does not exist!\n")
    exit()

f.flush()

# Transform binary trace file (where each sample is a uint8_t) to .data file
print("----------------------------------------------------------")
f.write("----------------------------------------------------------\n")
print("Converting trace file to appropriate format...")
f.write("Converting trace file to appropriate format...\n")

command = 'python3 convert_traces.py '+args.trace_file+' '+args.n_traces+' '+args.n_samples
print(command)
f.write(command+"\n")
f.flush()
process = subprocess.call(command.split(), stdout=f, stderr=f_err)
f_err.flush()
f.flush()

# Transform binary ciphertext file (where each ciphertext is 16 uint8_t values) to .txt file
print("----------------------------------------------------------")
f.write("----------------------------------------------------------\n")
print("Converting ciphertext file to appropriate format...")
f.write("Converting ciphertext file to appropriate format...\n")

command = 'python3 convert_ciphertexts.py '+args.ciphertexts_file+' '+args.n_traces
print(command)
f.write(command+"\n")
f.flush()
process = subprocess.call(command.split(), stdout=f, stderr=f_err)
f_err.flush()
f.flush()

# Compile attack
print("----------------------------------------------------------")
f.write("----------------------------------------------------------\n")
print("Compiling CPA key rank estimation attack...")
f.write("Compiling CPA key rank estimation attack...\n")

command = 'make'
print(command)
f.write(command+"\n")
f.flush()
process = subprocess.call(command.split(), stdout=f, stderr=f_err)
f_err.flush()
f.flush()

# Launch attack
print("----------------------------------------------------------")
f.write("----------------------------------------------------------\n")
print("Launching CPA key rank estimation attack...")
f.write("Launching CPA key rank estimation attack...\n")

command = ('./main-CPA' +
           ' -k '  + args.key +
           ' -t '  + os.path.splitext(args.trace_file)[0]+".data" +
           ' -c '  + os.path.splitext(args.ciphertexts_file)[0]+".txt" +
           ' -nt ' + args.n_traces +
           ' -ns ' + args.n_samples +
           ' -ss ' + args.step_size +
           ' -o  ' + 'out/')
print(command)
f.write(command+"\n")
f.flush()
process = subprocess.call(command.split(), stdout=f, stderr=f_err)
f_err.flush()
f.flush()

# Create key rank upper and lower bounds
print("----------------------------------------------------------")
f.write("----------------------------------------------------------\n")
print("Creating CPA key rank estimation upper and lower bounds...")
f.write("Creating CPA key rank estimation upper and lower bounds...\n")

command = 'python3 calculate_keyrank.py '+args.key+' '+args.step_size+' '+args.n_traces+' out/' 
print(command)
f.write(command+"\n")
f.flush()
process = subprocess.call(command.split(), stdout=f, stderr=f_err)
f_err.flush()
f.flush()

# Move results to output directory
print("----------------------------------------------------------")
f.write("----------------------------------------------------------\n")
print("Moving results to destination folder...")
f.write("Moving results to destination folder...\n")

command = 'mv out/* '+args.output_path+"/"
print(command)
f.write(command+"\n")
f.flush()
process = subprocess.call(command, shell=True, stdout=f, stderr=f_err)
f_err.flush()
f.flush()

f.close()
f_err.close()
