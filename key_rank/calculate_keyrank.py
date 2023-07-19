# RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
# Copyright 2023, School of Computer and Communication Sciences, EPFL.
#
# All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file. 

import numpy as np
import pandas as pd
import sys
from decimal import *
import math

if(len(sys.argv) != 5):
    print("Not enough arguments: python3 calculate_keyrank.py key step_size n_traces /path/to/results/")
    exit()

KEY_1 = bytes.fromhex(sys.argv[1])
STEPSIZE = int(sys.argv[2])
STEP_START = STEPSIZE
STEP_END = int(sys.argv[3])
n_bins = 256
DIRECTORY_PATH = sys.argv[4] 
KEY_2 = [0xe0, 0x7f,0x16, 0xbd, 0xb9, 0xe5, 0x03, 0x46, 0xa2, 0x27, 0x7c, 0xd3, 0x82, 0x77, 0x42, 0x70]

def convolve(A,B):
    A_len = len(A)
    B_len = len(B)
    out = (A_len + B_len) * [0]
    for i in range(A_len + B_len-1):
        out[i] = 0
        startk = 0
        endk = 0
        if i >= A_len:
            startk = i - A_len + 1
        else:
            startk = 0
        if i < B_len:
            endk = i
        else:
            endk = B_len - 1
        for k in range(startk, endk+1):
            out[i] = out[i] + A[i-k] * B[k]
    return out
        

def keyrank(): 

    steps = []
    lower = []
    upper = []

    for sample in range(STEP_START, STEP_END+1, STEPSIZE):
        M = np.loadtxt(DIRECTORY_PATH + '/final_kr/'+ str(sample) + '.txt', delimiter=',')
        num_rows, num_cols = M.shape
        sum_M = M.sum(axis=0)
        sum_M = np.tile(sum_M, (num_rows, 1))
        M = np.divide(M, sum_M)
        M = np.log2(M)
        hist1, bin_edges1 = np.histogram(M[:,0], bins=n_bins)
        hist2, bin_edges2 = np.histogram(M[:,1], bins=bin_edges1)
        for x in list(M[:,1]):
            if x < min(bin_edges1):
                hist2[0] = hist2[0] + 1
            elif x > max(bin_edges1):
                hist2[-1] = hist2[-1] + 1

        H = convolve(hist1.tolist(), hist2.tolist())
        for i in range(2, num_cols):
            histi, bin_edgesi = np.histogram(M[:,i], bins=bin_edges1)
            for x in list(M[:,i]):
                if x < min(bin_edges1):
                    histi[0] = histi[0] + 1
                elif x > max(bin_edges1):
                    histi[-1] = histi[-1] + 1
            H = convolve(H, histi.tolist())
        b = np.zeros(n_bins)
        for i in range(0, len(KEY_1)):
            histi, bin_edgesi = np.histogram(M[KEY_1[i], i], bins=bin_edges1)
            x = M[KEY_1[i], i]
            if x < min(bin_edges1):
                histi[0] = histi[0] + 1
            elif x > max(bin_edges1):
                histi[-1] = histi[-1] + 1
            b = np.add(b, histi)
        b = np.multiply(b, [x for x in range(1, n_bins+1)])
        b = sum(b) - len(KEY_1) + 1
        min_a = 0
        max_a = 0
        for i in H[int(b+len(KEY_1)/2):]:
            min_a = min_a + i  
        for i in H[int(b-len(KEY_1)/2-1):]:
            max_a = max_a + i
        print("Key Rank after " + str(sample)+ " traces")
        print("\t lower bound", math.log2(min_a+1))
        print("\t upper bound", math.log2(max_a+1))
        steps.append(sample)
        lower.append(math.log2(min_a+1))
        upper.append(math.log2(max_a+1))

    keyrank_df = pd.DataFrame()
    keyrank_df['traces'] = steps
    keyrank_df['upperBound'] = upper
    keyrank_df['lowerBound'] = lower
    keyrank_df.to_csv(DIRECTORY_PATH+"/keyrank_results.csv", index=False)

if __name__ == "__main__":
    keyrank()
